import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models.dart';
import '../../services/excel_import.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/course_picker.dart';
import 'grades_screen.dart';

/// رفع ملف نتائج الطلبة ومزامنته مع لوحات الطلبة.
///
/// يقبل ملف مادة واحدة (student_grades_full) أو ملفاً شاملاً بورقة لكل مادة
/// (مثل CS-L3 Grades): تُطابَق كل ورقة مع مادتها تلقائياً ويمكن تعديل المطابقة.
class ResultsUploadScreen extends StatefulWidget {
  final List<Course> myCourses;
  final Course? initialCourse;
  const ResultsUploadScreen(
      {super.key, required this.myCourses, this.initialCourse});

  @override
  State<ResultsUploadScreen> createState() => _ResultsUploadScreenState();
}

class _Matched {
  final Student student;
  final Map<String, double> marks;
  _Matched(this.student, this.marks);
}

/// خطة رفع ورقة واحدة إلى مادة.
class _Plan {
  final GradeSheet sheet;
  Course? course;
  bool include;
  List<_Matched> matched = [];
  List<String> problems = [];
  List<String> notes = [];
  Map<String, double> max = {};
  _Plan(this.sheet, this.course, this.include);
}

class _ResultsUploadScreenState extends State<ResultsUploadScreen> {
  Course? _course; // لملف المادة الواحدة
  GradeFile? _file;
  String? _fileError;
  bool _publish = true;
  List<_Plan> _plans = [];
  List<Course> _allCourses = [];
  Map<String, String> _deptNames = {};
  Map<String, Student> _students = {};

  bool get _isManager {
    final r = AppState.user.value?.role;
    return r != null && isManagement(r);
  }

  bool get _multi => (_file?.sheets.length ?? 0) > 1;

  @override
  void initState() {
    super.initState();
    _course = widget.initialCourse ??
        (widget.myCourses.length == 1 ? widget.myCourses.first : null);
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      _allCourses = await repo.courses();
      _deptNames = {for (final d in await repo.departments()) d.id: d.name};
    } catch (_) {}
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  bool _mayGrade(Course c) =>
      _isManager
          ? AppState.scope.hasDept(c.deptId)
          : widget.myCourses.any((x) => x.id == c.id);

