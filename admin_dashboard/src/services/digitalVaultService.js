import CryptoJS from 'crypto-js';
import { API_CONFIG } from '../config/apiConfig';

export class DigitalVaultService {
  static generateHeaders(method, pathWithQuery, bodyData = null) {
    const nowUtc = new Date().toISOString().split('.')[0] + 'Z';
    const nonce = Math.random().toString(36).substring(2) + Date.now().toString(36);
    
    let rawBody = '';
    if (bodyData) {
      rawBody = typeof bodyData === 'string' ? bodyData : JSON.stringify(bodyData);
    }
    
    const bodyHash = CryptoJS.SHA256(rawBody).toString(CryptoJS.enc.Hex).toLowerCase();
    
    const canonicalRequest = [
      method.toUpperCase(),
      pathWithQuery,
      nowUtc,
      nonce,
      bodyHash
    ].join('\n');
    
    const signature = CryptoJS.HmacSHA256(canonicalRequest, API_CONFIG.apiSecret)
      .toString(CryptoJS.enc.Hex)
      .toLowerCase();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Seller-Key': API_CONFIG.keyId,
      'X-Seller-Timestamp': nowUtc,
      'X-Seller-Nonce': nonce,
      'X-Seller-Signature': `sha256=${signature}`,
      'X-Request-ID': `admin_${Date.now()}`
    };
  }

  static async getSellerProfile() {
    const path = '/api/seller/v1/me';
    const headers = this.generateHeaders('GET', path);
    const resp = await fetch(`${API_CONFIG.baseUrl}/me`, { headers });
    return await resp.json();
  }

  static async getSellerWallet() {
    const path = '/api/seller/v1/wallet';
    const headers = this.generateHeaders('GET', path);
    const resp = await fetch(`${API_CONFIG.baseUrl}/wallet`, { headers });
    return await resp.json();
  }

  static async getCatalogProducts() {
    const path = '/api/seller/v1/catalog/products?limit=50';
    const headers = this.generateHeaders('GET', path);
    const resp = await fetch(`${API_CONFIG.baseUrl}/catalog/products?limit=50`, { headers });
    return await resp.json();
  }

  static async getSellerOrder(sellerOrderId) {
    const path = `/api/seller/v1/orders/${sellerOrderId}`;
    const headers = this.generateHeaders('GET', path);
    const resp = await fetch(`${API_CONFIG.baseUrl}/orders/${sellerOrderId}`, { headers });
    return await resp.json();
  }

  static async requestDeliveryAccess(sellerOrderId) {
    const path = `/api/seller/v1/orders/${sellerOrderId}/delivery-access`;
    const headers = this.generateHeaders('POST', path, {});
    headers['Idempotency-Key'] = `admin-token-${sellerOrderId}-${Date.now()}`;
    const resp = await fetch(`${API_CONFIG.baseUrl}/orders/${sellerOrderId}/delivery-access`, {
      method: 'POST',
      headers,
      body: '{}'
    });
    return await resp.json();
  }

  static async consumeDeliveryAccess(accessToken) {
    const path = '/api/seller/v1/delivery-access/consume';
    const body = { access_token: accessToken };
    const headers = this.generateHeaders('POST', path, body);
    const resp = await fetch(`${API_CONFIG.baseUrl}/delivery-access/consume`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body)
    });
    return await resp.json();
  }
}
