import crypto from 'crypto';
import { verifyAdminAuth } from './_lib/adminAuth.js';
import { getServerSecrets } from './_lib/serverSecrets.js';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    const secrets = await getServerSecrets();
    const BASE_URL = process.env.DIGITAL_VAULT_BASE_URL || process.env.VITE_DIGITAL_VAULT_BASE_URL || secrets.DIGITAL_VAULT_BASE_URL || 'https://sahalnahaa.cloud/api/seller/v1';
    const KEY_ID = process.env.DIGITAL_VAULT_KEY_ID || secrets.DIGITAL_VAULT_KEY_ID;
    const API_SECRET = process.env.DIGITAL_VAULT_API_SECRET || secrets.DIGITAL_VAULT_API_SECRET;
    const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || secrets.SUPABASE_SERVICE_ROLE_KEY;

    if (!KEY_ID || !API_SECRET) {
      return res.status(500).json({ success: false, error: 'إعدادات مزود الخدمة غير مكتملة في الخادم' });
    }

    const { action, product_id, cursor, limit = '50' } = req.query || {};
    let endpointSubPath = '';

    if (action === 'seller_profile' || action === 'seller_wallet') {
      const isAdmin = await verifyAdminAuth(req, SUPABASE_ANON);
      if (!isAdmin) {
        return res.status(401).json({ success: false, error: 'غير مصرح بالوصول لبيانات التاجر' });
      }
      endpointSubPath = action === 'seller_profile' ? '/me' : '/wallet';
    } else if (product_id) {
      endpointSubPath = `/catalog/products/${encodeURIComponent(product_id)}`;
    } else {
      const qs = new URLSearchParams();
      qs.set('limit', String(limit));
      if (cursor) qs.set('cursor', String(cursor));
      endpointSubPath = `/catalog/products?${qs.toString()}`;
    }

    const pathWithQuery = `/api/seller/v1${endpointSubPath}`;
    const nowUtc = new Date().toISOString().split('.')[0] + 'Z';
    const nonce = crypto.randomBytes(16).toString('hex');
    const bodyHash = crypto.createHash('sha256').update('').digest('hex').toLowerCase();

    const canonicalRequest = [
      'GET',
      pathWithQuery,
      nowUtc,
      nonce,
      bodyHash
    ].join('\n');

    const signature = crypto
      .createHmac('sha256', API_SECRET)
      .update(canonicalRequest)
      .digest('hex')
      .toLowerCase();

    const response = await fetch(`${BASE_URL}${endpointSubPath}`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'X-Seller-Key': KEY_ID,
        'X-Seller-Timestamp': nowUtc,
        'X-Seller-Nonce': nonce,
        'X-Seller-Signature': `sha256=${signature}`,
        'X-Request-ID': `gw_${Date.now()}`
      }
    });

    const data = await response.json();

    if (response.ok && SUPABASE_KEY && Array.isArray(data?.data) && data.data.length > 0) {
      const rowsToCache = data.data
        .filter(p => p && Number.isSafeInteger(Number(p.id)))
        .map(p => ({
          id: Number(p.id),
          name: String(p.name || ''),
          price_cents: Number(p.seller_price?.amount_cents || p.price_cents || 0),
          currency: String(p.seller_price?.currency || p.currency || 'USD'),
          updated_at: new Date().toISOString()
        }));
      if (rowsToCache.length > 0) {
        await fetch(`${SUPABASE_URL}/rest/v1/cached_products`, {
          method: 'POST',
          headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates'
          },
          body: JSON.stringify(rowsToCache)
        }).catch(() => {});
      }
    }

    return res.status(response.status).json(data);
  } catch (error) {
    console.error('Catalog API error:', error.message);
    return res.status(500).json({
      success: false,
      error: 'تعذر جلب البيانات من مزود الخدمة حالياً'
    });
  }
}
