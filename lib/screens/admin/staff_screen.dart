import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/course_picker.dart';

/// إدارة الكادر (الدكاترة والمدراء) وتوزيع المواد عليهم.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Staff> _staff = [];
  List<Department> _depts = [];
  Map<String, Course> _courses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait(
          [repo.staff(), repo.departments(), repo.courses()]);
      _staff = List<Staff>.from(r[0] as List<Staff>)
        ..sort((a, b) => a.role != b.role
            ? a.role.compareTo(b.role)
            : a.name.compareTo(b.name));
      _depts = r[1] as List<Department>;
      _courses = {for (final c in r[2] as List<Course>) c.id: c};
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Staff? s]) async {
    final email = TextEditingController(text: s?.email);
    final name = TextEditingController(text: s?.name);
    String role = s?.role ?? 'doctor';
    String? dept = s?.deptId;
    List<String> courseIds = [...?s?.courseIds];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(s == null ? 'إضافة عضو كادر' : 'تعديل بيانات الكادر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'doctor',
                        label: Text('دكتور'),
                        icon: Icon(Icons.co_present)),
                    ButtonSegment(
                        value: 'admin',
                        label: Text('مدير'),
                        icon: Icon(Icons.admin_panel_settings)),
                  ],
                  selected: {role},
                  onSelectionChanged: (v) => setD(() => role = v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'الاسم الكامل مع اللقب العلمي')),
                const SizedBox(height: 10),
                TextField(
                    controller: email,
                    enabled: s == null,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                        labelText: 'البريد الجامعي (للدخول)',
                        hintText: 'name@${AppConfig.universityDomain}')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: dept,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'القسم'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('غير محدد')),
                    ..._depts.map((d) => DropdownMenuItem<String?>(
                        value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (v) => setD(() => dept = v),
                ),
                if (role == 'doctor') ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final r = await Navigator.push<List<String>>(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => CoursePickerScreen(
                            initial: courseIds.toSet(),
                            title: 'مواد الدكتور',
                            initialDept: dept,
                          ),
                        ),
                      );
                      if (r != null) setD(() => courseIds = r);
                    },
                    icon: const Icon(Icons.library_books_outlined),
                    label: Text('المواد المسندة (${courseIds.length})'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final e = email.text.trim().toLowerCase();
    if (e.isEmpty || name.text.trim().isEmpty) {
      showSnack(context, 'أدخل الاسم والبريد الجامعي', error: true);
      return;
    }
    if (!AppConfig.isAllowedEmail(e)) {
      showSnack(context,
          'يجب أن يكون البريد جامعياً (@${AppConfig.universityDomain})',
          error: true);
      return;
    }
    if (s == null && _staff.any((x) => x.id == e)) {
      showSnack(context, 'هذا البريد مضاف مسبقاً', error: true);
      return;
    }
    final staff = Staff(
      id: e,
      name: name.text.trim(),
      role: role,
      deptId: dept,
      courseIds: role == 'doctor' ? courseIds : const [],
    );
    await runBusy(context, () => repo.saveStaff(staff), success: 'تم الحفظ');
    _load();
  }

  Future<void> _delete(Staff s) async {
    if (s.id == AppState.user.value?.staff?.id) {
      showSnack(context, 'لا يمكنك حذف حسابك', error: true);
      return;
    }
    final ok = await confirmDialog(context, 'حذف', 'حذف "${s.name}"؟',
        ok: 'حذف', danger: true);
    if (!ok || !mounted) return;
    await runBusy(context, () => repo.deleteStaff(s.id), success: 'تم الحذف');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('الكادر التدريسي والإداري'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _staff.isEmpty
              ? const EmptyState(icon: Icons.badge, text: 'لا يوجد كادر بعد')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _staff.length,
                  itemBuilder: (_, i) => _tile(_staff[i]),
                ),
    );
  }

  Widget _tile(Staff s) {
    final g = s.isAdmin ? AppColors.tilePalette[4] : AppColors.tilePalette[1];
    final names = s.courseIds
        .map((id) => _courses[id]?.nameAr)
        .whereType<String>()
        .take(3)
        .join('، ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        onTap: () => _edit(s),
        leading: Container(
          width: 48,
          height: 48,
          decoration:
              BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(16)),
          child: Icon(s.isAdmin ? Icons.admin_panel_settings : Icons.co_present,
              color: Colors.white),
        ),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.isAdmin ? 'مدير' : 'دكتور'} • ${s.email}',
                style: const TextStyle(fontSize: 12)),
            if (!s.isAdmin)
              Text(
                  s.courseIds.isEmpty
                      ? 'لا توجد مواد مسندة'
                      : '${s.courseIds.length} مادة: $names${s.courseIds.length > 3 ? '…' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.royal)),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _delete(s),
          icon: const Icon(Icons.delete_outline, color: AppColors.rose),
        ),
      ),
    );
  }
}
