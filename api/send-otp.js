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
    const { phone, otp, message, channel = 'whatsapp' } = req.body || {};

    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }

    const cleanPhone = String(phone).replace(/[^0-9]/g, '');

    const token = process.env.WHATSAPP_TOKEN || process.env.VITE_WHATSAPP_TOKEN;
    const from = process.env.WHATSAPP_FROM || process.env.VITE_WHATSAPP_FROM;

    if (!token || !from) {
      return res.status(500).json({
        success: false,
        error: 'WhatsApp configuration is missing in server environment variables (.env)'
      });
    }

    const text = message || `مرحباً بك في بوابة شبكتي للخدمات الرقمية.\n\nرمز التحقق لتسجيل حسابك هو:\n* ${otp} *\n\nصالح لمدة 5 دقائق. لا تشارك هذا الرمز مع أي شخص.`;

    const endpoint = 'https://whatsqubatibot-9x83.onrender.com/api/qr/rest/send_message';

    const response = await fetch(endpoint, {
      method: 'POST',
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

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'فشل في إرسال رسالة الواتساب عبر الخادم: ' + error.message
    });
  }
}
