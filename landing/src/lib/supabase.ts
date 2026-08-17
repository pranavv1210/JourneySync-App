import { createClient } from '@supabase/supabase-js';

const fallbackUrl = 'https://vvhzofxwiwlffyzyovlw.supabase.co';
const fallbackKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aHpvZnh3aXdsZmZ5enlvdmx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyMjc4MzAsImV4cCI6MjA4NjgwMzgzMH0.eSlUSJMJtANHnS91VG_ofZW_jO1j-d9zR51w7XqtFKU';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.VITE_SUPABASE_URL || fallbackUrl;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || fallbackKey;

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
  : null;
