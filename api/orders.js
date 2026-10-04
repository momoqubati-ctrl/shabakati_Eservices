import crypto from 'crypto';
import { verifyAdminAuth } from './_lib/adminAuth.js';
import { calculateExpectedTotalYer, isExactPaidAmount } from './_lib/orderPricing.js';
import { getServerSecrets } from './_lib/serverSecrets.js';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs';


function toDeterministicUuid(seed) {
  const str = String(seed || '').trim();
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(str)) {
    return str.toLowerCase();
  }
  const hash = crypto.createHash('sha256').update(str || crypto.randomUUID()).digest('hex');
  return [
    hash.substring(0, 8),
    hash.substring(8, 12),
    '4' + hash.substring(13, 16),
    'a' + hash.substring(17, 20),
    hash.substring(20, 32)
  ].join('-');
}

function signRequest(method, pathWithQuery, bodyData, keyId, apiSecret, idempotencySeed = null) {
  const nowUtc = new Date().toISOString().split('.')[0] + 'Z';
  const nonce = crypto.randomBytes(16).toString('hex');
  const rawBody = bodyData ? (typeof bodyData === 'string' ? bodyData : JSON.stringify(bodyData)) : '';
  const bodyHash = crypto.createHash('sha256').update(rawBody).digest('hex').toLowerCase();

  const upperMethod = method.toUpperCase();
  const canonical = [upperMethod, pathWithQuery, nowUtc, nonce, bodyHash].join('\n');
  const signature = crypto.createHmac('sha256', apiSecret).update(canonical).digest('hex').toLowerCase();

  const headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Seller-Key': keyId,
    'X-Seller-Timestamp': nowUtc,
    'X-Seller-Nonce': nonce,
    'X-Seller-Signature': `sha256=${signature}`,
    'X-Request-ID': `gw_ord_${Date.now()}`
  };

  if (upperMethod === 'POST' || upperMethod === 'PUT' || upperMethod === 'PATCH') {
    headers['Idempotency-Key'] = idempotencySeed ? toDeterministicUuid(idempotencySeed) : crypto.randomUUID();
  }

  return {
    headers,
    rawBody
  };
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const secrets = await getServerSecrets();
  const BASE_URL = process.env.DIGITAL_VAULT_BASE_URL || process.env.VITE_DIGITAL_VAULT_BASE_URL || secrets.DIGITAL_VAULT_BASE_URL || 'https://sahalnahaa.cloud/api/seller/v1';
  const KEY_ID = process.env.DIGITAL_VAULT_KEY_ID || secrets.DIGITAL_VAULT_KEY_ID;
  const API_SECRET = process.env.DIGITAL_VAULT_API_SECRET || secrets.DIGITAL_VAULT_API_SECRET;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || secrets.SUPABASE_SERVICE_ROLE_KEY;

  if (!KEY_ID || !API_SECRET || !SUPABASE_KEY) {
    return res.status(500).json({ success: false, error: 'إعدادات الخادم غير مكتملة' });
  }

  // =========================================================================
  // 1. معالجة طلبات GET (قائمة الطلبات للأدمن / فحص حالة طلب / استهلاك الكود)
  // =========================================================================
  if (req.method === 'GET') {
    const { seller_order_id, external_order_id, action, limit = '20' } = req.query || {};
    const isAdmin = await verifyAdminAuth(req, SUPABASE_ANON);

    if (action === 'list') {
      if (!isAdmin) {
        return res.status(401).json({ success: false, error: 'غير مصرح لك بعرض قائمة طلبات المزود' });
      }
      try {
        const signed = signRequest('GET', `/api/seller/v1/orders?limit=${encodeURIComponent(limit)}`, null, KEY_ID, API_SECRET);
        const providerRes = await fetch(`${BASE_URL}/orders?limit=${encodeURIComponent(limit)}`, {
          headers: signed.headers
        });
        const data = await providerRes.json();
        return res.status(providerRes.status).json(data);
      } catch (_) {
        return res.status(500).json({ success: false, error: 'تعذر جلب قائمة الطلبات من المزود' });
      }
    }

    if (!seller_order_id) {
      return res.status(400).json({ success: false, error: 'seller_order_id is required' });
    }

    // حماية consume_key وفحص الطلب من ثغرة IDOR: يتطلب إما توكن أدمن موثق أو تطابق external_order_id السري للعميل
    if (!isAdmin) {
      if (!external_order_id) {
        return res.status(401).json({ success: false, error: 'غير مصرح بالوصول إلى هذا الطلب' });
      }
      const ownRes = await fetch(
        `${SUPABASE_URL}/rest/v1/orders?seller_order_id=eq.${encodeURIComponent(seller_order_id)}&external_order_id=eq.${encodeURIComponent(external_order_id)}&select=id`,
        {
          headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`
          }
        }
      );
      const ownRows = ownRes.ok ? await ownRes.json() : [];
      if (!Array.isArray(ownRows) || ownRows.length === 0) {
        return res.status(403).json({ success: false, error: 'غير مصرح بالوصول إلى بيانات هذا الطلب' });
      }
    }

    if (action === 'consume_key' || action === 'delivery_access') {
      try {
        const tokenSign = signRequest('POST', `/api/seller/v1/orders/${encodeURIComponent(seller_order_id)}/delivery-access`, {}, KEY_ID, API_SECRET);
        tokenSign.headers['Idempotency-Key'] = crypto.randomUUID();
        const tokRes = await fetch(`${BASE_URL}/orders/${encodeURIComponent(seller_order_id)}/delivery-access`, {
          method: 'POST',
          headers: tokenSign.headers,
          body: '{}'
        });
        const tokData = await tokRes.json();
        if (tokData?.data?.access_token) {
          const consumeSign = signRequest('POST', '/api/seller/v1/delivery-access/consume', { access_token: tokData.data.access_token }, KEY_ID, API_SECRET);
          const consumeRes = await fetch(`${BASE_URL}/delivery-access/consume`, {
            method: 'POST',
            headers: consumeSign.headers,
            body: consumeSign.rawBody
          });
          const consumeData = await consumeRes.json();

          // مزامنة حالة الطلب والأكواد في Supabase فور استهلاك المفتاح بنجاح
          if (Array.isArray(consumeData?.data?.assets) && consumeData.data.assets.length > 0) {
            const rawAssets = consumeData.data.assets.map(a => ({
              type: a.type || 'key',
              value: a.value || '',
              ...(a.url ? { url: a.url } : {})
            })).filter(a => a.value);

            try {
              await fetch(`${SUPABASE_URL}/rest/v1/orders?seller_order_id=eq.${encodeURIComponent(seller_order_id)}`, {
                method: 'PATCH',
                headers: {
                  'apikey': SUPABASE_KEY,
                  'Authorization': `Bearer ${SUPABASE_KEY}`,
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                  status: 'completed',
                  fulfillment_status: 'ready',
                  delivered_assets: rawAssets,
                  updated_at: new Date().toISOString()
                })
              });
            } catch (_) {}
          }

          return res.status(consumeRes.status).json(consumeData);
        }
        return res.status(tokRes.status).json(tokData);
      } catch (err) {
        console.error('Consume key error:', err.message);
        return res.status(500).json({ success: false, error: 'تعذر سحب المفتاح الرقمي حالياً' });
      }
    }

    try {
      const signed = signRequest('GET', `/api/seller/v1/orders/${encodeURIComponent(seller_order_id)}`, null, KEY_ID, API_SECRET);
      const providerRes = await fetch(`${BASE_URL}/orders/${encodeURIComponent(seller_order_id)}`, {
        headers: signed.headers
      });
      const data = await providerRes.json();
      return res.status(providerRes.status).json(data);
    } catch (err) {
      console.error('Get order error:', err.message);
      return res.status(500).json({ success: false, error: 'تعذر فحص حالة الطلب حالياً' });
    }
  }

  // =========================================================================
  // 2. معالجة طلبات التعديل الإداري (PATCH / action === 'update') - للأدمن حصرياً
  // =========================================================================
  if (req.method === 'PATCH' || (req.method === 'POST' && req.body?.action === 'update')) {
    const isAdmin = await verifyAdminAuth(req, SUPABASE_ANON);
    if (!isAdmin) {
      return res.status(401).json({ success: false, error: 'غير مصرح لك بتعديل بيانات الطلبات (يتطلب صلاحية الأدمن)' });
    }

    const { id, external_order_id, fulfillment_status, status, delivered_assets, seller_order_id, notes, payment_id, payment_reference, payment_method, wallet_name } = req.body || {};
    if (!id && !external_order_id && !seller_order_id) {
      return res.status(400).json({ success: false, error: 'id or external_order_id or seller_order_id is required' });
    }

    const updatePayload = {
      updated_at: new Date().toISOString()
    };
    if (fulfillment_status !== undefined) updatePayload.fulfillment_status = fulfillment_status;
    if (status !== undefined) updatePayload.status = status;
    if (delivered_assets !== undefined) updatePayload.delivered_assets = delivered_assets;
    if (seller_order_id !== undefined) updatePayload.seller_order_id = seller_order_id;
    if (notes !== undefined) updatePayload.notes = notes;
    if (payment_id !== undefined) updatePayload.payment_id = payment_id;
    if (payment_reference !== undefined) updatePayload.payment_reference = payment_reference;
    if (payment_method !== undefined) updatePayload.payment_method = payment_method;
    if (wallet_name !== undefined) updatePayload.wallet_name = wallet_name;

    try {
      let queryParam = '';
      if (id) queryParam = `id=eq.${encodeURIComponent(id)}`;
      else if (external_order_id) queryParam = `external_order_id=eq.${encodeURIComponent(external_order_id)}`;
      else if (seller_order_id) queryParam = `seller_order_id=eq.${encodeURIComponent(seller_order_id)}`;
      const patchRes = await fetch(`${SUPABASE_URL}/rest/v1/orders?${queryParam}`, {
        method: 'PATCH',
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify(updatePayload)
      });
      const data = await patchRes.json();
      return res.status(patchRes.status).json({ success: patchRes.ok, data });
    } catch (err) {
      console.error('Patch order error:', err.message);
      return res.status(500).json({ success: false, error: 'تعذر تحديث الطلب' });
    }
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // =========================================================================
  // 3. معالجة طلب إلغاء العملية لدى المزود (للأدمن حصرياً)
  // =========================================================================
  if (req.body?.action === 'cancel') {
    const isAdmin = await verifyAdminAuth(req, SUPABASE_ANON);
    if (!isAdmin) {
      return res.status(401).json({ success: false, error: 'غير مصرح لك بإلغاء الطلبات' });
    }
    const { seller_order_id, reason } = req.body || {};
    if (!seller_order_id) {
      return res.status(400).json({ success: false, error: 'seller_order_id is required' });
    }
    try {
      const cancelBody = { reason: String(reason || 'إلغاء الطلب بناء على رغبة العميل').substring(0, 500) };
      const signed = signRequest('POST', `/api/seller/v1/orders/${encodeURIComponent(seller_order_id)}/cancellation-requests`, cancelBody, KEY_ID, API_SECRET);
      signed.headers['Idempotency-Key'] = crypto.randomUUID();
      const cancelRes = await fetch(`${BASE_URL}/orders/${encodeURIComponent(seller_order_id)}/cancellation-requests`, {
        method: 'POST',
        headers: signed.headers,
        body: signed.rawBody
      });
      const cancelData = await cancelRes.json().catch(() => ({}));
      return res.status(cancelRes.status).json(cancelData);
    } catch (err) {
      return res.status(500).json({ success: false, error: 'تعذر إرسال طلب الإلغاء للمزود' });
    }
  }

  // =========================================================================
  // 4. إنشاء وتنفيذ الطلب (مع فحص تطابق المبلغ والعملة والقفل الذري لمنع Race Condition)
  // =========================================================================
  try {
    const { items, external_order_id, device_id, telegram_user, contact_phone, contact_email, payment_id, payment_reference, payment_method, wallet_name, user_id, account_number } = req.body || {};
    const externalId = external_order_id || `ord_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, error: 'قائمة عناصر الطلب مطلوبة' });
    }

    for (const item of items) {
      const qty = Number(item.quantity || 1);
      if (!Number.isInteger(qty) || qty < 1 || qty > 50) {
        return res.status(400).json({ success: false, error: 'الكمية المطلوبة غير صالحة' });
      }
    }

    let verifiedPaymentRef = payment_reference || null;
    let verifiedWalletName = wallet_name || null;
    let existingDbOrderId = null;

    if (payment_id) {
      // أ) جلب سجل الدفع والتحقق من حالته ومبلغه وعملته
      const pCheckRes = await fetch(
        `${SUPABASE_URL}/rest/v1/payments?id=eq.${encodeURIComponent(payment_id)}&select=id,status,amount,currency,external_order_id,payment_reference,wallet_name,metadata`,
        {
          headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`
          }
        }
      );

      if (!pCheckRes.ok) {
        return res.status(500).json({ success: false, error: 'تعذر التحقق من سجل الدفع' });
      }

      const pRows = await pCheckRes.json();
      if (!Array.isArray(pRows) || pRows.length === 0) {
        return res.status(403).json({ success: false, error: 'عملية الدفع غير مسجلة في النظام' });
      }

      const paymentRow = pRows[0];
      const isAlreadyConsumedBySameOrder =
        paymentRow.status === 'consumed' && paymentRow.metadata?.consumed_by_order === externalId;

      if (paymentRow.status !== 'completed' && !isAlreadyConsumedBySameOrder) {
        return res.status(403).json({
          success: false,
          error: 'عملية الدفع غير مكتملة أو تم استخدامها مسبقاً'
        });
      }

      // ب) مطابقة المبلغ المدفوع (payment.amount) والعملة مع إجمالي أسعار وكميات المنتجات المطلوبة
      const expectedTotalYer = await calculateExpectedTotalYer(items, SUPABASE_KEY);

      const paidAmountYer = Number(paymentRow.amount) || 0;
      const paidCurrency = String(paymentRow.currency || 'YER').toUpperCase();

      if (
        paidCurrency !== 'YER' ||
        !isExactPaidAmount(paidAmountYer, expectedTotalYer)
      ) {
        return res.status(403).json({
          success: false,
          error: 'المبلغ المسدد لا يطابق إجمالي أسعار وكميات المنتجات المطلوبة'
        });
      }

      // ج) القفل الذري (Atomic Lock) على سجل الدفع لمنع هجمات التنافسية (Race Condition)
      if (!isAlreadyConsumedBySameOrder) {
        const lockRes = await fetch(
          `${SUPABASE_URL}/rest/v1/payments?id=eq.${encodeURIComponent(payment_id)}&status=eq.completed`,
          {
            method: 'PATCH',
            headers: {
              'apikey': SUPABASE_KEY,
              'Authorization': `Bearer ${SUPABASE_KEY}`,
              'Content-Type': 'application/json',
              'Prefer': 'return=representation'
            },
            body: JSON.stringify({
              status: 'consumed',
              updated_at: new Date().toISOString(),
              metadata: {
                ...(paymentRow.metadata || {}),
                consumed_by_order: externalId,
                consumed_at: new Date().toISOString()
              }
            })
          }
        );

        const lockedRows = lockRes.ok ? await lockRes.json() : [];
        if (!Array.isArray(lockedRows) || lockedRows.length === 0) {
          return res.status(409).json({
            success: false,
            error: 'تم استخدام مرجع عملية الدفع هذا مسبقاً لطلب آخر'
          });
        }
      }

      verifiedPaymentRef = verifiedPaymentRef || paymentRow.payment_reference || payment_id;
      verifiedWalletName = verifiedWalletName || paymentRow.wallet_name || null;

      // د) تسجيل الطلب مبدئياً في جدول orders قبل الاتصال بالمزود لضمان القفل الفريد وحفظ حق العميل
      const initialTotalCents = items.reduce(
        (sum, it) => sum + ((Number(it.unit_price_cents) || 0) * (Number(it.quantity) || 1)),
        0
      );

      const preInsertRes = await fetch(`${SUPABASE_URL}/rest/v1/orders`, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify({
          external_order_id: externalId,
          device_id: device_id || 'unknown_device',
          telegram_user: telegram_user || null,
          contact_phone: contact_phone || null,
          contact_email: contact_email || null,
          status: 'paid',
          fulfillment_status: 'processing',
          total_cents: initialTotalCents,
          currency: 'USD',
          idempotency_key: crypto.randomUUID(),
          payment_id: payment_id,
          payment_reference: verifiedPaymentRef,
          payment_method: payment_method || 'المحافظ الإلكترونية',
          wallet_name: verifiedWalletName,
          user_id: user_id || null,
          account_number: account_number || null
        })
      });

      if (!preInsertRes.ok) {
        // فحص ما إذا كان الطلب مسجلاً مسبقاً لنفس externalId
        const existingCheck = await fetch(
          `${SUPABASE_URL}/rest/v1/orders?payment_id=eq.${encodeURIComponent(payment_id)}&select=id,external_order_id`,
          { headers: { 'apikey': SUPABASE_KEY, 'Authorization': `Bearer ${SUPABASE_KEY}` } }
        );
        const existingRows = existingCheck.ok ? await existingCheck.json() : [];
        if (Array.isArray(existingRows) && existingRows.length > 0) {
          if (existingRows[0].external_order_id !== externalId) {
            return res.status(409).json({
              success: false,
              error: 'تم استخدام مرجع عملية الدفع هذا مسبقاً لطلب آخر'
            });
          }
          existingDbOrderId = existingRows[0].id;
        } else {
          return res.status(409).json({
            success: false,
            error: 'تعذر حجز عملية الدفع لهذا الطلب'
          });
        }
      } else {
        const insertedRows = await preInsertRes.json();
        existingDbOrderId = insertedRows?.[0]?.id;
        if (existingDbOrderId) {
          const itemsPayload = items.map(it => ({
            order_id: existingDbOrderId,
            product_id: Number(it.product_id || it.product?.id),
            product_name: it.product_name || it.product?.name || `منتج #${it.product_id || it.product?.id}`,
            quantity: Number(it.quantity || 1),
            unit_price_cents: Number(it.unit_price_cents || 0),
            currency: it.currency || 'USD'
          }));
          await fetch(`${SUPABASE_URL}/rest/v1/order_items`, {
            method: 'POST',
            headers: {
              'apikey': SUPABASE_KEY,
              'Authorization': `Bearer ${SUPABASE_KEY}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(itemsPayload)
          }).catch(() => {});
        }
      }
    } else if (external_order_id) {
      // إعادة تنفيذ طلب معلق من لوحة الأدمن — يتطلب توكن أدمن موثق وأن يكون الطلب موجوداً مسبقاً
      const isAdmin = await verifyAdminAuth(req, SUPABASE_ANON);
      if (!isAdmin) {
        return res.status(401).json({
          success: false,
          error: 'معرف عملية الدفع المؤكدة مطلوب لإنشاء طلب جديد'
        });
      }
      const ordCheckRes = await fetch(
        `${SUPABASE_URL}/rest/v1/orders?external_order_id=eq.${encodeURIComponent(external_order_id)}&select=id`,
        {
          headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`
          }
        }
      );
      const ordRows = ordCheckRes.ok ? await ordCheckRes.json() : [];
      if (!Array.isArray(ordRows) || ordRows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'الطلب غير موجود في قاعدة البيانات'
        });
      }
      existingDbOrderId = ordRows[0].id;
    } else {
      return res.status(403).json({
        success: false,
        error: 'معرف عملية الدفع المؤكدة مطلوب لإنشاء طلب جديد'
      });
    }

    const orderPayload = {
      external_order_id: externalId,
      items: items.map(i => ({
        product_id: Number(i.product_id || i.product?.id),
        quantity: Number(i.quantity || 1)
      }))
    };

    // 5. إرسال الطلب لمزود الخدمة Digital Vault
    const signed = signRequest('POST', '/api/seller/v1/orders', orderPayload, KEY_ID, API_SECRET, externalId);

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
    let deliveredAssetsList = null;

    // 6. إذا كان التسليم فوري (ready)، سحب الكود فوراً
    if (sellerOrder.fulfillment_status === 'ready') {
      try {
        const tokenSign = signRequest('POST', `/api/seller/v1/orders/${sellerOrder.id}/delivery-access`, {}, KEY_ID, API_SECRET);
        const tokRes = await fetch(`${BASE_URL}/orders/${sellerOrder.id}/delivery-access`, {
          method: 'POST',
          headers: tokenSign.headers,
          body: '{}'
        });
        const tokData = await tokRes.json();
        if (tokData?.data?.access_token) {
          const consumeSign = signRequest('POST', '/api/seller/v1/delivery-access/consume', { access_token: tokData.data.access_token }, KEY_ID, API_SECRET);
          const consumeRes = await fetch(`${BASE_URL}/delivery-access/consume`, {
            method: 'POST',
            headers: consumeSign.headers,
            body: consumeSign.rawBody
          });
          const consumeData = await consumeRes.json();
          const rawAssets = consumeData?.data?.assets;
          if (Array.isArray(rawAssets) && rawAssets.length > 0) {
            deliveredAssetsList = rawAssets.map(a => ({
              type: a.type || 'key',
              value: a.value || '',
              ...(a.url ? { url: a.url } : {})
            })).filter(a => a.value);
            deliveredKey = deliveredAssetsList.map(a => a.value).join('\n');
          }
        }
      } catch (_) {}
    }

    // 7. تحديث السجل في Supabase برقم طلب المزود والمفاتيح المسلمة
    if (existingDbOrderId) {
      try {
        await fetch(`${SUPABASE_URL}/rest/v1/orders?id=eq.${existingDbOrderId}`, {
          method: 'PATCH',
          headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            seller_order_id: sellerOrder.id,
            status: deliveredKey ? 'completed' : (sellerOrder.status || 'paid'),
            fulfillment_status: deliveredKey ? 'ready' : (sellerOrder.fulfillment_status || 'processing'),
            total_cents: sellerOrder.total?.amount_cents || undefined,
            currency: sellerOrder.total?.currency || 'USD',
            delivered_assets: deliveredAssetsList || (deliveredKey ? [{ type: 'key', value: deliveredKey }] : null),
            updated_at: new Date().toISOString()
          })
        });
      } catch (_) {}
    }

    return res.status(201).json({
      success: true,
      data: {
        ...sellerOrder,
        delivered_key: deliveredKey,
        delivered_assets: deliveredAssetsList,
        is_ready: !!deliveredKey
      }
    });
  } catch (error) {
    console.error('Orders API error:', error.message);
    return res.status(500).json({
      success: false,
      error: 'حدث خطأ أثناء معالجة الطلب في الخادم'
    });
  }
}
