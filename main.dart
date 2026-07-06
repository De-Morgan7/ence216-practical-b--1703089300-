import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'database_helper.dart';
import 'student.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const ClassAttendanceApp());
}

class ClassAttendanceApp extends StatelessWidget {
  const ClassAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Attendance System',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AttendanceHomePage(),
    );
  }
}

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({super.key});

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  final _dbh = DatabaseHelper.instance;
  final _searchCtrl = TextEditingController();

  List<Student> _students = [];
  Map<int, String> _attendance = {};
  bool _loading = true;
  String _searchTerm = '';

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchCtrl.addListener(() {
      setState(() => _searchTerm = _searchCtrl.text.trim());
      _refresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = _searchTerm.isEmpty
        ? await _dbh.allStudents()
        : await _dbh.searchStudents(_searchTerm);
    final attendance = await _dbh.attendanceForDate(_today);
    if (!mounted) return;
    setState(() {
      _students = data;
      _attendance = attendance;
      _loading = false;
    });
  }

  Future<void> _toggleAttendance(Student student) async {
    final current = _attendance[student.id];
    final next = current == 'present' ? 'absent' : 'present';
    await _dbh.setAttendance(student.id!, _today, next);
    _refresh();
  }

  Future<void> _openForm({Student? existing}) async {
    final indexCtrl = TextEditingController(text: existing?.indexNo ?? '');
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final progCtrl = TextEditingController(text: existing?.programme ?? '');
    final levelCtrl =
        TextEditingController(text: existing?.level.toString() ?? '100');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              existing == null ? 'Register Student' : 'Edit Student',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: indexCtrl,
              decoration: const InputDecoration(labelText: 'Index number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: progCtrl,
              decoration: const InputDecoration(labelText: 'Programme'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: levelCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Level (100–400)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final student = Student(
                  id: existing?.id,
                  indexNo: indexCtrl.text.trim(),
                  fullName: nameCtrl.text.trim(),
                  programme: progCtrl.text.trim(),
                  level: int.tryParse(levelCtrl.text) ?? 100,
                );
                if (existing == null) {
                  await _dbh.insertStudent(student);
                } else {
                  await _dbh.updateStudent(student);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Save Student' : 'Update Student'),
            ),
          ],
        ),
      ),
    );
    _refresh();
  }

  Future<void> _confirmDelete(Student s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${s.fullName}?'),
        content: const Text(
          'This student and their attendance records will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _dbh.deleteStudent(s.id!);
      _refresh();
    }
  }

  Future<void> _showStatistics() async {
    final levelStats = await _dbh.levelStatistics();
    final todayStats = await _dbh.todayAttendanceSummary(_today);
    if (!mounted) return;

    final present = todayStats['present'] ?? 0;
    final absent = todayStats['absent'] ?? 0;
    final unmarked = _students.length - present - absent;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Class Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today — ${DateFormat('EEE, MMM d').format(DateTime.now())}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            _statRow('Present', present, AppColors.present),
            _statRow('Absent', absent, AppColors.absent),
            _statRow('Unmarked', unmarked, AppColors.unmarked),
            const Divider(height: 24),
            const Text(
              'Students by Level',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            if (levelStats.isEmpty)
              const Text('No students registered yet.')
            else
              ...levelStats.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Level ${row['level']}: ${row['count']} student(s)',
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('$label: $count'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentCount =
        _students.where((s) => _attendance[s.id] == 'present').length;
    final absentCount =
        _students.where((s) => _attendance[s.id] == 'absent').length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Class Attendance System',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: 48),
                    child: Icon(
                      Icons.fact_check_rounded,
                      size: 56,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: 'Statistics',
                onPressed: _showStatistics,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search students by name...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _summaryChip(
                        'Present',
                        presentCount,
                        AppColors.present,
                        Icons.check_circle,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Absent',
                        absentCount,
                        AppColors.absent,
                        Icons.cancel,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Total',
                        _students.length,
                        AppColors.primary,
                        Icons.groups,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _students.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 64,
                              color: AppColors.unmarked.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchTerm.isEmpty
                                  ? 'No students registered yet'
                                  : 'No students match your search',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Tap + to add a student'),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final s = _students[i];
                            final status = _attendance[s.id];
                            return _StudentCard(
                              student: s,
                              status: status,
                              onToggle: () => _toggleAttendance(s),
                              onEdit: () => _openForm(existing: s),
                              onDelete: () => _confirmDelete(s),
                            );
                          },
                          childCount: _students.length,
                        ),
                      ),
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Student'),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.status,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Student student;
  final String? status;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPresent = status == 'present';
    final isAbsent = status == 'absent';
    final statusColor =
        isPresent ? AppColors.present : (isAbsent ? AppColors.absent : AppColors.unmarked);
    final statusLabel =
        isPresent ? 'Present' : (isAbsent ? 'Absent' : 'Not marked');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 2),
                  ),
                  child: Icon(
                    isPresent
                        ? Icons.check
                        : (isAbsent ? Icons.close : Icons.remove),
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.indexNo} · ${student.programme}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Level ${student.level}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
