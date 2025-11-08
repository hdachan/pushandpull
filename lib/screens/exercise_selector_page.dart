// lib/screens/exercise_selector_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_client.dart';

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

  Future<void> loadExercises() async {
    final data = await supabase
        .from('exercises')
        .select('id, name')
        .eq('user_id', userId)
        .order('name');
    setState(() {
      allExercises = List.from(data);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운동 선택')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: allExercises.map((ex) {
          final id = ex['id'] as String;
          return CheckboxListTile(
            title: Text(ex['name']),
            value: selected.contains(id),
            onChanged: (v) {
              setState(() {
                v! ? selected.add(id) : selected.remove(id);
              });
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () => Navigator.pop(context, selected.toList()),
      ),
    );
  }
}