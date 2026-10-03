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
  let payloadStr = typeof input === 'string' ? input : JSON.stringify(input);

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

async function insertSupabase(table, data, supabaseKey) {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
      method: 'POST',
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      },
      body: JSON.stringify(data)
    });
    return await res.json().catch(() => null);
  } catch (e) {
    console.warn(`Supabase insert error on ${table}:`, e.message);
    return null;
  }
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
    const {
      amount,
      currency = 'YER',
      order_id,
      user_account,
      customer_name,
      description
    } = req.body || {};

    if (!amount || Number(amount) <= 0) {
      return res.status(400).json({ success: false, error: 'المبلغ غير صالح لإتمام عملية الدفع' });
    }

    const secrets = await getServerSecrets();
    const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || secrets.SUPABASE_SERVICE_ROLE_KEY;

    const mode = 'live';
    const isLive = true;

    const appId = process.env.BASGATE_LIVE_APP_ID || process.env.BASGATE_APP_ID || secrets.BASGATE_LIVE_APP_ID;
    const clientId = process.env.BASGATE_LIVE_CLIENT_ID || process.env.BASGATE_CLIENT_ID || secrets.BASGATE_LIVE_CLIENT_ID;
    const clientSecret = process.env.BASGATE_LIVE_CLIENT_SECRET || process.env.BASGATE_CLIENT_SECRET || secrets.BASGATE_LIVE_CLIENT_SECRET;
    const mKey = process.env.BASGATE_LIVE_MKEY || process.env.BASGATE_MKEY || secrets.BASGATE_LIVE_MKEY || clientSecret;

    const authUrl = process.env.BASGATE_LIVE_AUTH_URL || 'https://app.basgate.com/api/v1/auth/token';
    const initiateUrl = process.env.BASGATE_LIVE_INITIATE_URL || 'https://app.basgate.com/api/v1/merchant/sdk-payment/initiate-transaction';

    if (!appId || !clientId || !clientSecret || !mKey || !SUPABASE_KEY) {
      return res.status(500).json({
        success: false,
        error: 'إعدادات بوابة الدفع في الخادم غير مكتملة'
      });
    }

    // 1. طلب OAuth Access Token من BasGate
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
      console.error('BasGate auth error status:', tokenRes.status);
      return res.status(502).json({
        success: false,
        error: 'تعذر الاتصال ببوابة الدفع للمصادقة في الوقت الحالي'
      });
    }

    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token || tokenData.token;

    if (!accessToken) {
      console.error('BasGate missing access token');
      return res.status(502).json({
        success: false,
        error: 'لم يتم استلام رمز المصادقة من بوابة الدفع'
      });
    }

    // 2. تجهيز معرف المعاملة والطلب
    const effectiveOrderId = order_id || `ORD_${Date.now()}`;
    const timestampMs = Date.now();
    const paymentId = `PAY_${timestampMs}_${Math.random().toString(36).substring(2, 7)}`;

    const requestBodyData = {
      amount: {
        value: Math.round(Number(amount)),
        currency: currency.toUpperCase()
      },
      customerInfo: {
        id: 'CUSTOMER'
      },
      ordertype: 'PayBill',
      orderId: effectiveOrderId,
      requestTimestamp: timestampMs,
      appId: appId,
      description: description || `دفع طلب رقم ${effectiveOrderId}`,
      remark: `سداد طلب بوابة شبكتي ${effectiveOrderId}`,
      orderDetails: {
        itemId: 'ESERVICE-ORDER',
        quantity: 1
      },
      callBackUrl: 'https://shabakati-eservices.vercel.app/api/basgate-webhook',
      redirectUrl: 'https://shabakati-eservices.vercel.app/success',
      cancelUrl: 'https://shabakati-eservices.vercel.app/cancel'
    };

    const bodyJson = JSON.stringify(requestBodyData);
    const signature = generateBasGateSignature(bodyJson, mKey);

    // 3. طلب initiate-transaction من BasGate
    const initRes = await fetch(initiateUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      },
      body: JSON.stringify({
        head: {
          signature: signature,
          requestTimestamp: timestampMs,
          bodystring: bodyJson,
          forceVerifySignature: false
        },
        body: requestBodyData
      })
    });

    const initData = await initRes.json();
    const trxToken = initData.body?.trxToken || initData.trxToken || initData.data?.trxToken || initData.trx_token;

    if (!initRes.ok || !trxToken) {
      console.error('BasGate initiate error code:', initData?.code, initData?.messages);
      return res.status(400).json({
        success: false,
        error: initData.messages?.[0] || 'تعذر بدء المعاملة لدى بوابة الدفع'
      });
    }

    // 4. حفظ سجل الدفع في Supabase
    await insertSupabase('payments', {
      id: paymentId,
      user_account: user_account || 'GUEST',
      external_order_id: effectiveOrderId,
      amount: Number(amount),
      currency: currency.toUpperCase(),
      provider: 'basgate',
      trx_token: trxToken,
      status: 'pending',
      environment: isLive ? 'prod' : 'dev',
      metadata: {
        app_id: appId,
        mode: mode,
        customer_name: customer_name || '',
        order_details: requestBodyData.orderDetails
      }
    }, SUPABASE_KEY);

    // 5. حفظ لوج العملية (مع تنقية السجلات وإخفاء trxToken)
    await insertSupabase('payment_logs', {
      payment_id: paymentId,
      action: 'initiate',
      payload: {
        order_id: effectiveOrderId,
        amount: Number(amount),
        currency,
        mode
      }
    }, SUPABASE_KEY);

    return res.status(200).json({
      success: true,
      payment_id: paymentId,
      trx_token: trxToken,
      order_id: effectiveOrderId,
      amount: Number(amount),
      currency: currency.toUpperCase(),
      environment: isLive ? 'prod' : 'dev',
      mode: mode
    });
  } catch (error) {
    console.error('Initiate handler error:', error.message);
    return res.status(500).json({
      success: false,
      error: 'حدث خطأ أثناء الاتصال ببوابة الدفع، يرجى المحاولة لاحقاً'
    });
  }
}
