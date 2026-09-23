export const API_CONFIG = {
  // Digital Vault Seller API v1
  baseUrl: import.meta.env.VITE_DIGITAL_VAULT_BASE_URL || 'https://sahalnahaa.cloud/api/seller/v1',
  keyId: import.meta.env.VITE_DIGITAL_VAULT_KEY_ID || '',
  apiSecret: import.meta.env.VITE_DIGITAL_VAULT_API_SECRET || '',

  // Supabase Database & Realtime
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL || 'https://enutfwspwrzpvhmtgftl.supabase.co',
  supabaseAnonKey: import.meta.env.VITE_SUPABASE_ANON_KEY || '',

  // Telegram bot info
  telegramBotUsername: import.meta.env.VITE_TELEGRAM_BOT_USERNAME || 'ShabaktiBot',
};
