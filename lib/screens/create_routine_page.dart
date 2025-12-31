// lib/screens/create_routine_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../component/design_components.dart';
import '../services/supabase_client.dart';
import 'exercise_selector_page.dart';
// ⬇️ 방금 만든 디자인 컴포넌트 임포트 (경로 확인해주세요)


class CreateRoutinePage extends StatefulWidget {
  final VoidCallback? onSaved;
  const CreateRoutinePage({this.onSaved, super.key});
  @override
  State<CreateRoutinePage> createState() => _CreateRoutinePageState();
}

class _CreateRoutinePageState extends State<CreateRoutinePage> {
  final _nameCtl = TextEditingController();
  final List<String> _selectedExerciseIds = [];
  String _type = 'main';
  bool saving = false;
  final user = supabase.auth.currentUser;

  /// 운동 선택 화면 이동
  void pickExercises() async {
    final chosen = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseSelectorPage()),
    );
    if (chosen != null && mounted) {
      setState(() => _selectedExerciseIds.addAll(chosen));
    }
  }

  /// 저장 로직 (Supabase)
  Future<void> handleSave() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty || _selectedExerciseIds.isEmpty) return;
    setState(() => saving = true);

    try {
      // 1. 루틴 생성
      final routine = await supabase
          .from('routines')
          .insert({'user_id': user!.id, 'name': name, 'type': _type})
          .select('id')
          .single();
      final routineId = routine['id'] as String;

      // 2. 루틴 내 운동 연결
      final inserts = _selectedExerciseIds
          .asMap()
          .entries
          .map((e) => {
        'routine_id': routineId,
        'exercise_id': e.value,
        'sort_order': e.key * 10,
        'type': _type
      })
          .toList();

      await supabase.from('routine_exercises').insert(inserts);

      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
          '새 루틴 만들기',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. 분리한 배경 컴포넌트 사용
          const AtmosphericBackground(),

          // 2. 메인 컨텐츠
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: [
                      // 루틴 이름
                      const SectionTitle('루틴 이름'),
                      const SizedBox(height: 8),
                      GlassTextField(
                        controller: _nameCtl,
                        hintText: '예: 가슴 박살내기',
                      ),

                      const SizedBox(height: 24),

                      // 루틴 타입 (컴포넌트에 상태 전달)
                      const SectionTitle('루틴 타입'),
                      const SizedBox(height: 8),
                      TypeSelector(
                        selectedType: _type,
                        onTypeChanged: (val) => setState(() => _type = val),
                      ),

                      const SizedBox(height: 24),

                      // 운동 목록 헤더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SectionTitle('선택된 운동 (${_selectedExerciseIds.length})'),
                          SmallAddButton(onTap: pickExercises),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 운동 목록 리스트
                      if (_selectedExerciseIds.isEmpty)
                        _buildEmptyState()
                      else
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: Future.wait(_selectedExerciseIds.map((id) async {
                            return await supabase
                                .from('exercises')
                                .select('id, name')
                                .eq('id', id)
                                .single();
                          })),
                          builder: (c, snap) {
                            if (!snap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: CupertinoActivityIndicator(),
                              );
                            }
                            final list = snap.data!;
                            return Column(
                              children: list.map((ex) {
                                return ExerciseCard(
                                  name: ex['name'],
                                  onRemove: () => setState(
                                          () => _selectedExerciseIds.remove(ex['id'])),
                                );
                              }).toList(),
                            );
                          },
                        ),

                      const SizedBox(height: 100), // 하단 버튼 공간 확보
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. 하단 저장 버튼 컴포넌트
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FloatingBottomButton(
              label: '루틴 저장하기',
              isLoading: saving,
              onPressed: saving ? null : handleSave,
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 메시지는 간단해서 여기 둠 (원하면 이것도 컴포넌트로 이동 가능)
  Widget _buildEmptyState() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      alignment: Alignment.center,
      child: Text(
        '운동을 추가해주세요.',
        style: TextStyle(color: Colors.grey[500]),
      ),
    );
  }
}