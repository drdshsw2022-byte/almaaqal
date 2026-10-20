import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/profile_sheet.dart';
import '../common/student_report_screen.dart';
import 'scan_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  bool _loading = true;
  List<StudentCourseSummary> _data = [];
  String? _deptName;

  Student get _me => AppState.user.value!.student!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // تحديث بيانات الطالب (قد يكون المدير غيّر القسم)
      final fresh = await repo.student(_me.id);
      if (fresh != null) AppState.user.value = AppUser.student(fresh);
      final depts = await repo.departments();
      _deptName = depts
          .where((d) => d.id == _me.deptId)
          .map((d) => d.name)
          .firstOrNull;
      _data = await loadStudentSummary(_me,
          term: AppState.settings.currentTerm);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _scan() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final total = _data.fold<int>(0, (a, d) => a + d.total);
    final present = _data.fold<int>(0, (a, d) => a + d.present);
    final rate = total == 0 ? 100.0 : present * 100 / total;
    final warnings = _data
        .where((d) =>
            absenceStatus(d.absencePercent).color != AppColors.emerald)
        .length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              title: me.name,
              subtitle:
                  '${me.id} • ${stageName(me.stage)} • ${shiftName(me.shift)}${_deptName != null ? '\n$_deptName' : ''}',
              roleIcon: Icons.school_rounded,
              actions: [
                IconButton(
                  onPressed: () => showProfileSheet(context),
                  icon: const Icon(Icons.account_circle_outlined,
                      color: Colors.white),
                ),
                IconButton(
                  onPressed: () => logout(context),
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
              ],
              bottom: _scanButton(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: StatCard(
                              label: 'نسبة الحضور',
                              value: _loading ? '…' : '${rate.round()}%',
                              icon: Icons.trending_up_rounded,
                              gradient: AppColors.tilePalette[2])),
                      const SizedBox(width: 10),
                      Expanded(
                          child: StatCard(
                              label: 'محاضرات حضرتها',
                              value: _loading ? '…' : '$present/$total',
                              icon: Icons.event_available_rounded,
                              gradient: AppColors.tilePalette[1])),
                    ],
                  ),
                  if (!_loading && warnings > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                'لديك $warnings مادة تجاوزت نسبة الغياب المسموح بها للإنذار. انتبه لحضورك!',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SectionTitle(
                      'موادي • ${termName(AppState.settings.currentTerm)}',
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    StudentReportScreen(student: me))),
                        child: const Text('السجل الكامل'),
                      )),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_data.isEmpty)
                    const EmptyState(
                        icon: Icons.menu_book,
                        text: 'لا توجد مواد أو محاضرات مسجلة لك بعد')
                  else
                    ..._data.map((d) => CourseAttendanceCard(
                          summary: d,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => StudentCourseSessionsScreen(
                                      summary: d, student: me))),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanButton() {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: AppColors.gold.withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _scan,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 40),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تسجيل الحضور',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('امسح رمز QR المعروض في القاعة',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
