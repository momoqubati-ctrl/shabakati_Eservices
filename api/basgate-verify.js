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
    const { payment_id, order_id, sdk_result_status, sdk_message } = req.body || {};

    if (!payment_id && !order_id) {
      return res.status(400).json({ success: false, error: 'معرف الدفع أو رقم الطلب مطلوب' });
    }

    // 1. جلب سجل الدفع من Supabase
    let url = `${SUPABASE_URL}/rest/v1/payments?select=*`;
    if (payment_id) {
      url += `&id=eq.${encodeURIComponent(payment_id)}`;
    } else {
      url += `&external_order_id=eq.${encodeURIComponent(order_id)}`;
    }

    const payRes = await fetch(url, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`
      }
    });

    const payments = await payRes.json();
    if (!payments || payments.length === 0) {
      return res.status(404).json({ success: false, error: 'سجل الدفع غير موجود' });
    }

    const payment = payments[0];
    if (payment.status === 'completed') {
      return res.status(200).json({
        success: true,
        outcome: 'SUCCESS',
        payment_id: payment.id,
        payment_reference: payment.payment_reference || payment.id,
        payment_method: 'المحافظ الإلكترونية',
        wallet_name: payment.wallet_name || 'محفظة إلكترونية (BasGate)',
        status: 'completed',
        message: 'تم تأكيد عملية الدفع بنجاح'
      });
    }

    const mode = (process.env.BASGATE_MODE || 'test').toLowerCase();
    const isLive = mode === 'live';

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
      ? (process.env.BASGATE_LIVE_MKEY || process.env.BASGATE_MKEY || clientSecret)
      : (process.env.BASGATE_TEST_MKEY || clientSecret);

    const authUrl = isLive
      ? (process.env.BASGATE_LIVE_AUTH_URL || 'https://app.basgate.com/api/v1/auth/token')
      : (process.env.BASGATE_TEST_AUTH_URL || 'https://api-tst.basgate.com/api/v1/auth/token');

    const statusUrl = isLive
      ? (process.env.BASGATE_LIVE_STATUS_URL || 'https://app.basgate.com/api/v1/merchant/sdk-payment/get-transaction-status')
      : (process.env.BASGATE_TEST_STATUS_URL || 'https://api-tst.basgate.com/api/v1/merchant/sdk-payment/get-transaction-status');

    // 2. طلب Access Token
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
      return res.status(502).json({
        success: false,
        error: 'فشل التوثيق مع بوابة BasGate للتحقق من المعاملة'
      });
    }

    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token || tokenData.token;

    // 3. إرسال طلب فحص الحالة
    const timestampMs = String(Date.now());
    const bodyDict = {
      appId,
      orderId: payment.external_order_id,
      requestTimestamp: timestampMs
    };
    const bodyJson = JSON.stringify(bodyDict);
    const signature = isLive
      ? generateBasGateSignature(bodyJson, mKey)
      : 'QDY0UVc1NzYzckFXYW9zMg==';

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

    const rawResponse = await statusRes.json();
    const responseObj = (rawResponse && typeof rawResponse === 'object') ? rawResponse : {};
    const dataBody = responseObj.body || {};
    const orderData = dataBody.order || {};

    // استخراج رقم مرجع العملية واسم المحفظة الإلكترونية من استجابة BasGate
    const descStr = String(orderData.description || dataBody.description || '');
    const refMatch = descStr.match(/(?:رقم المرجع|Ref|Sdk)\s*[:#]?\s*([A-Za-z0-9_-]+)/i) || descStr.match(/(Sdk[0-9A-Za-z_-]+)/i);
    const extractedRef =
      dataBody.referenceId ||
      dataBody.referenceNumber ||
      dataBody.trxReference ||
      dataBody.bankReference ||
      orderData.referenceId ||
      orderData.referenceNumber ||
      (refMatch ? (refMatch[1]?.startsWith('Sdk') ? refMatch[1] : (descStr.match(/(Sdk[0-9A-Za-z_-]+)/i)?.[1] || refMatch[1])) : null) ||
      dataBody.trxId ||
      payment.payment_reference ||
      payment.id;

    const walletFromDescMatch = descStr.match(/لدى\s+(.+)$/);
    const walletFromDesc = walletFromDescMatch && walletFromDescMatch[1] ? walletFromDescMatch[1].trim() : '';
    const extractedWalletName =
      walletFromDesc ||
      (dataBody.paymentMethodNameAr ? String(dataBody.paymentMethodNameAr).trim() : '') ||
      (dataBody.walletName ? String(dataBody.walletName).trim() : '') ||
      (dataBody.providerName ? String(dataBody.providerName).trim() : '') ||
      (dataBody.channelName ? String(dataBody.channelName).trim() : '') ||
      (dataBody.paymentMethodNameEn ? String(dataBody.paymentMethodNameEn).trim() : '') ||
      payment.wallet_name ||
      'محفظة إلكترونية (BasGate)';

    const apiStatus = Number(responseObj.status ?? -1);
    const apiCode = String(responseObj.code ?? '');
    const paymentStatus = Number(dataBody.paymentStatus ?? orderData.paymentStatus ?? -1);
    const trxStatus = String(dataBody.trxStatus ?? '').toLowerCase();
    const paymentStatusName = String(dataBody.paymentStatusName ?? '').toLowerCase();

    // 4. تقييم نتيجة المعاملة بناءً على معايير BasGate الرسمية
    // النجاح الحقيقي: 1202
    const isSuccess = paymentStatus === 1202;
    const isPending = (apiStatus === 1 && apiCode === '1111') && (
      paymentStatus === 1201 || 
      paymentStatusName === 'process_pending' || 
      trxStatus === 'received' || 
      trxStatus === 'pending' ||
      paymentStatus === 0
    );
    const isCancelled = paymentStatus === 1205 || paymentStatusName === 'process_cancelled' || trxStatus === 'cancelled';
    const isFailed = paymentStatus === 1203 || paymentStatus === 1204 || paymentStatus === 1501 || paymentStatusName === 'process_failed';

    let finalStatus = 'pending';
    let outcome = 'PENDING';
    let userMessage = 'عملية الدفع قيد المعالجة';

    if (isSuccess) {
      finalStatus = 'completed';
      outcome = 'SUCCESS';
      userMessage = 'تمت عملية الدفع بنجاح';
    } else if (isCancelled || sdk_result_status === false) {
      finalStatus = 'cancelled';
      outcome = 'CANCELLED';
      userMessage = 'تم إلغاء عملية الدفع من قبل المستخدم';
    } else if (isFailed) {
      finalStatus = 'failed';
      outcome = 'FAILED';
      userMessage = 'تعثرت عملية الدفع لدى البنك/المحفظة';
    }

    // 5. تحديث السجل في Supabase مع رقم المرجع واسم المحفظة
    await fetch(`${SUPABASE_URL}/rest/v1/payments?id=eq.${encodeURIComponent(payment.id)}`, {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify({
        status: finalStatus,
        payment_reference: extractedRef,
        wallet_name: extractedWalletName,
        updated_at: new Date().toISOString()
      })
    });

    // 6. لوج التحقق
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
        action: 'verify',
        payload: {
          outcome,
          paymentStatus,
          trxStatus,
          payment_reference: extractedRef,
          wallet_name: extractedWalletName,
          rawResponse
        }
      })
    });

    return res.status(200).json({
      success: isSuccess,
      outcome,
      status: finalStatus,
      payment_id: payment.id,
      payment_reference: extractedRef,
      payment_method: 'المحافظ الإلكترونية',
      wallet_name: extractedWalletName,
      trx_id: dataBody.trxId || null,
      payment_status_code: paymentStatus,
      message: userMessage,
      raw_details: rawResponse
    });
  } catch (error) {
    console.error('Verify error:', error);
    return res.status(500).json({
      success: false,
      error: 'خطأ أثناء التحقق من عملية الدفع',
      details: error.message
    });
  }
}
