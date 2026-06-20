class AppConfig {
  // In-app defaults so release/debug builds work without --dart-define.
  // --dart-define values can still override these when needed.
  static const String supabaseUrl = 'https://vvhzofxwiwlffyzyovlw.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aHpvZnh3aXdsZmZ5enlvdmx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyMjc4MzAsImV4cCI6MjA4NjgwMzgzMH0.eSlUSJMJtANHnS91VG_ofZW_jO1j-d9zR51w7XqtFKU';
  static const String authRedirectUrl = 'journeysync://login-callback';
  static const String supabaseAvatarBucket = 'avatars';
}
