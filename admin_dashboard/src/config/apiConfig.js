export const API_CONFIG = {
  // Digital Vault Seller API v1 (Routed securely via Vercel Backend Gateway)
  baseUrl: import.meta.env.VITE_DIGITAL_VAULT_BASE_URL || 'https://sahalnahaa.cloud/api/seller/v1',

  // Supabase Database & Realtime
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co',
  supabaseAnonKey: import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs',

  // Telegram bot info
  telegramBotUsername: import.meta.env.VITE_TELEGRAM_BOT_USERNAME || 'sahm',
};
