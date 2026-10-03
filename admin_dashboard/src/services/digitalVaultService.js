import { supabase } from '../config/supabase';

export class DigitalVaultService {
  static async getAuthHeaders() {
    const headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    };
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.access_token) {
        headers['Authorization'] = `Bearer ${session.access_token}`;
      }
    } catch (_) {}
    return headers;
  }

  static async getSellerProfile() {
    const headers = await this.getAuthHeaders();
    const resp = await fetch('/api/catalog?action=seller_profile', { headers });
    return await resp.json();
  }

  static async getSellerWallet() {
    const headers = await this.getAuthHeaders();
    const resp = await fetch('/api/catalog?action=seller_wallet', { headers });
    return await resp.json();
  }

  static async getCatalogProducts() {
    const headers = await this.getAuthHeaders();
    const resp = await fetch('/api/catalog?limit=50', { headers });
    return await resp.json();
  }

  static async getSellerOrder(sellerOrderId) {
    const headers = await this.getAuthHeaders();
    const resp = await fetch(`/api/orders?seller_order_id=${encodeURIComponent(sellerOrderId)}`, { headers });
    const text = await resp.text();
    let data = null;
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { success: false, error: text };
    }
    return { ...data, httpStatus: resp.status, ok: resp.ok, rawText: text };
  }

  static async getOrders(limit = 20) {
    const headers = await this.getAuthHeaders();
    const resp = await fetch(`/api/orders?action=list&limit=${encodeURIComponent(limit)}`, { headers });
    const text = await resp.text();
    let data = null;
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { success: false, error: text };
    }
    return { ...data, httpStatus: resp.status, ok: resp.ok, rawText: text };
  }

  static async createOrder({ externalOrderId, items }) {
    const headers = await this.getAuthHeaders();
    const body = {
      external_order_id: externalOrderId,
      items: (items || []).map(i => ({
        product_id: Number(i.product_id),
        quantity: Number(i.quantity || 1)
      }))
    };
    const resp = await fetch('/api/orders', {
      method: 'POST',
      headers,
      body: JSON.stringify(body)
    });
    const text = await resp.text();
    let data = null;
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { success: false, error: text };
    }
    return { ...data, httpStatus: resp.status, ok: resp.ok, rawText: text };
  }

  static generateUUID() {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID();
    }
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  static async requestDeliveryAccess(sellerOrderId) {
    const headers = await this.getAuthHeaders();
    const resp = await fetch(`/api/orders?action=consume_key&seller_order_id=${encodeURIComponent(sellerOrderId)}`, {
      method: 'GET',
      headers
    });
    const text = await resp.text();
    let data = null;
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { success: false, error: text };
    }
    return { ...data, httpStatus: resp.status, ok: resp.ok, rawText: text };
  }

  static async consumeDeliveryAccess(accessTokenOrAssets) {
    if (accessTokenOrAssets && typeof accessTokenOrAssets === 'object' && accessTokenOrAssets.assets) {
      return { success: true, ok: true, httpStatus: 200, data: accessTokenOrAssets };
    }
    return { success: false, ok: false, httpStatus: 400, error: 'Use requestDeliveryAccess via backend' };
  }

  static async requestCancellation(sellerOrderId, reason) {
    const headers = await this.getAuthHeaders();
    const resp = await fetch('/api/orders', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        action: 'cancel',
        seller_order_id: sellerOrderId,
        reason: (reason || 'إلغاء الطلب بناء على رغبة العميل').substring(0, 500)
      })
    });
    const text = await resp.text();
    let data = null;
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { success: false, error: text };
    }
    return { ...data, httpStatus: resp.status, ok: resp.ok, rawText: text };
  }
}
