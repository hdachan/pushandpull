// lib/screens/routine_page_logic.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_client.dart';
import 'exercise_selector_page.dart';

class RoutinePageLogic {
  bool loading = true;
  Map<String, dynamic> routine = {};
  List<Map<String, dynamic>> exercises = [];
  Map<String, List<Map<String, dynamic>>> todaySets = {};
  Map<String, List<Map<String, dynamic>>> latestSession = {};
  bool hasUnsavedChanges = false;

  late String routineId;
  late BuildContext context;
  late void Function(void Function()) setStateCallback;

  void init(String id, BuildContext ctx, void Function(void Function()) setStateFn) {
    routineId = id;
    context = ctx;
    setStateCallback = setStateFn;
    fetchRoutine();
  }

  Future<void> fetchRoutine() async {
    try {
      final r = await supabase.from('routines').select('name').eq('id', routineId).single();
      routine = r;

      final data = await supabase
          .from('routine_exercises')
          .select('exercise_id, exercises(id, name)')
          .eq('routine_id', routineId)
          .order('sort_order');

      exercises = List.from(data.map((e) => e['exercises']));

      for (final ex in exercises) {
        final exId = ex['id'] as String;
        todaySets[exId] = [];
        await loadTodayInputs(exId);
        if (todaySets[exId]!.isEmpty) {
          todaySets[exId]!.add({
            'weight': TextEditingController(),
            'reps': TextEditingController(),
            'id': null,
            'set_group': 1,
          });
        }
        await fetchLatestSession(exId);
      }
      setStateCallback(() => loading = false);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로드 실패: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> loadTodayInputs(String exId) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final logs = await supabase
        .from('exercise_history')
        .select('id, weight, reps, set_group')
        .eq('exercise_id', exId)
        .eq('session_date', today)
        .order('set_group, date');

    final sets = <Map<String, dynamic>>[];

    // 기존 set_group 유지 (UI 정렬용)
    int maxGroup = 0;
    for (final log in logs) {
      final group = log['set_group'] as int? ?? 1;
      maxGroup = group > maxGroup ? group : maxGroup;
      sets.add({
        'weight': TextEditingController(text: log['weight']?.toString() ?? ''),
        'reps': TextEditingController(text: log['reps']?.toString() ?? ''),
        'id': log['id'] as String?,
        'set_group': group,
      });
    }

    if (sets.isEmpty) {
      sets.add({
        'weight': TextEditingController(),
        'reps': TextEditingController(),
        'id': null,
        'set_group': 1,
      });
    }

    todaySets[exId] = sets;
    _addInputListeners(exId);
  }

  Future<void> fetchLatestSession(String exId) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final lastDateRes = await supabase
        .from('exercise_history')
        .select('session_date')
        .eq('exercise_id', exId)
        .not('session_date', 'eq', today)
        .order('session_date', ascending: false)
        .limit(1);

    if (lastDateRes.isEmpty) {
      latestSession[exId] = [];
      return;
    }

    final latestDate = lastDateRes.first['session_date'] as String;
    final session = await supabase
        .from('exercise_history')
        .select('id, weight, reps, set_group')
        .eq('exercise_id', exId)
        .eq('session_date', latestDate)
        .order('set_group, date');

    latestSession[exId] = session;
  }

  void _addInputListeners(String exId) {
    for (var s in todaySets[exId]!) {
      (s['weight'] as TextEditingController).addListener(_checkUnsavedChanges);
      (s['reps'] as TextEditingController).addListener(_checkUnsavedChanges);
    }
  }

  void _checkUnsavedChanges() {
    if (loading) return;
    final changed = todaySets.values.any((sets) => sets.any((s) =>
    (s['weight'] as TextEditingController).text.isNotEmpty ||
        (s['reps'] as TextEditingController).text.isNotEmpty));
    if (changed != hasUnsavedChanges) {
      setStateCallback(() => hasUnsavedChanges = changed);
    }
  }

  void addSet(String exId) {
    setStateCallback(() {
      final lastGroup = todaySets[exId]!.isEmpty ? 0 : todaySets[exId]!.last['set_group'] as int;
      todaySets[exId]!.add({
        'weight': TextEditingController(),
        'reps': TextEditingController(),
        'id': null,
        'set_group': lastGroup + 1,
      });
      _addInputListeners(exId);
      _checkUnsavedChanges();
    });
  }

  void addDropSet(String exId, int idx) {
    final parentSet = todaySets[exId]![idx];
    final parentWeight = double.tryParse((parentSet['weight'] as TextEditingController).text) ?? 0;
    final dropWeight = parentWeight > 0 ? (parentWeight * 0.8).toStringAsFixed(1) : '';

    setStateCallback(() {
      final group = parentSet['set_group'] as int;
      todaySets[exId]!.insert(idx + 1, {
        'weight': TextEditingController(text: dropWeight),
        'reps': TextEditingController(),
        'id': null,
        'set_group': group,
      });
      _addInputListeners(exId);
      _checkUnsavedChanges();
    });
  }

