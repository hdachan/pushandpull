import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  /// ✅ 앱 시작 시 세션 체크
  void _checkSession() {
    final user = supabase.auth.currentUser;
    if (user != null && mounted) {
      // 이미 로그인 되어 있으면 바로 HomePage로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  HomePage()),
        );
      });
    }

    // 🔹 인증 상태 변화 감지 (웹 로그인 후 돌아올 때)
    supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  HomePage()),
        );
      }
    });
  }

  /// 모바일 (Android/iOS)용 Google 로그인
  Future<void> _nativeGoogleSignIn() async {
    setState(() => loading = true);
    try {
      const webClientId =
          '159229953169-bupa6vn8bp2e568qm7ab0sjvmuqa1oqr.apps.googleusercontent.com';
      const androidClientId =
          '159229953169-m1ojqa0njarbkg404d0d6qm9me9mr78s.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn(
        clientId: androidClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw '로그인 취소됨';

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null || accessToken == null) throw '토큰이 비어 있습니다.';

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e, st) {
      debugPrint('Google 로그인 오류: $e\n$st');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  /// 웹(Web) 환경용 Google 로그인
  Future<void> _webGoogleSignIn() async {
    setState(() => loading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // 배포용 URL
         redirectTo: 'https://pushandpull-5a6f3.web.app/auth/callback',
        // 로컬 테스트용 URL
         //redirectTo: 'http://localhost:8000/auth/callback',
      );
    } catch (e) {
      debugPrint('🌐 웹 Google 로그인 오류: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('웹 로그인 실패: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  /// 환경에 따라 자동 분기
  Future<void> _signInWithGoogle() async {
    if (kIsWeb) {
      await _webGoogleSignIn();
    } else {
      await _nativeGoogleSignIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google 로그인')),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : kIsWeb
            ? ElevatedButton.icon(
          icon: const Icon(Icons.web, color: Colors.white),
          label: const Text('웹 Google 로그인'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 16),
            textStyle:
            const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _webGoogleSignIn,
        )
            : ElevatedButton.icon(
          icon: const Icon(Icons.phone_android, color: Colors.white),
          label: const Text('모바일 Google 로그인'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 16),
            textStyle:
            const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _nativeGoogleSignIn,
        ),
      ),
    );
  }
}