  Future<Course?> _chooseCourse() async {
    final r = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CoursePickerScreen(multi: false, title: 'اختر المادة'),
      ),
    );
    if (r == null || r.isEmpty || !mounted) return null;
    if (_allCourses.isEmpty) await _loadRefs();
    final c = _allCourses.where((x) => x.id == r.first).firstOrNull;
    if (c == null) return null;
    // الدكتور: إضافة المادة لمواده ليملك صلاحية رصد درجاتها
    final me = AppState.user.value?.staff;
    if (!_isManager && me != null && !me.courseIds.contains(c.id)) {
      final updated = me.copyWith(courseIds: [...me.courseIds, c.id]);
      try {
        await repo.saveStaff(updated);
        AppState.user.value = AppUser.staff(updated);
        try {
          widget.myCourses.add(c);
        } catch (_) {}
      } catch (_) {}
    }
    return c;
  }

  Future<void> _pickFile() async {
    try {
      final f = await GradesExcel.pick();
      if (f == null) return;
      _file = f;
      _fileError = f.sheets.isEmpty
          ? 'لم أجد في الملف ورقة فيها عمود «الرقم المعرفي» مع درجات مرصودة.'
          : null;
    } catch (e) {
      _file = null;
      _fileError = e is AppException ? e.message : 'تعذّرت قراءة الملف: $e';
    }
    await _buildPlans();
  }

  Future<void> _buildPlans() async {
    final f = _file;
    _plans = [];
    if (f == null || f.sheets.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    if (_allCourses.isEmpty) await _loadRefs();
    _students = {for (final s in await repo.students()) s.id: s};
    if (f.sheets.length == 1) {
      final p = _Plan(f.sheets.first, _course, true);
      _plans = [p];
    } else {
      // المواد المسموح بها أولاً، ثم البقية
      final pool = _isManager
          ? _allCourses.where((c) => AppState.scope.hasDept(c.deptId)).toList()
          : _allCourses;
      for (final sh in f.sheets) {
        var c = GradesExcel.bestCourse(
            sh, widget.myCourses.isNotEmpty && !_isManager ? widget.myCourses : pool, _deptNames);
        c ??= GradesExcel.bestCourse(sh, pool, _deptNames);
        _plans.add(_Plan(sh, c, c != null && _mayGrade(c)));
      }
    }
    for (final p in _plans) {
      await _analyze(p);
    }
    if (mounted) setState(() {});
  }

  /// مطابقة صفوف الورقة مع الطلبة والتحقق من المدى.
  Future<void> _analyze(_Plan p) async {
    p.matched = [];
    p.problems = [];
    p.notes = [];
    final c = p.course;
    if (c == null) return;
    final sch = await repo.scheme(c.id);
    p.max = Map<String, double>.from(sch.max)..addAll(p.sheet.headerMax);
    var otherStage = 0;
    for (final r in p.sheet.rows) {
      final s = _students[r.studentId];
      if (s == null) {
        p.problems.add(
            'صف ${r.row}: الرقم ${r.studentId} غير موجود في قاعدة البيانات');
        continue;
      }
      if (s.stage != c.stage || (s.deptId != null && s.deptId != c.deptId)) {
        otherStage++;
        if (otherStage <= 30) {
          p.notes.add(
              '${s.name} (${s.id}) من ${stageName(s.stage)}؛ سيُرفع كطالب محمَّل بهذه المادة');
        }
      }
      final marks = <String, double>{};
      r.marks.forEach((k, v) {
        final mx = p.max[k] ?? 0;
        if (v == null) {
          p.problems.add('صف ${r.row}: قيمة غير رقمية في ${componentName(k)}');
        } else if (mx <= 0 || v < 0 || v > mx) {
          p.problems.add(
              'صف ${r.row}: ${componentName(k)} = ${_fmt(v)} خارج المدى (0–${_fmt(mx)})');
        } else {
          marks[k] = v;
        }
      });
      if (marks.isNotEmpty) p.matched.add(_Matched(s, marks));
    }
    if (otherStage > 30) {
      p.notes.add('و${otherStage - 30} طالباً آخرين من مرحلة/قسم مختلف');
    }
  }

  List<_Plan> get _ready => _plans
      .where((p) => p.include && p.course != null && p.matched.isNotEmpty)
      .toList();

  Future<int> _syncPlan(_Plan p) async {
    final c = p.course!;
    final sch = await repo.scheme(c.id);
    final comps = <String>{for (final m in p.matched) ...m.marks.keys};
    final published = {...sch.published};
    if (_publish) published.addAll(comps);
    await repo.saveScheme(
        GradeScheme(courseId: c.id, max: p.max, published: published));
    final existing = {
      for (final g in await repo.gradesForCourse(c.id)) g.studentId: g
    };
    final out = p.matched.map((m) {
      final old = existing[m.student.id];
      return GradeRecord(
        courseId: c.id,
        studentId: m.student.id,
        studentName: m.student.name,
        studentEmail: m.student.email,
        marks: {...?old?.marks, ...m.marks},
      );
    }).toList();
    await repo.saveGradesBulk(out);
    return out.length;
  }

  Future<void> _sync() async {
    final plans = _ready;
    final dup = <String>{};
    for (final p in plans) {
      if (!dup.add(p.course!.id)) {
        showSnack(context,
            'المادة ${p.course!.nameAr} مختارة لأكثر من ورقة؛ صحّح المطابقة',
            error: true);
        return;
      }
    }
    final summary = await runBusy(context, () async {
      final lines = <String>[];
      var total = 0;
      for (final p in plans) {
        final n = await _syncPlan(p);
        total += n;
        lines.add('${p.course!.nameAr}: $n طالباً');
      }
      return (total, lines);
    });
    if (summary == null || !mounted) return;
    final (total, lines) = summary;
    final single = plans.length == 1 ? plans.first.course : null;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cloud_done_rounded,
            color: AppColors.emerald, size: 48),
        title: const Text('تمت المزامنة'),
        content: Text(
            '${lines.join('\n')}\n\nالمجموع: $total سجلاً.\n${_publish ? 'النتائج ظاهرة الآن في قسم «الدرجات» لدى كل طالب.' : 'لم تُنشر بعد للطلبة؛ انشرها من شاشة الدرجات.'}',
            textAlign: TextAlign.center),
        actions: [
          if (single != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GradesScreen(course: single)));
              },
              child: const Text('عرض الدرجات'),
            ),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('تم')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    final readyCount = ready.fold<int>(0, (a, p) => a + p.matched.length);
    return Scaffold(
      appBar: gradientAppBar('رفع نتائج الطلبة'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_multi) _courseStep(),
          _step(
            _multi ? 1 : 2,
            'ملف النتائج',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'يقبل سجل مادة واحدة (الرقم المعرفي، الحضور، الواجب البيتي، المشروع، المختبر، الامتحان الأسبوعي، الفصلي، النهائي)، أو ملفاً شاملاً فيه ورقة لكل مادة. يمكن اختياره من الهاتف أو من Google Drive.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.muted, height: 1.6),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                      _file == null ? 'اختيار ملف Excel' : 'اختيار ملف آخر'),
                ),
                if (_fileError != null) ...[
                  const SizedBox(height: 8),
                  Text(_fileError!,
                      style: const TextStyle(color: AppColors.rose)),
                ],
                if (_multi) ...[
                  const SizedBox(height: 10),
                  Text(
                      'ملف شامل: ${_file!.sheets.length} مادة. راجع مطابقة كل ورقة بمادتها:',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          ..._plans.asMap().entries.map((e) => _planCard(e.key, e.value)),
          if (_plans.isNotEmpty) ...[
            SwitchListTile(
              value: _publish,
              onChanged: (v) => setState(() => _publish = v),
              title: const Text('نشر النتائج للطلبة فوراً'),
              subtitle: const Text('تظهر في قسم «الدرجات» بلوحة الطالب'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: ready.isEmpty ? null : _sync,
              icon: const Icon(Icons.sync_rounded),
              label: Text(ready.isEmpty
                  ? (_plans.any((p) => p.course == null)
                      ? 'اختر المادة أولاً'
                      : 'لا توجد نتائج صالحة للمزامنة')
                  : ready.length == 1
                      ? 'مزامنة نتائج $readyCount طالباً'
                      : 'مزامنة ${ready.length} مواد ($readyCount سجلاً)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _courseStep() {
    final courses = {
      for (final c in [...widget.myCourses, if (_course != null) _course!])
        c.id: c
    }.values.toList();
    return _step(
      1,
      'المادة',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (courses.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _course?.id,
              isExpanded: true,
              hint: const Text('اختر المادة'),
              items: courses
                  .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                          '${c.nameAr} • ${stageName(c.stage)} • ${termName(c.term)}',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                setState(() => _course = courses.firstWhere((c) => c.id == v));
                _buildPlans();
              },
            ),
          TextButton.icon(
            onPressed: () async {
              final c = await _chooseCourse();
              if (c == null) return;
              setState(() => _course = c);
              _buildPlans();
            },
            icon: const Icon(Icons.search),
            label: Text(courses.isEmpty
                ? 'اختيار المادة من الأقسام'
                : 'مادة أخرى'),
          ),
        ],
      ),
    );
  }

  Widget _planCard(int i, _Plan p) {
    final c = p.course;
    final allowed = c != null && _mayGrade(c);
    return _step(
      _multi ? i + 2 : 3,
      _multi ? 'ورقة «${p.sheet.name}»' : 'المعاينة',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_multi) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    c == null
                        ? 'لم تُعرف المادة'
                        : '← ${c.nameAr} (${c.code}) • ${_deptNames[c.deptId] ?? ''} • ${stageName(c.stage)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c == null ? AppColors.rose : AppColors.royal),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final n = await _chooseCourse();
                    if (n == null) return;
                    p.course = n;
                    p.include = _mayGrade(n);
                    await _analyze(p);
                    if (mounted) setState(() {});
                  },
                  child: const Text('تغيير'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: p.include && allowed,
              onChanged: allowed
                  ? (v) => setState(() => p.include = v)
                  : null,
              title: Text(allowed
                  ? 'رفع هذه الورقة'
                  : (c == null
                      ? 'اختر المادة أولاً'
                      : 'ليست من موادك؛ لا يمكنك رفعها')),
            ),
          ],
          if (c != null) ...[
            Row(
              children: [
                _num('جاهز للمزامنة', p.matched.length, AppColors.emerald),
                _num('ملاحظات', p.problems.length, AppColors.orange),
              ],
            ),
            if (p.sheet.headerMax.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: gradeComponents
                    .where((k) => p.sheet.headerMax.containsKey(k))
                    .map((k) => Pill(
                        '${componentName(k)} ${_fmt(p.sheet.headerMax[k]!)}'))
                    .toList(),
              ),
            ],
            const SizedBox(height: 6),
            ...p.matched.take(_multi ? 3 : 8).map((m) {
              final total = m.marks.values.fold<double>(0, (a, b) => a + b);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.check_circle, color: AppColors.emerald),
                title: Text(m.student.name),
                subtitle: Text('الرقم المعرفي: ${m.student.id}'),
                trailing: Text(_fmt(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              );
            }),
            if (p.matched.length > (_multi ? 3 : 8))
              Text('و${p.matched.length - (_multi ? 3 : 8)} طالباً آخرين…',
                  style: const TextStyle(color: AppColors.muted)),
            if (p.notes.isNotEmpty)
              _list('تنبيهات (${p.notes.length})', p.notes, AppColors.royal),
            if (p.problems.isNotEmpty)
              _list('الصفوف غير المرفوعة (${p.problems.length})', p.problems,
                  AppColors.orange),
          ],
        ],
      ),
    );
  }

  Widget _list(String title, List<String> items, Color color) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(title, style: TextStyle(fontSize: 13.5, color: color)),
        children: items
            .take(100)
            .map((p) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('• $p', style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
      );

  Widget _num(String l, int n, Color c) => Expanded(
        child: Column(
          children: [
            Text('$n',
                style: TextStyle(
                    color: c, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(l, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      );

  Widget _step(int n, String title, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.royal,
                  child: Text('$n',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}
