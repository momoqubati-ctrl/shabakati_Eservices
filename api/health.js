export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  return res.status(200).json({
    status: 'online',
    service: 'Shabakti E-Services Backend Gateway',
    domain: 'https://shabakati-eservices.vercel.app',
    timestamp: new Date().toISOString(),
    realtime_enabled: true
  });
}
