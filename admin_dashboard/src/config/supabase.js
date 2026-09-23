import { createClient } from '@supabase/supabase-js';
import { API_CONFIG } from './apiConfig';

export const supabase = createClient(
  API_CONFIG.supabaseUrl,
  API_CONFIG.supabaseAnonKey
);
