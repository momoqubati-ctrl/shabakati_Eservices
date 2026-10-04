import crypto from 'crypto';
import { getServerSecrets } from './_lib/serverSecrets.js';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';


export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { phone, raw_phone, channel = 'whatsapp' } = req.body || {};

    if (!phone) {
      return res.status(400).json({ success: false, error: 'رقم الهاتف مطلوب' });
    }

    // إزالة أي إشارة + أو مسافات أو رموز غير رقمية بشكل قاطع
    let cleanPhone = String(phone).replace(/[^0-9]/g, '');

    // معالجة الصفر الزائد بعد كود الدولة (مثلاً 9670777... تحول إلى 967777...)
    if (cleanPhone.startsWith('9670')) {
      cleanPhone = '967' + cleanPhone.substring(4);
    } else if (cleanPhone.startsWith('0') && cleanPhone.length === 10) {
      cleanPhone = '967' + cleanPhone.substring(1);
    } else if (!cleanPhone.startsWith('967') && cleanPhone.length === 9) {
      cleanPhone = '967' + cleanPhone;
    }

    if (cleanPhone.length < 9 || cleanPhone.length > 15) {
      return res.status(400).json({ success: false, error: 'رقم الهاتف غير صالح' });
    }

    const secrets = await getServerSecrets();
    const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || secrets.SUPABASE_SERVICE_ROLE_KEY;
    if (!SUPABASE_KEY) {
      return res.status(500).json({ success: false, error: 'إعدادات الخادم غير مكتملة' });
    }

    // 1. توليد رمز OTP عشوائي آمن من 4 أرقام داخل الخادم حصرياً
    const generatedOtp = String(crypto.randomInt(1000, 10000));
    const phoneKey = String(raw_phone || ('+' + cleanPhone)).trim();

    // 2. حفظ الرمز في قاعدة بيانات Supabase عبر الدالة المؤمنة مع فحص Rate Limiting
    const otpSaveRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/rpc_create_phone_otp`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        p_phone: phoneKey,
        p_clean_phone: cleanPhone,
        p_otp: generatedOtp,
        p_channel: channel
      })
    });

    const otpSaveData = otpSaveRes.ok ? await otpSaveRes.json() : null;
    if (otpSaveData && otpSaveData.error === 'RATE_LIMITED') {
      return res.status(429).json({
        success: false,
        error: 'تم تجاوز الحد المسموح لطلبات رمز التحقق، يرجى الانتظار دقائق قبل المحاولة مجدداً'
      });
    }
    if (!otpSaveRes.ok || (otpSaveData && otpSaveData.success === false)) {
      return res.status(500).json({
        success: false,
        error: 'تعذر إنشاء رمز التحقق في الخادم'
      });
    }

    // 3. إرسال رمز التحقق عبر بوابة الواتساب دون إرجاعه في استجابة الشبكة للعميل
    const token = process.env.WHATSAPP_TOKEN || process.env.VITE_WHATSAPP_TOKEN || secrets.WHATSAPP_TOKEN;
    const from = process.env.WHATSAPP_FROM || process.env.VITE_WHATSAPP_FROM || secrets.WHATSAPP_FROM || '967737241475';

    if (!token) {
      return res.status(500).json({ success: false, error: 'إعدادات بوابة الرسائل غير مكتملة' });
    }

    const text = `مرحباً بك في بوابة شبكتي للخدمات الرقمية.\n\nرمز التحقق الخاص بحسابك هو:\n${generatedOtp}\n\nصالح لمدة 5 دقائق. لا تشارك هذا الرمز مع أي شخص.`;
    const endpoint = 'https://whatsqubatibot-9x83.onrender.com/api/qr/rest/send_message';

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45000);

    const response = await fetch(endpoint, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        messageType: 'text',
        requestType: 'POST',
        token,
        from,
        to: cleanPhone,
        text
      })
    });

    clearTimeout(timeout);

    if (!response.ok) {
      return res.status(502).json({
        success: false,
        error: 'تعذر إرسال رسالة الواتساب في الوقت الحالي'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'تم إرسال رمز التحقق عبر واتساب بنجاح'
    });
  } catch (error) {
    console.error('Send OTP error:', error.message);
    return res.status(500).json({
      success: false,
      error: 'حدث خطأ أثناء إرسال رمز التحقق عبر الخادم'
    });
  }
}
