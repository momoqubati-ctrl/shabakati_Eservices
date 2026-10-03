import crypto from 'crypto';

const BASE_URL = process.env.VITE_DIGITAL_VAULT_BASE_URL || 'https://sahalnahaa.cloud/api/seller/v1';
const KEY_ID = process.env.VITE_DIGITAL_VAULT_KEY_ID || 'skey_01m37stgc9tpg5vsj5382rd8ra';
const API_SECRET = process.env.VITE_DIGITAL_VAULT_API_SECRET || 'ssec_96c632b8e715694af4b0fa62c8872cd2c99901fe0f13323c0cfb55251e335954';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    const { product_id, cursor, limit = '50' } = req.query || {};
    let endpointSubPath = '';
    if (product_id) {
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
    return res.status(response.status).json(data);
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'فشل في الاتصال بمزود الخدمات الرقمية: ' + error.message
    });
  }
}
