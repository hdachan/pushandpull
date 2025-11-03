import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_client.dart';
import 'home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = false;

  // Firebase 호스팅 URL (배포용, 로컬 개발 시 localhost로 변경)
  static const String _firebaseUrl = 'https://pushandpull-5a6f3.web.app/'; // ← 실제 URL로 변경!

  Future<void> signInWithGoogle() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? '$_firebaseUrl/__/auth/handler' : null,  // 웹: Firebase, 모바일: 자동
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault  // 웹: 기본
            : LaunchMode.externalApplication,  // 모바일: 시스템 브라우저 강제 (disallowed_useragent 해결!)
      );
    } catch (e) {
      print('OAuth Error: $e');  // flutter logs로 확인
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();

    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  HomePage()),
        );
      }
    });

    if (supabase.auth.currentUser != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  HomePage()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RoutineFit 로그인'),
        centerTitle: true,
      ),
      body: Center(
        child: loading
            ? const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('로그인 중...'),
          ],
        )
            : ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('구글 로그인'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          onPressed: signInWithGoogle,
        ),
      ),
    );
  }
}