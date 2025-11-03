import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_client.dart';

class RoutinePage extends StatefulWidget {
  final String routineId;
  const RoutinePage({required this.routineId, super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  bool loading = true;
  Map<String, dynamic> routine = {};
  List<Map<String, dynamic>> exercises = [];
  Map<String, List<Map<String, String>>> localSets = {};
  Map<String, List<Map<String, dynamic>>> history = {}; // 운동별 기록 캐시

  @override
  void initState() {
    super.initState();
    fetchRoutine();
  }

  Future<void> fetchRoutine() async {
    try {
      // 루틴 정보 불러오기
      final r = await supabase
          .from('routines')
          .select('id, name')
          .eq('id', widget.routineId)
          .single();
      routine = r;

      // 루틴에 포함된 운동 불러오기
      final data = await supabase
          .from('routine_exercises')
          .select('exercise_id, exercises(id, name, last_weight, last_reps)')
          .eq('routine_id', widget.routineId)
          .order('sort_order');

      exercises = List<Map<String, dynamic>>.from(
        data.map((row) => row['exercises'] as Map<String, dynamic>),
      );

      // 각 운동별 로컬 상태 + 히스토리 불러오기
      for (var ex in exercises) {
        final exId = ex['id'] as String;
        localSets[exId] = [{'weight': '', 'reps': ''}];
        await fetchHistory(exId);
      }

      setState(() => loading = false);
    } catch (e) {
      debugPrint('Error fetching routine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('데이터 로드 실패: $e')));
      }
    }
  }

  Future<void> fetchHistory(String exId) async {
    final data = await supabase
        .from('exercise_history')
        .select()
        .eq('exercise_id', exId)
        .order('date', ascending: false);

    setState(() {
      history[exId] = List<Map<String, dynamic>>.from(data);
    });
  }

  void updateLocal(String exId, String field, String val) {
    final filtered = val.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      localSets[exId]![0][field] = filtered;
    });
  }

  Future<void> handleSave() async {
    setState(() => loading = true);
    final now = DateTime.now().toIso8601String();

    for (var ex in exercises) {
      final exId = ex['id'] as String;
      final set = localSets[exId]!.first;
      final weightStr = set['weight']!;
      final repsStr = set['reps']!;

      if (weightStr.isEmpty || repsStr.isEmpty) continue;

      final weight = int.parse(weightStr);
      final reps = int.parse(repsStr);

      // 🔹 1) history 테이블에 새 기록 추가
      await supabase.from('exercise_history').insert({
        'exercise_id': exId,
        'weight': weight,
        'reps': reps,
        'date': now,
      });

      // 🔹 2) exercises 테이블 최신값 갱신
      await supabase.from('exercises').update({
        'last_weight': weight,
        'last_reps': reps,
      }).eq('id', exId);

      await fetchHistory(exId);
      localSets[exId] = [{'weight': '', 'reps': ''}];
    }

    setState(() => loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장 완료!')));
    }
  }

  Future<void> deleteLog(String exId, String logId) async {
    await supabase.from('exercise_history').delete().eq('id', logId);
    await fetchHistory(exId);

    // 최근 기록이 없으면 exercises 최신값 초기화
    final latest =
    history[exId]?.isNotEmpty == true ? history[exId]!.first : null;
    await supabase.from('exercises').update({
      'last_weight': latest?['weight'],
      'last_reps': latest?['reps'],
    }).eq('id', exId);
  }

  Future<void> editLog(String exId, Map<String, dynamic> log) async {
    final weightController =
    TextEditingController(text: log['weight'].toString());
    final repsController = TextEditingController(text: log['reps'].toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('기록 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '무게 (kg)'),
              ),
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '횟수'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final weight = int.tryParse(weightController.text) ?? 0;
                final reps = int.tryParse(repsController.text) ?? 0;

                await supabase.from('exercise_history').update({
                  'weight': weight,
                  'reps': reps,
                }).eq('id', log['id']);

                await fetchHistory(exId);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.parse(iso).toLocal();
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routine['name'] ?? '루틴')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (var ex in exercises)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ex['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text(
                          '최근: ${ex['last_weight'] ?? '-'}kg / ${ex['last_reps'] ?? '-'}회',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                          const InputDecoration(hintText: '무게'),
                          onChanged: (v) =>
                              updateLocal(ex['id'], 'weight', v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                          const InputDecoration(hintText: '횟수'),
                          onChanged: (v) =>
                              updateLocal(ex['id'], 'reps', v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (history[ex['id']]?.isNotEmpty == true) ...[
                      const Text('기록 이력',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      for (var log in history[ex['id']]!)
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${log['weight']}kg × ${log['reps']}회'),
                              Text(
                                _formatDate(log['date']),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600]),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 16, color: Colors.blue),
                                    onPressed: () =>
                                        editLog(ex['id'], log),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 16, color: Colors.red),
                                    onPressed: () =>
                                        deleteLog(ex['id'], log['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                    const Divider(),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('기록 저장'),
          ),
        ],
      ),
    );
  }
}
