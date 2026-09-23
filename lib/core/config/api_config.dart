class ApiConfig {
  // Live Vercel Backend Gateway Domain
  static const String vercelBackendUrl = String.fromEnvironment(
    'VERCEL_BACKEND_URL',
    defaultValue: 'https://shabakati-eservices.vercel.app',
  );

  // Digital Vault Seller API v1
  static const String baseUrl = String.fromEnvironment(
    'DIGITAL_VAULT_BASE_URL',
    defaultValue: 'https://sahalnahaa.cloud/api/seller/v1',
  );
  
  static const String keyId = String.fromEnvironment(
    'DIGITAL_VAULT_KEY_ID',
    defaultValue: 'skey_01m37stgc9tpg5vsj5382rd8ra',
  );
  
  static const String apiSecret = String.fromEnvironment(
    'DIGITAL_VAULT_API_SECRET',
    defaultValue: 'ssec_96c632b8e715694af4b0fa62c8872cd2c99901fe0f13323c0cfb55251e335954',
  );

  // Telegram Bot Support Configuration
  static const String telegramBotUsername = String.fromEnvironment(
    'TELEGRAM_BOT_USERNAME',
    defaultValue: 'ShabaktiBot',
  );
  
  static const String telegramChannelUsername = String.fromEnvironment(
    'TELEGRAM_CHANNEL_USERNAME',
    defaultValue: 'shabakti_services',
  );
  
  static const String defaultSupportLink = 'https://t.me/ShabaktiBot';

  // Supabase Backend Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://enutfwspwrzpvhmtgftl.supabase.co',
  );
  
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudXRmd3Nwd3J6cHZobXRnZnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxODE3ODQsImV4cCI6MjEwNTc1Nzc4NH0.dRgwtfHV1OYWxeFKDon030mwesEIx_993cOQiAABTRs',
  );

  // Order processing constants
  static const int maxProcessingHours = 24;
}
