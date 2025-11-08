// lib/screens/routine_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_client.dart';
import 'exercise_selector_page.dart';
import 'routine_page_logic.dart';

class RoutinePage extends StatefulWidget {
  final String routineId;
  const RoutinePage({required this.routineId, super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  late final RoutinePageLogic logic;
  bool _editMode = false; // 편집 모드

  @override
  void initState() {
    super.initState();
    logic = RoutinePageLogic()..init(widget.routineId, context, setState);
  }

  @override
  void dispose() {
    logic.dispose();
    super.dispose();
  }

  // 순서 저장
  Future<void> _saveOrder() async {
    final updates = logic.exercises.asMap().entries.map((e) {
      return {
        'id': e.value['routine_exercise_id'], // PK
        'routine_id': widget.routineId,       // RLS 필수
        'sort_order': e.key * 10,
      };
    }).toList();

    try {
      await supabase.from('routine_exercises').upsert(updates);
      setState(() => _editMode = false);
      logic.hasUnsavedChanges = true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('순서 저장 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 드래그 핸들 + 기록 UI
  Widget _buildExerciseCard(int i) {
    final ex = logic.exercises[i];
    final exId = ex['id'] as String;
    final name = ex['name'] as String;
    final latest = logic.latestSession[exId] ?? [];
    final sets = logic.todaySets[exId]!;

    return Card(
      key: ValueKey(exId),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 드래그 핸들 (편집 모드에서만)
                if (_editMode)
                  ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                if (_editMode) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _editMode ? null : () => logic.removeExerciseFromRoutine(exId),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 기록 입력 (편집 모드면 비활성화)
            Opacity(
              opacity: _editMode ? 0.5 : 1.0,
              child: AbsorbPointer(
                absorbing: _editMode,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 최근 기록
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("최근 기록", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 8),
                          if (latest.isEmpty)
                            const Text("기록 없음", style: TextStyle(color: Colors.grey))
                          else
                            _buildLatest(latest),
                        ],
                      ),
                    ),
                    // 오늘 입력
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text("오늘 입력", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              if (logic.hasUnsavedChanges)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.circle, size: 8, color: Colors.orange),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...sets.asMap().entries.map((e) {
                            final idx = e.key;
                            final s = e.value;
                            final wCtl = s['weight'] as TextEditingController;
                            final rCtl = s['reps'] as TextEditingController;
                            final group = s['set_group'] as int;
                            final isFirstInGroup = idx == 0 || sets[idx - 1]['set_group'] != group;
                            final isDrop = !isFirstInGroup;
                            final hasValue = wCtl.text.isNotEmpty || rCtl.text.isNotEmpty;

                            return Padding(
                              padding: EdgeInsets.only(left: isDrop ? 32.0 : 0.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isDrop ? "    드롭" : "$group세트",
                                        style: TextStyle(
                                          color: isDrop ? Colors.orange[700] : Colors.black,
                                          fontStyle: isDrop ? FontStyle.italic : FontStyle.normal,
                                          fontWeight: isDrop ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: wCtl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                          decoration: InputDecoration(
                                            hintText: "무게",
                                            filled: hasValue && !logic.hasUnsavedChanges,
                                            fillColor: hasValue && !logic.hasUnsavedChanges ? Colors.green[50] : null,
                                            border: const OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const Text(" × "),
                                      Expanded(
                                        child: TextField(
                                          controller: rCtl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          decoration: InputDecoration(
                                            hintText: "횟수",
                                            filled: hasValue && !logic.hasUnsavedChanges,
                                            fillColor: hasValue && !logic.hasUnsavedChanges ? Colors.green[50] : null,
                                            border: const OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      if (!isDrop)
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: () => logic.removeTodaySet(exId, idx),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                  if (idx == sets.length - 1 || (idx + 1 < sets.length && sets[idx + 1]['set_group'] != group))
                                    Padding(
                                      padding: EdgeInsets.only(left: isDrop ? 48 : 32),
                                      child: TextButton.icon(
                                        onPressed: () => logic.addDropSet(exId, idx),
                                        icon: const Icon(Icons.arrow_downward, size: 14),
                                        label: const Text("드롭세트 추가", style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: () => logic.addSet(exId),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("세트 추가"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => logic.onWillPop(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(logic.routine['name'] ?? '루틴'),
          actions: [
            if (logic.hasUnsavedChanges)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('저장 안 됨', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              ),
            TextButton(
              onPressed: _editMode
                  ? _saveOrder
                  : () => setState(() => _editMode = true),
              child: Text(
                _editMode ? '완료' : '편집',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: logic.loading
            ? const Center(child: CircularProgressIndicator())
            : logic.exercises.isEmpty
            ? const Center(child: Text('운동이 없습니다.'))
            : _editMode
            ? ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: logic.exercises.length,
          onReorder: (oldIdx, newIdx) {
            setState(() {
              final moved = logic.exercises.removeAt(oldIdx);
              logic.exercises.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, moved);
            });
          },
          itemBuilder: (_, i) => _buildExerciseCard(i),
        )
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: logic.exercises.length,
          itemBuilder: (_, i) => _buildExerciseCard(i),
        ),
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "add_exercise",
              onPressed: logic.loading || _editMode ? null : logic.addExerciseToRoutine,
              child: const Icon(Icons.fitness_center),
              backgroundColor: Colors.blue,
            ),
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              heroTag: "save",
              onPressed: logic.loading || _editMode ? null : logic.saveToday,
              label: Row(
                children: [
                  if (logic.hasUnsavedChanges) const Icon(Icons.warning, color: Colors.orange, size: 18),
                  const SizedBox(width: 4),
                  const Text("기록 저장"),
                ],
              ),
              icon: const Icon(Icons.save),
              backgroundColor: logic.hasUnsavedChanges ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatest(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) return const Text("기록 없음", style: TextStyle(color: Colors.grey));

    int currentGroup = -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: logs.map((log) {
        final group = log['set_group'] as int? ?? 1;
        final isFirst = group != currentGroup;
        if (isFirst) currentGroup = group;
        final indent = isFirst ? '  $group세트: ' : '    드롭: ';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            "$indent${log['weight']}kg × ${log['reps']}회",
            style: TextStyle(
              color: !isFirst ? Colors.orange[700] : null,
              fontStyle: !isFirst ? FontStyle.italic : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}