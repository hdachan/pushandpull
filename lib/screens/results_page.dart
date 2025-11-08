// lib/screens/results_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_client.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool loading = true;
  Map<String, List<Map<String, dynamic>>> sessions = {};

  @override
  void initState() {
    super.initState();
    fetchAllHistory();
  }

  Future<void> fetchAllHistory() async {
    final userId = supabase.auth.currentUser!.id;

    final exerciseIds = await supabase
        .from('exercises')
        .select('id')
        .eq('user_id', userId)
        .then((d) => d.map((e) => e['id'] as String).toList());

    if (exerciseIds.isEmpty) {
      setState(() => loading = false);
      return;
    }

    final data = await supabase
        .from('exercise_history')
        .select('*, exercises(name)')
        .inFilter('exercise_id', exerciseIds)
        .order('session_date', ascending: false)
        .order('date', ascending: false);

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var log in data) {
      final date = log['session_date'] as String;
      grouped.putIfAbsent(date, () => []).add(log);
    }

    setState(() {
      sessions = grouped;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('날짜별 기록')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? const Center(child: Text('기록이 없습니다'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sessions.length,
        itemBuilder: (_, i) {
          final entry = sessions.entries.elementAt(i);
          final date = entry.key;
          final logs = entry.value;

          // 같은 운동끼리 묶기
          final Map<String, List<Map<String, dynamic>>> byExercise = {};
          for (var log in logs) {
            final name = log['exercises']['name'] as String;
            byExercise.putIfAbsent(name, () => []).add(log);
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ExpansionTile(
              initiallyExpanded: i == 0, // 최신 날짜 펼침
              title: Text(
                date,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${logs.length}개 기록'),
              children: byExercise.entries.map((ex) {
                final exName = ex.key;
                final sets = ex.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      ...sets.asMap().entries.map((s) {
                        final idx = s.key + 1;
                        final log = s.value;
                        return Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            '$idx세트: ${log['weight']}kg × ${log['reps']}회',
                            style: const TextStyle(fontSize: 15),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}