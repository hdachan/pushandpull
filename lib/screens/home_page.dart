// lib/screens/home_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pushpull/screens/results_page.dart';
import '../services/supabase_client.dart';
import 'create_routine_page.dart';
import 'exercise_list_page.dart';
import 'routine_page.dart';
import 'auth_gate.dart';
// 🎨 디자인 컴포넌트들 임포트
import '../component/design_components.dart';
import '../component/routine_components.dart'; // 🌟 방금 만든 파일

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

  /// 데이터 로딩
  Future<void> fetchRoutines() async {
    setState(() => loading = true);
    try {
      final data = await supabase
          .from('routines')
          .select()
          .eq('user_id', user!.id)
          .order('created_at');
      setState(() {
        routines = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => loading = false);
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const AuthGate()));
    }
  }

  void openRoutine(String id) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => RoutinePage(routineId: id)));
  }

  void gotoCreate() async {
    final needRefresh = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateRoutinePage(onSaved: fetchRoutines)),
    );
    if (needRefresh == true) fetchRoutines();
  }

  Future<void> _deleteRoutine(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('루틴 삭제'),
        content: Text('"$name" 를 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => loading = true);
    await supabase.from('routines').delete().eq('id', id);
    await fetchRoutines();
  }

  /// ✅ 루틴 수정 (별도 위젯 사용으로 코드가 매우 깔끔해짐)
  Future<void> _editRoutine(String id, String curName, String curType) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => RoutineEditDialog(
          initialName: curName,
          initialType: curType
      ),
    );

    if (result == null) return;
    if (result['name'] == curName && result['type'] == curType) return;

    setState(() => loading = true);
    await supabase.from('routines').update({
      'name': result['name'],
      'type': result['type'],
    }).eq('id', id);

    await fetchRoutines();
  }

  @override
  Widget build(BuildContext context) {
    final mainRoutines = routines.where((r) => r['type'] == 'main').toList();
    final sideRoutines = routines.where((r) => r['type'] == 'side').toList();
    const textColor = Color(0xFF2D3436);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('내 루틴',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.fitness_center, color: Colors.deepOrange),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExerciseListPage()))),
          IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.green),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ResultsPage()))),
          IconButton(
              onPressed: signOut,
              icon: const Icon(Icons.logout, color: textColor)),
        ],
      ),
      body: Stack(
        children: [
          const AtmosphericBackground(), // 배경 컴포넌트
          SafeArea(
            child: loading
                ? const Center(child: CupertinoActivityIndicator())
                : routines.isEmpty
                ? Center(
              child: Text(
                '루틴이 없습니다.\n+ 버튼을 눌러 추가하세요!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
                : ListView(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 10, bottom: 80),
              children: [
                if (mainRoutines.isNotEmpty) ...[
                  // 🌟 분리한 헤더 컴포넌트 사용
                  const RoutineSectionHeader(
                      title: 'Main 루틴', color: Colors.blue),
                  ...mainRoutines.map((r) => RoutineCard(
                    name: r['name'],
                    type: r['type'],
                    onTap: () => openRoutine(r['id']),
                    onEdit: () => _editRoutine(
                        r['id'], r['name'], r['type']),
                    onDelete: () =>
                        _deleteRoutine(r['id'], r['name']),
                  )),
                ],
                if (sideRoutines.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  // 🌟 분리한 헤더 컴포넌트 사용
                  const RoutineSectionHeader(
                      title: 'Side 루틴', color: Colors.orange),
                  ...sideRoutines.map((r) => RoutineCard(
                    name: r['name'],
                    type: r['type'],
                    onTap: () => openRoutine(r['id']),
                    onEdit: () => _editRoutine(
                        r['id'], r['name'], r['type']),
                    onDelete: () =>
                        _deleteRoutine(r['id'], r['name']),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: gotoCreate,
        backgroundColor: const Color(0xFF2D3436),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}