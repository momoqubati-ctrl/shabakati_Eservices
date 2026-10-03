import crypto from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs';

async function getServerSecrets() {
  if (globalThis.__shabaktiSecretsCache) return globalThis.__shabaktiSecretsCache;
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/rpc_get_backend_secrets`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_ANON,
        'Authorization': `Bearer ${SUPABASE_ANON}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ p_handshake: process.env.SERVER_HANDSHAKE_KEY || 'shabakti_srv_vault_handshake_2026_v1' })
    });
    if (res.ok) {
      const data = await res.json();
      if (data && typeof data === 'object') {
        globalThis.__shabaktiSecretsCache = data;
        return data;
      }
    }
  } catch (_) {}
  return {};
}

function generateBasGateSignature(input, secretKey) {
  const payloadStr = typeof input === 'string' ? input : JSON.stringify(input);
  const charset = '@#!abcdefghijklmonpqrstuvwxyz#@01234567890123456789#@ABCDEFGHIJKLMNOPQRSTUVWXYZ#@';
  let salt = '';
  const randomBytes = crypto.randomBytes(4);
  for (let i = 0; i < 4; i++) {
    salt += charset.charAt(randomBytes[i] % charset.length);
  }

  const inputToHash = payloadStr + '|' + salt;
  const sha256Hex = crypto.createHash('sha256').update(inputToHash, 'utf8').digest('hex').toLowerCase();
  const payloadToEncrypt = sha256Hex + salt;
  const keyHash = crypto.createHash('sha256').update(secretKey, 'ascii').digest();
  const iv = Buffer.from('@@@@&&&&####$$$$', 'utf8');
  const cipher = crypto.createCipheriv('aes-256-cbc', keyHash, iv);

  let encrypted = cipher.update(payloadToEncrypt, 'ascii', 'base64');
  encrypted += cipher.final('base64');
  return encrypted;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  try {
    const secrets = await getServerSecrets();
    const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || secrets.SUPABASE_SERVICE_ROLE_KEY;
    if (!SUPABASE_KEY) {
      return res.status(500).json({ success: false, error: 'Server configuration error' });
    }

    const payload = req.body || {};
    const body = payload.body || payload;
    const orderId = body.orderId || body.order_id || body.order?.orderId;

    if (!orderId || typeof orderId !== 'string') {
      return res.status(400).json({ success: false, error: 'Invalid orderId' });
    }

    // 1. التأكد من وجود سجل الدفع في قاعدة البيانات أولاً
    const payCheckRes = await fetch(
      `${SUPABASE_URL}/rest/v1/payments?external_order_id=eq.${encodeURIComponent(orderId)}&select=*`,
      {
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`
        }
      }
    );
    const payments = payCheckRes.ok ? await payCheckRes.json() : [];
    if (!Array.isArray(payments) || payments.length === 0) {
      return res.status(404).json({ success: false, error: 'Payment record not found' });
    }

    const payment = payments[0];

    // 2. التحقق العكسي المباشر (Server-to-Server Verification) مع خادم BasGate الرسمي
    // منع التحديث التلقائي لحالة الدفع بمجرد استقبال الـ Webhook لمنع تزوير الدفع (Payment Spoofing)
    const appId = process.env.BASGATE_LIVE_APP_ID || secrets.BASGATE_LIVE_APP_ID;
    const clientId = process.env.BASGATE_LIVE_CLIENT_ID || secrets.BASGATE_LIVE_CLIENT_ID;
    const clientSecret = process.env.BASGATE_LIVE_CLIENT_SECRET || secrets.BASGATE_LIVE_CLIENT_SECRET;
    const mKey = process.env.BASGATE_LIVE_MKEY || secrets.BASGATE_LIVE_MKEY;
    const authUrl = process.env.BASGATE_LIVE_AUTH_URL || 'https://app.basgate.com/api/v1/auth/token';
    const statusUrl = process.env.BASGATE_LIVE_STATUS_URL || 'https://app.basgate.com/api/v1/merchant/sdk-payment/get-transaction-status';

    const formData = new URLSearchParams();
    formData.append('grant_type', 'client_credentials');
    formData.append('client_id', clientId);
    formData.append('client_secret', clientSecret);

    const tokenRes = await fetch(authUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      },
      body: formData.toString()
    });

    if (!tokenRes.ok) {
      return res.status(502).json({ success: false, error: 'Gateway authentication failed' });
    }

    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token || tokenData.token;
    if (!accessToken) {
      return res.status(502).json({ success: false, error: 'Invalid gateway token' });
    }

    const timestampMs = String(Date.now());
    const bodyDict = {
      appId,
      orderId: payment.external_order_id,
      requestTimestamp: timestampMs
    };
    const bodyJson = JSON.stringify(bodyDict);
    const signature = generateBasGateSignature(bodyJson, mKey);

    const statusRes = await fetch(statusUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      },
      body: JSON.stringify({
        head: {
          signature,
          requestTimestamp: timestampMs,
          bodystring: bodyJson,
          forceVerifySignature: false
        },
        body: bodyDict
      })
    });

    const verifiedRaw = await statusRes.json();
    const verifiedBody = verifiedRaw?.body || {};
    const verifiedOrder = verifiedBody.order || {};
    const verifiedPaymentStatus = Number(verifiedBody.paymentStatus ?? verifiedOrder.paymentStatus ?? -1);

    // لا يتم اعتماد الدفع كمكتمل إلا إذا أكد خادم BasGate الرسمي الرمز 1202
    const isVerifiedSuccess = verifiedPaymentStatus === 1202;
    const isVerifiedFailed = verifiedPaymentStatus === 1203 || verifiedPaymentStatus === 1204 || verifiedPaymentStatus === 1501;
    const dbStatus = isVerifiedSuccess ? 'completed' : (isVerifiedFailed ? 'failed' : payment.status);

    const descStr = String(verifiedOrder.description || verifiedBody.description || '');
    const refMatch = descStr.match(/(Sdk[0-9A-Za-z_-]+)/i);
    const paymentReference = verifiedBody.referenceId || verifiedBody.referenceNumber || (refMatch ? refMatch[1] : null) || verifiedBody.trxId || null;
    const walletFromDescMatch = descStr.match(/لدى\s+(.+)$/);
    const walletFromDesc = walletFromDescMatch && walletFromDescMatch[1] ? walletFromDescMatch[1].trim() : '';
    const walletName = walletFromDesc || verifiedBody.paymentMethodNameAr || verifiedBody.walletName || verifiedBody.paymentMethodNameEn || null;

    const updateFields = {
      status: dbStatus,
      updated_at: new Date().toISOString(),
      metadata: {
        ...(payment.metadata || {}),
        webhook_verified_status: verifiedPaymentStatus
      }
    };
    if (paymentReference) updateFields.payment_reference = paymentReference;
    if (walletName) updateFields.wallet_name = walletName;

    await fetch(`${SUPABASE_URL}/rest/v1/payments?id=eq.${encodeURIComponent(payment.id)}`, {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify(updateFields)
    });

    await fetch(`${SUPABASE_URL}/rest/v1/payment_logs`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify({
        payment_id: payment.id,
        action: 'webhook_verified',
        payload: { verified_status: verifiedPaymentStatus, db_status: dbStatus }
      })
    });

    return res.status(200).json({ success: true, verified: isVerifiedSuccess, status: dbStatus });
  } catch (err) {
    console.error('Webhook verification error:', err.message);
    return res.status(500).json({ success: false, error: 'Internal webhook processing error' });
  }
}
