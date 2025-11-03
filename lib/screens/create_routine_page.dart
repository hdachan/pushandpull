// 루틴 생성 화면 – 이름 입력 + 운동 여러 개 추가 → DB 저장 후 돌아감.
import 'package:flutter/material.dart';
import '../services/supabase_client.dart';

class CreateRoutinePage extends StatefulWidget {
  final VoidCallback? onSaved;
  const CreateRoutinePage({this.onSaved, super.key});

  @override
  State<CreateRoutinePage> createState() => _CreateRoutinePageState();
}

class _CreateRoutinePageState extends State<CreateRoutinePage> {
  final _nameCtl = TextEditingController();
  final List<TextEditingController> _exerciseCtls = [TextEditingController()];
  bool saving = false;
  final user = supabase.auth.currentUser;

  void addExerciseField() => setState(() => _exerciseCtls.add(TextEditingController()));
  void removeExerciseField(int i) => setState(() => _exerciseCtls.removeAt(i));

  Future<void> handleSave() async {
    final name = _nameCtl.text.trim();
    final exercises = _exerciseCtls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (name.isEmpty || exercises.isEmpty) return;
    setState(() => saving = true);

    final routine = await supabase.from('routines').insert({'user_id': user!.id, 'name': name}).select('id').single();
    final routineId = routine['id'] as String;

    for (var i = 0; i < exercises.length; i++) {
      final exName = exercises[i];
      final existing = await supabase.from('exercises').select('id').eq('user_id', user!.id).eq('name', exName).limit(1);
      String exId;
      if (existing.isNotEmpty) {
        exId = existing[0]['id'];
      } else {
        final ins = await supabase.from('exercises').insert({'user_id': user!.id, 'name': exName}).select('id').single();
        exId = ins['id'];
      }
      await supabase.from('routine_exercises').insert({'routine_id': routineId, 'exercise_id': exId, 'sort_order': i});
    }

    setState(() => saving = false);
    widget.onSaved?.call();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('루틴 만들기')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: '루틴 이름')),
          Expanded(
            child: ListView.builder(
              itemCount: _exerciseCtls.length,
              itemBuilder: (context, i) => Row(children: [
                Expanded(child: TextField(controller: _exerciseCtls[i], decoration: InputDecoration(labelText: '운동 ${i + 1}'))),
                IconButton(onPressed: () => removeExerciseField(i), icon: const Icon(Icons.delete)),
              ]),
            ),
          ),
          ElevatedButton(onPressed: addExerciseField, child: const Text('+ 운동 추가')),
          ElevatedButton(onPressed: saving ? null : handleSave, child: const Text('저장')),
        ]),
      ),
    );
  }
}