  Future<void> removeTodaySet(String exId, int idx) async {
    setStateCallback(() {
      final s = todaySets[exId]![idx];
      (s['weight'] as TextEditingController).dispose();
      (s['reps'] as TextEditingController).dispose();
      todaySets[exId]!.removeAt(idx);
      _checkUnsavedChanges();
    });
  }

  Future<void> saveToday() async {
    if (loading) return;
    setStateCallback(() => loading = true);
    final now = DateTime.now();
    final sess = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      for (final ex in exercises) {
        final exId = ex['id'] as String;
        final sets = todaySets[exId]!;

        // 1. 오늘 세션 전체 삭제
        await supabase
            .from('exercise_history')
            .delete()
            .eq('exercise_id', exId)
            .eq('session_date', sess);

        // 2. 유효한 세트만 필터링 + set_group 재정렬
        final validSets = <Map<String, dynamic>>[];
        for (final s in sets) {
          final w = (s['weight'] as TextEditingController).text.trim();
          final r = (s['reps'] as TextEditingController).text.trim();
          if (w.isEmpty || r.isEmpty) continue;
          validSets.add({
            'weight': double.parse(w),
            'reps': int.parse(r),
            'original_group': s['set_group'] as int, // 드롭세트 판단용
          });
        }

        // 3. set_group 재할당 (1, 2, 3...)
        int newGroup = 1;
        Map<String, dynamic>? firstValidSet;
        bool isFirstInGroup = true;

        for (int i = 0; i < validSets.length; i++) {
          final vs = validSets[i];
          final origGroup = vs['original_group'] as int;
          final isFirst = i == 0 || validSets[i - 1]['original_group'] != origGroup;

          if (isFirst) {
            newGroup = i == 0 ? 1 : newGroup + 1;
            isFirstInGroup = true;
          }

          final isDrop = !isFirstInGroup;

          await supabase.from('exercise_history').insert({
            'exercise_id': exId,
            'weight': vs['weight'],
            'reps': vs['reps'],
            'date': now.toIso8601String(),
            'session_date': sess,
            'set_group': newGroup,
            'is_drop': isDrop,
          });

          if (isFirstInGroup) {
            firstValidSet ??= {
              'weight': TextEditingController(text: vs['weight'].toString()),
              'reps': TextEditingController(text: vs['reps'].toString()),
            };
            isFirstInGroup = false;
          }
        }

        // 4. 첫 번째 세트로 last_weight 업데이트
        if (firstValidSet != null) {
          await supabase.from('exercises').update({
            'last_weight': double.parse((firstValidSet['weight'] as TextEditingController).text),
            'last_reps': int.parse((firstValidSet['reps'] as TextEditingController).text),
          }).eq('id', exId);
        }
      }

      // 5. UI 갱신 (재정렬된 set_group 반영)
      for (final ex in exercises) {
        await loadTodayInputs(ex['id'] as String);
        await fetchLatestSession(ex['id'] as String);
      }

      setStateCallback(() => hasUnsavedChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 완료!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red));
    } finally {
      setStateCallback(() => loading = false);
    }
  }

  Future<void> addExerciseToRoutine() async {
    final chosen = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseSelectorPage()),
    );
    if (chosen == null || chosen.isEmpty) return;
    setStateCallback(() => loading = true);
    try {
      final maxSort = await supabase
          .from('routine_exercises')
          .select('sort_order')
          .eq('routine_id', routineId)
          .order('sort_order', ascending: false)
          .limit(1)
          .then((d) => d.isEmpty ? 0 : d.first['sort_order'] as int);
      final inserts = <Map<String, dynamic>>[];
      for (var i = 0; i < chosen.length; i++) {
        final exId = chosen[i];
        final exists = await supabase
            .from('routine_exercises')
            .select('id')
            .eq('routine_id', routineId)
            .eq('exercise_id', exId)
            .limit(1);
        if (exists.isEmpty) {
          inserts.add({'routine_id': routineId, 'exercise_id': exId, 'sort_order': maxSort + (i + 1) * 10});
        }
      }
      if (inserts.isNotEmpty) await supabase.from('routine_exercises').insert(inserts);
      await fetchRoutine();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('운동 추가 완료!'), backgroundColor: Colors.blue));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('추가 실패: $e'), backgroundColor: Colors.red));
    } finally {
      setStateCallback(() => loading = false);
    }
  }

  Future<void> removeExerciseFromRoutine(String exId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('운동 삭제'),
        content: const Text('이 운동을 루틴에서 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제', style: TextStyle(color:  Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await supabase.from('routine_exercises').delete().eq('routine_id', routineId).eq('exercise_id', exId);
    await fetchRoutine();
  }

  Future<bool> onWillPop(BuildContext context) async {
    if (hasUnsavedChanges) {
      final save = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('저장되지 않은 변경'),
          content: const Text('입력한 내용이 저장되지 않았습니다. 저장하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('버리기')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('저장', style: TextStyle(color: Colors.green))),
          ],
        ),
      );
      if (save == true) {
        await saveToday();
        return true;
      }
      return save != null;
    }
    return true;
  }

  void dispose() {
    for (final sets in todaySets.values) {
      for (final s in sets) {
        (s['weight'] as TextEditingController).dispose();
        (s['reps'] as TextEditingController).dispose();
      }
    }
  }
}