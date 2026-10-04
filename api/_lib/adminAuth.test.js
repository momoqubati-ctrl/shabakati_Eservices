import test from 'node:test';
import assert from 'node:assert/strict';

const { verifyAdminAuth } = await import('./adminAuth.js');

test('accepts only an authenticated user with server-managed admin role', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_url, options) => ({
    ok: true,
    json: async () => options.headers.Authorization === 'Bearer valid-token'
      ? { app_metadata: { role: 'admin' } }
      : { app_metadata: { role: 'user' } }
  });

  try {
    assert.equal(await verifyAdminAuth({ headers: { authorization: 'Bearer valid-token' } }, 'test-anon-key'), true);
    assert.equal(await verifyAdminAuth({ headers: { authorization: 'Bearer missing-role' } }, 'test-anon-key'), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('does not trust user-editable role claims and rejects invalid sessions', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({ user_metadata: { role: 'admin' } })
  });

  try {
    assert.equal(await verifyAdminAuth({ headers: { authorization: 'Bearer regular-user' } }, 'test-anon-key'), false);
    assert.equal(await verifyAdminAuth({ headers: { authorization: 'regular-user' } }, 'test-anon-key'), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
