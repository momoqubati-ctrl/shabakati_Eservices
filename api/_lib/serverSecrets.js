const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';

export async function getServerSecrets() {
  if (globalThis.__shabaktiSecretsCache) return globalThis.__shabaktiSecretsCache;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
  const handshake = process.env.SERVER_HANDSHAKE_KEY;
  if (!serviceKey || !handshake) return {};
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/rpc_get_backend_secrets`, {
      method: 'POST',
      headers: {
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ p_handshake: handshake })
    });
    if (res.ok) {
      const data = await res.json();
      if (data && typeof data === 'object') {
        if (!data.SUPABASE_SERVICE_ROLE_KEY) {
          data.SUPABASE_SERVICE_ROLE_KEY = serviceKey;
        }
        globalThis.__shabaktiSecretsCache = data;
        return data;
      }
    }
  } catch (_) {}
  return {};
}
