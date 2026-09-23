import crypto from 'crypto';

const BASE_URL = process.env.VITE_DIGITAL_VAULT_BASE_URL || 'https://sahalnahaa.cloud/api/seller/v1';
const KEY_ID = process.env.VITE_DIGITAL_VAULT_KEY_ID || 'skey_01m37stgc9tpg5vsj5382rd8ra';
const API_SECRET = process.env.VITE_DIGITAL_VAULT_API_SECRET || 'ssec_96c632b8e715694af4b0fa62c8872cd2c99901fe0f13323c0cfb55251e335954';
const SUPABASE_URL = process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';
const SUPABASE_ANON = process.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs';

function signRequest(method, pathWithQuery, bodyData = null) {
  const nowUtc = new Date().toISOString().split('.')[0] + 'Z';
  const nonce = crypto.randomBytes(16).toString('hex');
  const rawBody = bodyData ? (typeof bodyData === 'string' ? bodyData : JSON.stringify(bodyData)) : '';
  const bodyHash = crypto.createHash('sha256').update(rawBody).digest('hex').toLowerCase();

  const canonical = [method.toUpperCase(), pathWithQuery, nowUtc, nonce, bodyHash].join('\n');
  const signature = crypto.createHmac('sha256', API_SECRET).update(canonical).digest('hex').toLowerCase();

  return {
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Seller-Key': KEY_ID,
      'X-Seller-Timestamp': nowUtc,
      'X-Seller-Nonce': nonce,
      'X-Seller-Signature': `sha256=${signature}`,
      'X-Request-ID': `gw_ord_${Date.now()}`
    },
    rawBody
  };
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { items, external_order_id, device_id, telegram_user, contact_phone, contact_email } = req.body || {};
    const externalId = external_order_id || `ord_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    const orderPayload = {
      external_order_id: externalId,
      items: (items || []).map(i => ({
        product_id: i.product_id || i.product?.id,
        quantity: i.quantity || 1
      }))
    };

    // 1. طلب المزود Digital Vault
    const signed = signRequest('POST', '/api/seller/v1/orders', orderPayload);
    signed.headers['Idempotency-Key'] = externalId;

    const providerRes = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: signed.headers,
      body: signed.rawBody
    });

    const providerData = await providerRes.json();
    if (!providerRes.ok || !providerData.success) {
      return res.status(providerRes.status).json(providerData);
    }

    const sellerOrder = providerData.data;
    let deliveredKey = null;

    // 2. إذا كان التسليم فوري
    if (sellerOrder.fulfillment_status === 'ready') {
      try {
        const tokenSign = signRequest('POST', `/api/seller/v1/orders/${sellerOrder.id}/delivery-access`, {});
        tokenSign.headers['Idempotency-Key'] = `tok_${sellerOrder.id}_${Date.now()}`;
        const tokRes = await fetch(`${BASE_URL}/orders/${sellerOrder.id}/delivery-access`, {
          method: 'POST',
          headers: tokenSign.headers,
          body: '{}'
        });
        const tokData = await tokRes.json();
        if (tokData?.data?.access_token) {
          const consumeSign = signRequest('POST', '/api/seller/v1/delivery-access/consume', { access_token: tokData.data.access_token });
          const consumeRes = await fetch(`${BASE_URL}/delivery-access/consume`, {
            method: 'POST',
            headers: consumeSign.headers,
            body: consumeSign.rawBody
          });
          const consumeData = await consumeRes.json();
          deliveredKey = consumeData?.data?.assets?.[0]?.value || null;
        }
      } catch (_) {}
    }

    // 3. الحفظ في Supabase
    try {
      const orderRecord = {
        external_order_id: externalId,
        device_id: device_id || 'unknown_device',
        telegram_user: telegram_user || null,
        contact_phone: contact_phone || null,
        contact_email: contact_email || null,
        seller_order_id: sellerOrder.id,
        status: deliveredKey ? 'completed' : (sellerOrder.status || 'paid'),
        fulfillment_status: deliveredKey ? 'ready' : (sellerOrder.fulfillment_status || 'processing'),
        total_cents: sellerOrder.total?.amount_cents || 0,
        currency: sellerOrder.total?.currency || 'USD',
        idempotency_key: externalId,
        delivered_assets: deliveredKey ? [{ type: 'key', value: deliveredKey }] : null
      };

      await fetch(`${SUPABASE_URL}/rest/v1/orders`, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_ANON,
          'Authorization': `Bearer ${SUPABASE_ANON}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify(orderRecord)
      });
    } catch (_) {}

    return res.status(201).json({
      success: true,
      data: {
        ...sellerOrder,
        delivered_key: deliveredKey,
        is_ready: !!deliveredKey
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
}
