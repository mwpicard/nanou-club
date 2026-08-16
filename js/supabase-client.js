// Single shared Supabase client. The anon key is public by design — Row Level
// Security is the actual boundary. Never put service-role keys here.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'https://qrwkqnhdcoftikeancxr.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFyd2txbmhkY29mdGlrZWFuY3hyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5MTM4ODAsImV4cCI6MjEwMjQ4OTg4MH0.TBdHyB9UxNKuFMjzCL8qoPawGnjr4SsGxasGclLgaL4';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
