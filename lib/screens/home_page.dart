// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:pushpull/screens/results_page.dart';
import '../services/supabase_client.dart';
import 'create_routine_page.dart';
import 'exercise_list_page.dart';
import 'routine_page.dart';
import 'auth_gate.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> routines = [];
  bool loading = true;
  final user = supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    fetchRoutines();
  }

  Future<void> fetchRoutines() async {
    setState(() => loading = true);
    final data = await supabase
        .from('routines')
        .select()
        .eq('user_id', user!.id)
        .order('created_at');
    setState(() {
      routines = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
    }
  }

  void openRoutine(String id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RoutinePage(routineId: id)));
  }

  void gotoCreate() async {
    final needRefresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateRoutinePage(onSaved: fetchRoutines)),
    );
    if (needRefresh == true) fetchRoutines();
  }

  Future<void> _deleteRoutine(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('루틴 삭제'),
        content: Text('"$name" 를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => loading = true);
    await supabase.from('routines').delete().eq('id', id);
    await fetchRoutines();
  }

  Future<void> _editRoutineName(String id, String cur) async {
    final ctrl = TextEditingController(text: cur);
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('루틴 이름 수정'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: '새 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('저장')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == cur) return;
    setState(() => loading = true);
    await supabase.from('routines').update({'name': newName}).eq('id', id);
    await fetchRoutines();
  }

  @override
  Widget build(BuildContext context) {
    final mainRoutines = routines.where((r) => r['type'] == 'main').toList();
    final sideRoutines = routines.where((r) => r['type'] == 'side').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 루틴'),
        actions: [
          IconButton(onPressed: signOut, icon: const Icon(Icons.logout)),
          IconButton(
              icon: const Icon(Icons.fitness_center, color: Colors.deepOrange),
              tooltip: '운동 관리',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseListPage()))),
          IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.green),
              tooltip: '결과 보기',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsPage()))),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : routines.isEmpty
          ? const Center(child: Text('루틴이 없습니다.'))
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (mainRoutines.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Main 루틴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...mainRoutines.map((r) => Card(
              child: ListTile(
                title: Text(r['name'] ?? '이름 없음'),
                onTap: () => openRoutine(r['id']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editRoutineName(r['id'], r['name'])),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRoutine(r['id'], r['name'])),
                  ],
                ),
              ),
            )),
          ],
          if (sideRoutines.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Side 루틴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...sideRoutines.map((r) => Card(
              child: ListTile(
                title: Text(r['name'] ?? '이름 없음'),
                onTap: () => openRoutine(r['id']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editRoutineName(r['id'], r['name'])),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRoutine(r['id'], r['name'])),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: gotoCreate, child: const Icon(Icons.add)),
    );
  }
}