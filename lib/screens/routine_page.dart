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

  Map<String, List<Map<String, TextEditingController>>> todaySets = {};
  Map<String, List<Map<String, dynamic>>> latestSession = {};

  @override
  void initState() {
    super.initState();
    fetchRoutine();
  }

  Future<void> fetchRoutine() async {
    try {
      final r = await supabase
          .from('routines')
          .select('name')
          .eq('id', widget.routineId)
          .single();
      routine = r;

      final data = await supabase
          .from('routine_exercises')
          .select('exercise_id, exercises(id, name)')
          .eq('routine_id', widget.routineId)
          .order('sort_order');

      exercises = List.from(data.map((e) => e['exercises']));

      for (var ex in exercises) {
        final exId = ex['id'] as String;
        todaySets[exId] = [
          {
            'weight': TextEditingController(),
            'reps': TextEditingController(),
          }
        ];
        await fetchLatestSession(exId);
        await preloadFirstSet(exId);
      }

      setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로드 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 가장 최근 세션
  Future<void> fetchLatestSession(String exId) async {
    final result = await supabase
        .from('exercise_history')
        .select()
        .eq('exercise_id', exId)
        .order('session_date', ascending: false)
        .order('date', ascending: false);

    if (result.isNotEmpty) {
      final latestDate = result.first['session_date'];
      final session = result
          .where((log) => log['session_date'] == latestDate)
          .toList();
      latestSession[exId] = session;
    } else {
      latestSession[exId] = [];
    }
  }

  // 첫 세트 자동 입력
  Future<void> preloadFirstSet(String exId) async {
    final first = await supabase
        .from('exercise_history')
        .select('weight')
        .eq('exercise_id', exId)
        .order('session_date', ascending: false)
        .order('date')
        .limit(1);

    if (first.isNotEmpty && first[0]['weight'] != null) {
      todaySets[exId]![0]['weight']!.text = first[0]['weight'].toString();
    }
  }

  void addSet(String exId) {
    setState(() {
      todaySets[exId]!.add({
        'weight': TextEditingController(),
        'reps': TextEditingController(),
      });
    });
  }

  void removeTodaySet(String exId, int index) {
    setState(() {
      todaySets[exId]![index]['weight']!.dispose();
      todaySets[exId]![index]['reps']!.dispose();
      todaySets[exId]!.removeAt(index);
    });
  }

  Future<void> deleteHistoryRecord(String historyId, String exId) async {
    try {
      await supabase.from('exercise_history').delete().eq('id', historyId);
      await fetchLatestSession(exId);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록 삭제됨'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> saveToday() async {
    if (loading) return;
    setState(() => loading = true);

    final now = DateTime.now();
    final sessionDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      for (var ex in exercises) {
        final exId = ex['id'] as String;
        final sets = todaySets[exId]!;

        for (var s in sets) {
          final w = s['weight']!.text.trim();
          final r = s['reps']!.text.trim();
          if (w.isEmpty || r.isEmpty) continue;

          await supabase.from('exercise_history').insert({
            'exercise_id': exId,
            'weight': int.parse(w),
            'reps': int.parse(r),
            'date': now.toIso8601String(),
            'session_date': sessionDateStr,
          });
        }

        if (sets[0]['weight']!.text.isNotEmpty) {
          await supabase.from('exercises').update({
            'last_weight': int.parse(sets[0]['weight']!.text),
            'last_reps': int.parse(sets[0]['reps']!.text),
          }).eq('id', exId);
        }

        for (var s in sets) {
          s['weight']!.clear();
          s['reps']!.clear();
        }
        todaySets[exId] = [todaySets[exId]![0]];
      }

      for (var ex in exercises) {
        await fetchLatestSession(ex['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 완료!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routine['name'] ?? '루틴')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: exercises.length,
        itemBuilder: (ctx, i) {
          final ex = exercises[i];
          final exId = ex['id'] as String;
          final exName = ex['name'] as String;
          final latest = latestSession[exId] ?? [];
          final sets = todaySets[exId]!;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 운동 이름
                  Text(
                    exName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽: 최근 기록 (스와이프 삭제)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("최근 기록",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 8),
                            if (latest.isEmpty)
                              const Text("기록 없음", style: TextStyle(color: Colors.grey))
                            else
                              ...latest.asMap().entries.map((entry) {
                                final log = entry.value;
                                return Dismissible(
                                  key: Key(log['id'].toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (_) => deleteHistoryRecord(log['id'].toString(), exId),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text("${log['weight']}kg × ${log['reps']}회"),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),

                      // 오른쪽: 오늘 입력 (X 버튼 삭제)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("오늘 입력",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 8),
                            ...sets.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final s = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Text("${idx + 1}세트: "),
                                    Expanded(
                                      child: TextField(
                                        controller: s['weight'],
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        decoration: const InputDecoration(hintText: "무게"),
                                      ),
                                    ),
                                    const Text(" × "),
                                    Expanded(
                                      child: TextField(
                                        controller: s['reps'],
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        decoration: const InputDecoration(hintText: "횟수"),
                                      ),
                                    ),
                                    if (idx > 0)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => removeTodaySet(exId, idx),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            TextButton.icon(
                              onPressed: () => addSet(exId),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text("세트 추가"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : saveToday,
        label: const Text("기록 저장"),
        icon: const Icon(Icons.save),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    for (var sets in todaySets.values) {
      for (var s in sets) {
        s['weight']!.dispose();
        s['reps']!.dispose();
      }
    }
    super.dispose();
  }
}