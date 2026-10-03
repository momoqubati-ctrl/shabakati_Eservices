import crypto from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_PUBLISHABLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs';
const SUPABASE_SERVICE_ROLE = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MDE4MTc4NCwiZXhwIjoyMTA1NzU3Nzg0fQ.c4xQmTbu0dS2lxewsnYtQ6ih5vNlbwpBm4v2nv2F73g';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || process.env.VITE_SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SERVICE_ROLE;

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

async function insertSupabase(table, data) {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      },
      body: JSON.stringify(data)
    });
    return await res.json().catch(() => null);
  } catch (e) {
    console.warn(`Supabase insert error on ${table}:`, e);
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

    const mode = 'live';
    const isLive = true;

    const appId = isLive
      ? (process.env.BASGATE_LIVE_APP_ID || process.env.BASGATE_APP_ID || 'dcb2583d-a276-478c-a70b-77463f1fc3e5')
      : (process.env.BASGATE_TEST_APP_ID || 'de14eba9-6272-4c23-86c3-40b592816ebc');

    const clientId = isLive
      ? (process.env.BASGATE_LIVE_CLIENT_ID || process.env.BASGATE_CLIENT_ID || '384d0f26-fa84-4c23-9aaa-2e17efb1860e')
      : (process.env.BASGATE_TEST_CLIENT_ID || '273c2f8d-1f10-490f-8da7-d58785d627d2');

    const clientSecret = isLive
      ? (process.env.BASGATE_LIVE_CLIENT_SECRET || process.env.BASGATE_CLIENT_SECRET || '773c4cbb-5896-4ead-8070-61d988d7c8d1')
      : (process.env.BASGATE_TEST_CLIENT_SECRET || '9ddad294-7c6c-444a-9859-0613ea6c2da4');

    const mKey = isLive
      ? (process.env.BASGATE_LIVE_MKEY || process.env.BASGATE_MKEY || '---aUdFMztJdFQ4YMLSfZhEUQ')
      : (process.env.BASGATE_TEST_MKEY || clientSecret);

    const authUrl = isLive
      ? (process.env.BASGATE_LIVE_AUTH_URL || 'https://app.basgate.com/api/v1/auth/token')
      : (process.env.BASGATE_TEST_AUTH_URL || 'https://api-tst.basgate.com/api/v1/auth/token');

    const initiateUrl = isLive
      ? (process.env.BASGATE_LIVE_INITIATE_URL || 'https://app.basgate.com/api/v1/merchant/sdk-payment/initiate-transaction')
      : (process.env.BASGATE_TEST_INITIATE_URL || 'https://api-tst.basgate.com/api/v1/merchant/sdk-payment/initiate-transaction');

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
      const errText = await tokenRes.text();
      return res.status(502).json({
        success: false,
        error: `تعذر الاتصال ببوابة BasGate للمصادقة: ${tokenRes.status}`,
        details: errText
      });
    }

    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token || tokenData.token;

    if (!accessToken) {
      return res.status(502).json({
        success: false,
        error: 'لم يتم استلام توكن المصادقة من بوابة BasGate',
        details: tokenData
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
    const signature = isLive
      ? generateBasGateSignature(bodyJson, mKey)
      : 'QDY0UVc1NzYzckFXYW9zMg==';

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
      console.error('BasGate initiate error:', initData);
      return res.status(400).json({
        success: false,
        error: initData.messages?.[0] || 'تعذر بدء المعاملة لدى بوابة BasGate',
        details: initData
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
    });

    // 5. حفظ لوج العملية
    await insertSupabase('payment_logs', {
      payment_id: paymentId,
      action: 'initiate',
      payload: {
        order_id: effectiveOrderId,
        amount: Number(amount),
        currency,
        trx_token: trxToken,
        mode
      }
    });

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
    console.error('Handler error:', error);
    return res.status(500).json({
      success: false,
      error: 'خطأ غير متوقع أثناء معالجة طلب الدفع',
      details: error.message
    });
  }
}
