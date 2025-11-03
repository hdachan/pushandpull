// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'services/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );
  runApp(const RoutineApp());
}

class RoutineApp extends StatelessWidget {
  const RoutineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoutineFit',
      home: AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}