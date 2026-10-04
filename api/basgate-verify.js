import crypto from 'crypto';
import { getServerSecrets } from './_lib/serverSecrets.js';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';


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

    const secrets = await getServerSecrets();
    const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || secrets.SUPABASE_SERVICE_ROLE_KEY;
    if (!SUPABASE_KEY) {
      return res.status(500).json({ success: false, error: 'إعدادات الخادم غير مكتملة' });
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
    if (payment.status === 'completed' || payment.status === 'consumed') {
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

    const appId = secrets.BASGATE_LIVE_APP_ID || process.env.BASGATE_LIVE_APP_ID || process.env.BASGATE_APP_ID;
    const clientId = secrets.BASGATE_LIVE_CLIENT_ID || process.env.BASGATE_LIVE_CLIENT_ID || process.env.BASGATE_CLIENT_ID;
    const clientSecret = secrets.BASGATE_LIVE_CLIENT_SECRET || process.env.BASGATE_LIVE_CLIENT_SECRET || process.env.BASGATE_CLIENT_SECRET;
    const envMKey = process.env.BASGATE_LIVE_MKEY || process.env.BASGATE_MKEY;
    const validEnvMKey = (envMKey && !envMKey.startsWith('---')) ? envMKey : null;
    const mKey = secrets.BASGATE_LIVE_MKEY || validEnvMKey || clientSecret;

    const authUrl = process.env.BASGATE_LIVE_AUTH_URL || 'https://app.basgate.com/api/v1/auth/token';
    const statusUrl = process.env.BASGATE_LIVE_STATUS_URL || 'https://app.basgate.com/api/v1/merchant/sdk-payment/get-transaction-status';

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
        error: 'فشل التوثيق مع بوابة الدفع للتحقق من المعاملة'
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
        updated_at: new Date().toISOString(),
        metadata: {
          ...(payment.metadata || {}),
          verify_outcome: outcome,
          payment_status_code: paymentStatus,
          payment_reference: extractedRef,
          wallet_name: extractedWalletName,
          sdk_result_status,
          sdk_message
        }
      })
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
        action: 'verify',
        payload: {
          outcome,
          paymentStatus,
          trxStatus,
          sdk_result_status
        }
      })
    });

    return res.status(200).json({
      success: isSuccess,
      outcome,
      is_pending: isPending,
      payment_id: payment.id,
      payment_reference: extractedRef,
      payment_method: 'المحافظ الإلكترونية',
      wallet_name: extractedWalletName,
      order_id: payment.external_order_id,
      status: finalStatus,
      payment_status_code: paymentStatus,
      message: userMessage
    });
  } catch (error) {
    console.error('Verify error:', error.message);
    return res.status(500).json({
      success: false,
      error: 'حدث خطأ أثناء التحقق من حالة الدفع'
    });
  }
}
