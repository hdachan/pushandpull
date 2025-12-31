import 'dart:ui'; // 블러 효과를 위해 추가
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // iOS 스타일 로딩 인디케이터
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

  /// ✅ 앱 시작 시 세션 체크 (로직 유지)
  void _checkSession() {
    final user = supabase.auth.currentUser;
    if (user != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      });
    }

    supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      }
    });
  }

  /// 모바일 (Android/iOS)용 Google 로그인 (로직 유지)
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// 웹(Web) 환경용 Google 로그인 (로직 유지)
  Future<void> _webGoogleSignIn() async {
    setState(() => loading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://pushandpull-5a6f3.web.app/auth/callback',
      );
    } catch (e) {
      debugPrint('🌐 웹 Google 로그인 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('웹 로그인 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 배경: 은은한 그라데이션 (프리미엄 화이트/그레이 톤)
    return Scaffold(
      body: Stack(
        children: [
          // 1. 배경 (Atmospheric Background)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF5F7FA), // 아주 밝은 회색
                  Color(0xFFC3CFE2), // 부드러운 블루 그레이
                ],
              ),
            ),
          ),

          // 2. 배경 장식용 흐릿한 원 (Floating Orbs)
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -30,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.05),
              ),
            ),
          ),

          // 3. 전체 블러 처리 (Frosted Glass Effect 전체 적용)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.white.withOpacity(0.01)),
          ),

          // 4. 메인 컨텐츠
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 및 앱 이름 영역
                _buildLogoSection(),

                const SizedBox(height: 80),

                // 로그인 버튼 영역 (로딩 상태 처리)
                if (loading)
                  const CupertinoActivityIndicator(radius: 16) // iOS 스타일 로딩
                else
                  _buildFloatingButton(
                    onTap: kIsWeb ? _webGoogleSignIn : _nativeGoogleSignIn,
                    text: 'Google로 계속하기',
                    icon: Icons.g_mobiledata_rounded, // 깔끔한 아이콘
                  ),

                const SizedBox(height: 30),

                // 하단 캡션
                Text(
                  "밀고 당기는 확실한 방법",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 로고 및 타이틀 섹션 (깔끔하고 고급스러운 타이포그래피)
  Widget _buildLogoSection() {
    return Column(
      children: [
        // 아이콘 대신 텍스트 중심의 미니멀리즘
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.swap_vert_rounded, // Push & Pull을 상징하는 아이콘
            size: 40,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '밀고땡겨',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3436), // 진한 차콜색
            letterSpacing: -0.5,
            fontFamily: '.SF Pro Display', // iOS 기본 폰트 느낌 (없으면 기본값)
          ),
        ),
      ],
    );
  }

  /// 🔹 iOS 스타일 프리미엄 버튼 (Glassmorphism + Soft Shadow)
  Widget _buildFloatingButton({
    required VoidCallback onTap,
    required String text,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280, // 버튼 너비 고정
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), // 둥근 알약 형태
          boxShadow: [
            // 부드럽게 퍼지는 그림자 (Floating 효과)
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 구글 로고 대신 심플한 아이콘 사용 (원하시면 이미지로 교체 가능)
            Icon(Icons.login_rounded, color: Colors.grey[800], size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2D3436),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}