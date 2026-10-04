const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';

export function isExactPaidAmount(amount, expectedTotal) {
  const expectedAmount = Math.round(Number(expectedTotal));
  const paidAmount = Number(amount);
  return Number.isSafeInteger(expectedAmount) &&
    expectedAmount > 0 &&
    Number.isFinite(paidAmount) &&
    paidAmount === expectedAmount;
}

export function matchesRequestedAmount(amount, expectedTotal) {
  const expectedAmount = Math.round(Number(expectedTotal));
  const requestedAmount = Number(amount);
  return Number.isSafeInteger(expectedAmount) &&
    expectedAmount > 0 &&
    Number.isFinite(requestedAmount) &&
    Math.round(requestedAmount) === expectedAmount;
}

export async function calculateExpectedTotalYer(items, supabaseKey) {
  const [settingsRes, prodSettingsRes, cachedProdsRes] = await Promise.all([
    fetch(`${SUPABASE_URL}/rest/v1/app_settings?id=eq.general_settings&select=usd_to_yer_rate`, {
      headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` }
    }),
    fetch(`${SUPABASE_URL}/rest/v1/product_settings?select=product_id,custom_price_yer,is_active`, {
      headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` }
    }),
    fetch(`${SUPABASE_URL}/rest/v1/cached_products?select=id,price_cents`, {
      headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` }
    })
  ]);

  if (!settingsRes.ok || !prodSettingsRes.ok || !cachedProdsRes.ok) {
    const error = new Error('Unable to load canonical product pricing');
    error.code = 'PRICING_UNAVAILABLE';
    throw error;
  }

  const [settingsRows, productSettings, cachedProducts] = await Promise.all([
    settingsRes.json(),
    prodSettingsRes.json(),
    cachedProdsRes.json()
  ]);
  const exchangeRate = Number(settingsRows?.[0]?.usd_to_yer_rate) || 535;
  const customPricesMap = new Map(productSettings.map((item) => [Number(item.product_id), item]));
  const cachedPriceCentsMap = new Map(cachedProducts.map((item) => [Number(item.id), Number(item.price_cents) || 0]));

  return items.reduce((total, item) => {
    const productId = Number(item.product_id || item.product?.id);
    const quantity = Number(item.quantity || 1);
    if (!Number.isSafeInteger(productId) || productId <= 0 || !Number.isSafeInteger(quantity) || quantity < 1 || quantity > 50) {
      throw new Error('Invalid product or quantity');
    }

    const settings = customPricesMap.get(productId);
    if (settings?.is_active === false) {
      throw new Error('Product is inactive');
    }

    const customPrice = Number(settings?.custom_price_yer);
    const basePriceCents = cachedPriceCentsMap.get(productId) || 0;
    const unitPriceYer = customPrice > 0
      ? customPrice
      : basePriceCents > 0
        ? Math.ceil((((basePriceCents / 100) * exchangeRate) + 1000) / 1000) * 1000
        : 0;

    if (!Number.isFinite(unitPriceYer) || unitPriceYer <= 0) {
      throw new Error('Product has no server-side price');
    }
    return total + unitPriceYer * quantity;
  }, 0);
}
