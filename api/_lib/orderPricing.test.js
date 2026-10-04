import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateExpectedTotalYer,
  isExactPaidAmount,
  matchesRequestedAmount
} from './orderPricing.js';

function mockPricingFetch({ active = true, cachedPriceCents = 1000, customPriceYer = null, ok = true } = {}) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    if (url.includes('/app_settings')) {
      return { ok, json: async () => [{ usd_to_yer_rate: 535 }] };
    }
    if (url.includes('/product_settings')) {
      return { ok, json: async () => [{ product_id: 12, is_active: active, custom_price_yer: customPriceYer }] };
    }
    return { ok, json: async () => [{ id: 12, price_cents: cachedPriceCents }] };
  };
  return () => {
    globalThis.fetch = originalFetch;
  };
}

test('calculates totals from server pricing and ignores client-provided unit prices', async () => {
  const restoreFetch = mockPricingFetch();
  try {
    const total = await calculateExpectedTotalYer(
      [{ product_id: 12, quantity: 2, unit_price_cents: 1 }],
      'service-role-key'
    );
    assert.equal(total, 14000);
  } finally {
    restoreFetch();
  }
});

test('uses configured custom pricing and rejects inactive or unpriced products', async () => {
  let restoreFetch = mockPricingFetch({ customPriceYer: 1250 });
  try {
    assert.equal(await calculateExpectedTotalYer([{ product_id: 12, quantity: 1 }], 'service-role-key'), 1250);
  } finally {
    restoreFetch();
  }

  restoreFetch = mockPricingFetch({ active: false });
  try {
    await assert.rejects(
      calculateExpectedTotalYer([{ product_id: 12, quantity: 1 }], 'service-role-key'),
      /inactive/
    );
  } finally {
    restoreFetch();
  }

  restoreFetch = mockPricingFetch({ cachedPriceCents: 0 });
  try {
    await assert.rejects(
      calculateExpectedTotalYer([{ product_id: 12, quantity: 1 }], 'service-role-key'),
      /no server-side price/
    );
  } finally {
    restoreFetch();
  }
});

test('fails closed when canonical pricing cannot be loaded', async () => {
  const restoreFetch = mockPricingFetch({ ok: false });
  try {
    await assert.rejects(
      calculateExpectedTotalYer([{ product_id: 12, quantity: 1 }], 'service-role-key'),
      { code: 'PRICING_UNAVAILABLE' }
    );
  } finally {
    restoreFetch();
  }
});

test('requires the settled payment to equal the canonical amount exactly', () => {
  assert.equal(isExactPaidAmount(10000, 10000), true);
  assert.equal(isExactPaidAmount(9500, 10000), false);
  assert.equal(isExactPaidAmount(9999, 10000), false);
  assert.equal(isExactPaidAmount(10001, 10000), false);
  assert.equal(isExactPaidAmount(10000, 0), false);
});

test('only permits initiation when the requested amount rounds to the server total', () => {
  assert.equal(matchesRequestedAmount(10000, 10000), true);
  assert.equal(matchesRequestedAmount(9500, 10000), false);
  assert.equal(matchesRequestedAmount(10001, 10000), false);
  assert.equal(matchesRequestedAmount('not-a-number', 10000), false);
});
