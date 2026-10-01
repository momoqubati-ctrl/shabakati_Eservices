import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_PUBLISHABLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);

  try {
    const payload = req.body || {};
    const body = payload.body || payload;
    const orderId = body.orderId || body.order_id || body.order?.orderId;
    const paymentStatus = Number(body.paymentStatus ?? body.order?.paymentStatus ?? -1);

    if (orderId) {
      const isSuccess = paymentStatus === 1202;
      const dbStatus = isSuccess ? 'completed' : 'failed';

      await supabase.from('payments').update({
        status: dbStatus,
        updated_at: new Date().toISOString(),
        metadata: { webhook_payload: payload }
      }).eq('external_order_id', orderId);

      await supabase.from('payment_logs').insert({
        payment_id: orderId,
        action: 'webhook',
        payload
      });
    }

    return res.status(200).json({ success: true, message: 'Webhook received' });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
}
