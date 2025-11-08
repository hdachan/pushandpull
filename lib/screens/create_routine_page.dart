// lib/screens/create_routine_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import 'exercise_selector_page.dart';

class CreateRoutinePage extends StatefulWidget {
  final VoidCallback? onSaved;
  const CreateRoutinePage({this.onSaved, super.key});
  @override
  State<CreateRoutinePage> createState() => _CreateRoutinePageState();
}

class _CreateRoutinePageState extends State<CreateRoutinePage> {
  final _nameCtl = TextEditingController();
  final List<String> _selectedExerciseIds = [];
  String _type = 'main';          // 추가
  bool saving = false;
  final user = supabase.auth.currentUser;

  void pickExercises() async {
    final chosen = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseSelectorPage()),
    );
    if (chosen != null) setState(() => _selectedExerciseIds.addAll(chosen));
  }

  Future<void> handleSave() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty || _selectedExerciseIds.isEmpty) return;
    setState(() => saving = true);

    try {
      final routine = await supabase
          .from('routines')
          .insert({'user_id': user!.id, 'name': name, 'type': _type})
          .select('id')
          .single();
      final routineId = routine['id'] as String;

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('루틴 만들기')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: '루틴 이름')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: '루틴 타입'),
            items: const [
              DropdownMenuItem(value: 'main', child: Text('Main')),
              DropdownMenuItem(value: 'side', child: Text('Side')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: pickExercises,
              icon: const Icon(Icons.fitness_center),
              label: Text('운동 선택 (${_selectedExerciseIds.length})')),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: Future.wait(_selectedExerciseIds.map((id) async {
                return await supabase.from('exercises').select('id, name').eq('id', id).single();
              })),
              builder: (c, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!;
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final ex = list[i];
                    return ListTile(
                      title: Text(ex['name']),
                      trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => setState(() => _selectedExerciseIds.remove(ex['id']))),
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(onPressed: saving ? null : handleSave, child: const Text('저장')),
        ]),
      ),
    );
  }
}