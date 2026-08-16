// Single shared Supabase client. The anon key is public by design — Row Level
// Security is the actual boundary. Never put service-role keys here.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'https://FILL_ME.supabase.co';
const SUPABASE_ANON_KEY = 'FILL_ME';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
