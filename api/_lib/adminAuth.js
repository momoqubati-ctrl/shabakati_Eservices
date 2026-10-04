const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co';

export async function verifyAdminAuth(req, supabaseAnon) {
  const authHeader = req.headers.authorization || '';
  const tokenMatch = authHeader.match(/^Bearer\s+(.+)$/i);
  const token = tokenMatch?.[1]?.trim();
  if (!token || !supabaseAnon) return false;

  try {
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        apikey: supabaseAnon,
        Authorization: `Bearer ${token}`
      }
    });
    if (!userRes.ok) return false;

    const user = await userRes.json();
    return user?.app_metadata?.role === 'admin';
  } catch {
    return false;
  }
}
