// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import 'create_routine_page.dart';
import 'routine_page.dart';
import 'auth_gate.dart';

class HomePage extends StatefulWidget {
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
    final data = await supabase.from('routines').select().eq('user_id', user!.id);
    setState(() {
      routines = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthGate()));
    }
  }

  void openRoutine(String id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RoutinePage(routineId: id)));
  }

  void gotoCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRoutinePage(onSaved: fetchRoutines),
      ),
    );
  }

  Future<void> _deleteRoutine(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('루틴 삭제'),
        content: Text('"$name" 루틴을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => loading = true);
    await supabase.from('routines').delete().eq('id', id);
    await fetchRoutines();
  }

  /// ✅ 루틴 이름 수정 함수 추가
  Future<void> _editRoutineName(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('루틴 이름 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '새 루틴 이름'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    setState(() => loading = true);
    await supabase.from('routines').update({'name': newName}).eq('id', id);
    await fetchRoutines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 루틴'),
        actions: [
          IconButton(onPressed: signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : routines.isEmpty
          ? const Center(child: Text('루틴이 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: routines.length,
        itemBuilder: (context, i) {
          final r = routines[i];
          return Card(
            child: ListTile(
              title: Text(r['name'] ?? '이름 없음'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => openRoutine(r['id']),
                    child: const Text('시작'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editRoutineName(r['id'], r['name']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteRoutine(r['id'], r['name']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: gotoCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
