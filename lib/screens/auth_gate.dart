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

  Future<void> _nativeGoogleSignIn() async {
    setState(() => loading = true);

    try {
      // ✅ 네가 발급받은 client IDs로 바꿔야 함!
      const webClientId = '159229953169-bupa6vn8bp2e568qm7ab0sjvmuqa1oqr.apps.googleusercontent.com';
      const androidClientId = '159229953169-m1ojqa0njarbkg404d0d6qm9me9mr78s.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: androidClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw '로그인 취소됨';
      }

      final googleAuth = await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw '토큰이 비어 있습니다.';
      }

      // ✅ Supabase로 전달
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      }
    } catch (e, st) {
      debugPrint('Google 로그인 오류: $e\n$st');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google 로그인')),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Google 로그인'),
          onPressed: _nativeGoogleSignIn,
        ),
      ),
    );
  }
}
