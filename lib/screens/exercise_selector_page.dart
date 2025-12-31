// lib/screens/exercise_selector_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../component/design_components.dart';
import '../services/supabase_client.dart';
// 🎨 디자인 컴포넌트 임포트

class ExerciseSelectorPage extends StatefulWidget {
  const ExerciseSelectorPage({super.key});
  @override
  State<ExerciseSelectorPage> createState() => _ExerciseSelectorPageState();
}

class _ExerciseSelectorPageState extends State<ExerciseSelectorPage> {
  List<Map<String, dynamic>> allExercises = [];
  final Set<String> selected = {};
  bool loading = true;
  final userId = supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    loadExercises();
  }

  /// 🔹 데이터 로드 및 가나다순 정렬 함수
  Future<void> loadExercises() async {
    try {
      // 1. Supabase에서 name 기준으로 오름차순(ascending) 정렬 요청
      final data = await supabase
          .from('exercises')
          .select('id, name')
          .eq('user_id', userId)
          .order('name', ascending: true);

      // 2. Dart 언어 차원에서 한 번 더 확실하게 가나다순 정렬 (DB collation 이슈 방지)
      final List<Map<String, dynamic>> sortedList = List<Map<String, dynamic>>.from(data);
      sortedList.sort((a, b) {
        final nameA = a['name'] as String;
        final nameB = b['name'] as String;
        return nameA.compareTo(nameB); // 한글 가나다순 비교
      });

      setState(() {
        allExercises = sortedList;
        loading = false;
      });
    } catch (e) {
      // 에러 처리 필요 시 구현
      setState(() => loading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else {
        selected.add(id);
      }
    });
  }

  void _onComplete() {
    Navigator.pop(context, selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D3436);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '운동 선택',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. 공통 배경 컴포넌트 사용
          const AtmosphericBackground(),

          // 2. 메인 리스트
          if (loading)
            const Center(child: CupertinoActivityIndicator())
          else if (allExercises.isEmpty)
            Center(
              child: Text(
                '등록된 운동이 없습니다.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            SafeArea(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                itemCount: allExercises.length,
                itemBuilder: (context, index) {
                  final ex = allExercises[index];
                  final id = ex['id'] as String;
                  final name = ex['name'] as String;
                  final isSelected = selected.contains(id);

                  return _buildSelectionCard(id, name, isSelected);
                },
              ),
            ),

          // 3. 하단 완료 버튼
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FloatingBottomButton(
              label: selected.isEmpty
                  ? '선택 완료'
                  : '${selected.length}개 선택 완료',
              onPressed: _onComplete,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 선택용 카드 위젯
  Widget _buildSelectionCard(String id, String name, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blueAccent.withOpacity(0.15)
                  : Colors.black.withOpacity(0.02),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.black87 : const Color(0xFF2D3436),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.blueAccent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.blueAccent : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}