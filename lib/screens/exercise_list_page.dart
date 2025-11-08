// lib/screens/exercise_list_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import 'package:intl/intl.dart'; // 이 줄 추가!

class ExerciseListPage extends StatefulWidget {
  const ExerciseListPage({super.key});
  @override
  State<ExerciseListPage> createState() => _ExerciseListPageState();
}

class _ExerciseListPageState extends State<ExerciseListPage> {
  List<Map<String, dynamic>> exercises = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> groupedHistory = {};
  bool loading = true;
  final userId = supabase.auth.currentUser!.id;
  final weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String _getWeekday(String dateStr) {
    final date = DateFormat('yyyy-MM-dd').parse(dateStr);
    return weekdays[date.weekday - 1]; // 월=1 → index 0
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    final exData = await supabase.from('exercises').select().eq('user_id', userId).order('name');
    exercises = List.from(exData);

    final newGrouped = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (final ex in exercises) {
      final exId = ex['id'] as String;
      final hist = await supabase
          .from('exercise_history')
          .select()
          .eq('exercise_id', exId)
          .order('session_date', ascending: false);

      final dayMap = <String, List<Map<String, dynamic>>>{};
      for (final log in hist) {
        final date = log['session_date'] as String;
        final day = _getWeekday(date);
        dayMap.putIfAbsent(day, () => []).add(log);
      }
      newGrouped[exId] = dayMap;
    }

    setState(() {
      groupedHistory = newGrouped;
      loading = false;
    });
  }

  Future<void> addExercise() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('새 운동 추가'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('추가')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await supabase.from('exercises').insert({'user_id': userId, 'name': name});
    loadData();
  }

  Future<void> editExercise(String id, String cur) async {
    final ctrl = TextEditingController(text: cur);
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('운동 이름 수정'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('저장')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == cur) return;
    await supabase.from('exercises').update({'name': newName}).eq('id', id);
    loadData();
  }

  Future<void> deleteExercise(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('운동 삭제'),
        content: Text('"$name" 를 삭제하면 기록도 함께 사라집니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await supabase.from('exercises').delete().eq('id', id);
    loadData();
  }

  Future<void> deleteRecord(String id) async {
    await supabase.from('exercise_history').delete().eq('id', id);
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운동 관리')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : exercises.isEmpty
          ? const Center(child: Text('운동이 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: exercises.length,
        itemBuilder: (_, i) {
          final ex = exercises[i];
          final exId = ex['id'] as String;
          final dayLogs = groupedHistory[exId] ?? {};

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              title: Text(
                ex['name'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => editExercise(exId, ex['name'])),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteExercise(exId, ex['name'])),
                ],
              ),
              children: dayLogs.isEmpty
                  ? [const ListTile(title: Text('기록 없음', style: TextStyle(color: Colors.grey)))]
                  : dayLogs.entries.map((dayEntry) {
                final dayName = dayEntry.key;
                final logs = dayEntry.value;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 8),
                      ...logs.map((log) {
                        final date = log['session_date'] as String;
                        final sets = logs
                            .where((l) => l['session_date'] == date)
                            .toList()
                          ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '  $date',
                              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                            ),
                            ...sets.asMap().entries.map((s) {
                              final idx = s.key + 1;
                              final l = s.value;
                              return Padding(
                                padding: const EdgeInsets.only(left: 16, top: 2),
                                child: Row(
                                  children: [
                                    Text('$idx세트: '),
                                    Text('${l['weight']}kg × ${l['reps']}회'),
                                    const Spacer(),
                                    IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () => deleteRecord(l['id'].toString()),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints()),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: addExercise, child: const Icon(Icons.add)),
    );
  }
}