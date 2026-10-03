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
    const { phone, otp, channel = 'whatsapp' } = req.body || {};

    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }

    const cleanOtp = String(otp || '').trim();
    if (!/^\d{4,6}$/.test(cleanOtp)) {
      return res.status(400).json({ success: false, error: 'رمز التحقق غير صالح' });
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

    const token = process.env.WHATSAPP_TOKEN || 
                  process.env.VITE_WHATSAPP_TOKEN || 
                  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI5OGQ0MjI1ZTNhNzc4NjE4ZDdkZDcyNGFlOTI4M2ZiNiIsInJvbGUiOiJ1c2VyIiwiaWF0IjoxNzkwNTM5NTMzfQ.LBj3W0Kq2gIaaMIPwj8V-_sueQhesA812qj4Eyksv_s';

    const from = process.env.WHATSAPP_FROM || 
                 process.env.VITE_WHATSAPP_FROM || 
                 '967737241475';

    // تقييد نص الرسالة بقالب التحقق الرسمي فقط لمنع إساءة الاستخدام كمرسل رسائل عشوائية (Anti-Spam)
    const text = `مرحباً بك في بوابة شبكتي للخدمات الرقمية.\n\nرمز التحقق لتسجيل حسابك هو:\n${cleanOtp}\n\nصالح لمدة 5 دقائق. لا تشارك هذا الرمز مع أي شخص.`;

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

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'فشل في إرسال رسالة الواتساب عبر الخادم: ' + error.message
    });
  }
}
