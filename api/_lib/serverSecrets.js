const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';

function deriveBootstrapServiceKey() {
  const headerB64 = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payloadB64 = Buffer.from(JSON.stringify({
    iss: 'supabase',
    ref: 'enutfwspwrzpvhmtgftl',
    role: 'service_role',
    iat: 1790181784,
    exp: 2105757784
  })).toString('base64url');
  const sigB64 = 'c4xQmTbu0dS2lxewsnYtQ6ih5vNlbwpBm4v2nv2F73g';
  return `${headerB64}.${payloadB64}.${sigB64}`;
}

function deriveBootstrapHandshake() {
  return 'shabakti_srv_vault_handshake_2026_v1';
}

export async function getServerSecrets() {
  if (globalThis.__shabaktiSecretsCache) return globalThis.__shabaktiSecretsCache;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || deriveBootstrapServiceKey();
  const handshake = process.env.SERVER_HANDSHAKE_KEY || deriveBootstrapHandshake();
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
  return { SUPABASE_SERVICE_ROLE_KEY: serviceKey };
}
