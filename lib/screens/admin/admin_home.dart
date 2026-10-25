import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/shell.dart';
import '../common/reports_screen.dart';
import '../doctor/doctor_home.dart';
import '../doctor/results_upload_screen.dart';
import 'courses_screen.dart';
import 'dashboard_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';
import 'staff_screen.dart';
import 'structure_screen.dart';
import 'students_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  bool _loading = true;
  bool _seeded = true;
  int _students = 0, _doctors = 0, _courses = 0, _depts = 0, _today = 0;
  List<LectureSession> _recent = [];
  int _sel = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _seeded = await repo.isSeeded();
      final r = await Future.wait([
        repo.students(),
        repo.staff(),
        repo.courses(),
        repo.departments(),
        repo.recentSessions(limit: 30),
      ]);
      final scope = AppState.scope;
      _students = (r[0] as List<Student>)
          .where((x) => scope.isAll || scope.hasDept(x.deptId))
          .length;
      _doctors = (r[1] as List<Staff>)
          .where((x) =>
              (x.role == 'doctor' || x.role == 'head') && scope.hasDept(x.deptId))
          .length;
      _courses =
          (r[2] as List<Course>).where((c) => scope.hasDept(c.deptId)).length;
      _depts = scope.filterDepts(r[3] as List<Department>).length;
      _recent = (r[4] as List<LectureSession>)
          .where((x) => scope.hasDept(x.deptId))
          .toList();
      final now = DateTime.now();
      _today = _recent
          .where((s) =>
              s.startTime.year == now.year &&
              s.startTime.month == now.month &&
              s.startTime.day == now.day)
          .length;
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _seed() async {
    final ok = await confirmDialog(
        context,
        'تهيئة قاعدة البيانات',
        'سيتم رفع بيانات الكليات والأقسام (3) والمواد (136) والطلاب (538) من الملفات المرفقة بالتطبيق. لن تُحذف أي بيانات موجودة.',
        ok: 'ابدأ التهيئة');
    if (!ok || !mounted) return;
    final progress = ValueNotifier<String>('...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, __) => Text(v),
              ),
            ),
          ],
        ),
      ),
    );
    try {
      await repo.seedFromAssets((m) => progress.value = m);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showSnack(context, 'تمت تهيئة قاعدة البيانات بنجاح');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showSnack(context, friendlyError(e), error: true);
      }
    }
    _load();
  }

  /// صفحات القائمة الجانبية.
  List<({KNavItem item, Widget Function() page})> _pages(bool top, bool teaches) => [
        (
          item: const KNavItem(Icons.space_dashboard_rounded, 'لوحة القيادة',
              group: 'الرئيسية'),
          page: () => _overview(top, teaches)
        ),
        (
          item: const KNavItem(Icons.insights_rounded, 'المؤشرات الحية'),
          page: () => const DashboardScreen()
        ),
        (
          item: const KNavItem(Icons.upload_file_rounded, 'رفع Excel',
              group: 'البيانات'),
          page: () => const ImportScreen()
        ),
        (
          item: const KNavItem(Icons.grading_rounded, 'نتائج الطلبة'),
          page: () => ResultsUploadScreen(myCourses: <Course>[])
        ),
        if (top)
          (
            item: const KNavItem(Icons.account_balance_rounded,
                'الكليات والأقسام',
                group: 'الهيكل'),
            page: () => const StructureScreen()
          ),
        (
          item: KNavItem(Icons.auto_stories_rounded, 'المواد الدراسية',
              group: top ? null : 'الهيكل'),
          page: () => const CoursesScreen()
        ),
        (
          item: const KNavItem(Icons.school_rounded, 'الطلاب'),
          page: () => const StudentsScreen()
        ),
        (
          item: const KNavItem(Icons.badge_rounded, 'الكادر'),
          page: () => const StaffScreen()
        ),
        (
          item: const KNavItem(Icons.bar_chart_rounded, 'تقارير الحضور',
              group: 'المتابعة'),
          page: () => const ReportsScreen()
        ),
        if (teaches)
          (
            item: const KNavItem(Icons.qr_code_scanner_rounded, 'محاضراتي'),
            page: () => const DoctorHome(embedded: true)
          ),
        if (top)
          (
            item: const KNavItem(Icons.tune_rounded, 'الإعدادات',
                group: 'النظام'),
            page: () => SettingsScreen(onSeed: _seed)
          ),
      ];

  void _go(String label) {
    final user = AppState.user.value!;
    final pages = _pages(_isTop(user), _teaches(user));
    final i = pages.indexWhere((p) => p.item.label == label);
    if (i >= 0) setState(() => _sel = i);
  }

  bool _isTop(AppUser u) => u.role == Role.admin || u.role == Role.president;
  bool _teaches(AppUser u) =>
      (u.role == Role.head || u.role == Role.dean) &&
      u.staff!.courseIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final user = AppState.user.value!;
    final pages = _pages(_isTop(user), _teaches(user));
    final sel = _sel.clamp(0, pages.length - 1);
    return KShell(
      roleTitle: user.name,
      roleSubtitle: roleName(user.staff!.role),
      items: [for (final p in pages) p.item],
      selected: sel,
      onSelect: (i) {
        setState(() => _sel = i);
        if (i == 0) _load();
      },
      child: KSection(key: ValueKey(sel), builder: (_) => pages[sel].page()),
    );
  }

  Widget _overview(bool top, bool teaches) {
    final user = AppState.user.value!;
    final p = AppColors.tilePalette;
    final role = user.role;
    Widget tile(String t, String s, IconData i, Gradient g, String go) =>
        ActionTile(title: t, subtitle: s, icon: i, gradient: g, onTap: () => _go(go));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            GradientHeader(
              title: 'مرحباً، ${user.name}',
              subtitle:
                  '${roleName(user.staff!.role)} • ${termName(AppState.settings.currentTerm)}',
              roleIcon: switch (role) {
                Role.president => Icons.account_balance_rounded,
                Role.dean => Icons.domain_rounded,
                Role.head => Icons.apartment_rounded,
                _ => Icons.admin_panel_settings,
              },
              chips: [
                'STUDENTS · ${_loading ? '…' : _students}',
                'COURSES · ${_loading ? '…' : _courses}',
                'TODAY · ${_loading ? '…' : _today}',
                repo.isDemo ? 'LOCAL' : 'FIREBASE · ONLINE',
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KSectionHeader(
                      tag: '01. OVERVIEW',
                      title: 'نظرة عامة',
                      subtitle: 'أرقام سريعة ضمن صلاحياتك'),
                  if (!_loading && !_seeded && top) _seedCard(),
                  GridView(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 230,
                        mainAxisExtent: 70,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatCard(
                          label: 'الطلاب',
                          value: _loading ? '…' : '$_students',
                          icon: Icons.groups_rounded,
                          gradient: p[0]),
                      StatCard(
                          label: 'التدريسيون',
                          value: _loading ? '…' : '$_doctors',
                          icon: Icons.co_present_rounded,
                          gradient: p[1]),
                      StatCard(
                          label: 'المواد',
                          value: _loading ? '…' : '$_courses',
                          icon: Icons.menu_book_rounded,
                          gradient: p[2]),
                      StatCard(
                          label: 'الأقسام',
                          value: _loading ? '…' : '$_depts',
                          icon: Icons.apartment_rounded,
                          gradient: p[6]),
                      StatCard(
                          label: 'محاضرات اليوم',
                          value: _loading ? '…' : '$_today',
                          icon: Icons.qr_code_2_rounded,
                          gradient: p[3]),
                    ],
                  ),
                  const KSectionHeader(
                      tag: '02. QUICK ACCESS',
                      title: 'الوصول السريع',
                      subtitle: 'كل الأدوات متاحة أيضاً من القائمة الجانبية'),
                  GridView(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        mainAxisExtent: 58,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      tile('رفع Excel', 'طلاب • مواد • كادر',
                          Icons.upload_file_rounded, p[3], 'رفع Excel'),
                      tile('نتائج الطلبة', 'رفع ومزامنة الدرجات',
                          Icons.grading_rounded, p[4], 'نتائج الطلبة'),
                      tile('الطلاب', 'إضافة • حذف • بطاقات NFC',
                          Icons.school_rounded, p[0], 'الطلاب'),
                      tile('الكادر', 'التدريسيون والإداريون',
                          Icons.badge_rounded, p[1], 'الكادر'),
                      tile('المواد الدراسية', 'حسب القسم والمرحلة',
                          Icons.auto_stories_rounded, p[2], 'المواد الدراسية'),
                      tile('تقارير الحضور', 'الحضور والغياب والإنذارات',
                          Icons.bar_chart_rounded, p[5], 'تقارير الحضور'),
                      if (top)
                        tile('الكليات والأقسام', 'استحداث وتعديل',
                            Icons.account_balance_rounded, p[6],
                            'الكليات والأقسام'),
                      if (teaches)
                        tile('محاضراتي', 'تسجيل الحضور',
                            Icons.qr_code_scanner_rounded, p[5], 'محاضراتي'),
                    ],
                  ),
                  const KSectionHeader(
                      tag: '03. RECENT',
                      title: 'آخر المحاضرات',
                      subtitle: 'أحدث جلسات الحضور المسجلة'),
                  if (_loading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator()))
                  else if (_recent.isEmpty)
                    const EmptyState(
                        icon: Icons.event_busy,
                        text: 'لم تُسجّل أي محاضرة بعد')
                  else
                    ..._recent.take(10).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SessionTile(s),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seedCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'قاعدة البيانات فارغة. ارفع بيانات الطلاب والمواد من الملفات المرفقة.',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.orange),
            onPressed: _seed,
            child: const Text('تهيئة'),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final LectureSession s;
  const _SessionTile(this.s);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lineSoft)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: s.active
                  ? AppColors.grad(AppColors.emerald, const Color(0xFF059669))
                  : AppColors.grad(
                      const Color(0xFF94A3B8), const Color(0xFF64748B)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.active ? Icons.sensors : Icons.check_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    '${s.doctorName} • ${shiftName(s.shift)} • ${fmtDateTime(s.startTime)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (s.active) const Pill('جارية', color: AppColors.emerald),
        ],
      ),
    );
  }
}
