// lib/services/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

const SUPABASE_URL = 'https://igumzxneamlhsmmxhuyd.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlndW16eG5lYW1saHNtbXhodXlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5MzMzODIsImV4cCI6MjA3NzUwOTM4Mn0.DpHS67ft6uijNIEQ2S-qNmgJrhZXyfc6DYb0hZdhzgE';

final supabase = Supabase.instance.client;