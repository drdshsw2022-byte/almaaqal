import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'filters.dart';

/// صفحة اختيار مواد (متعدد أو مفرد). تعيد قائمة معرفات المواد المختارة.
class CoursePickerScreen extends StatefulWidget {
  final Set<String> initial;
  final bool multi;
  final String title;
  final String? initialDept;

  /// في الوضع المفرد: إن وُجد يُستدعى بدلاً من إغلاق الصفحة.
  final void Function(BuildContext context, Course course)? onPicked;

  const CoursePickerScreen({
    super.key,
    this.initial = const {},
    this.multi = true,
    this.title = 'اختيار المواد',
    this.initialDept,
    this.onPicked,
  });

  @override
  State<CoursePickerScreen> createState() => _CoursePickerScreenState();
}

class _CoursePickerScreenState extends State<CoursePickerScreen> {
  late Set<String> _sel;
  List<Course> _all = [];
  List<Department> _depts = [];
  String? _dept;
  int? _stage;
  int? _term;
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sel = {...widget.initial};
    _dept = widget.initialDept;
    _term = AppState.settings.currentTerm;
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([repo.courses(), repo.departments()]);
      _all = List<Course>.from(r[0] as List<Course>)
        ..sort((a, b) => a.semester != b.semester
            ? a.semester.compareTo(b.semester)
            : a.nameAr.compareTo(b.nameAr));
      _depts = r[1] as List<Department>;
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _deptName(String id) =>
      _depts.where((d) => d.id == id).map((d) => d.name).firstOrNull ?? id;

  @override
  Widget build(BuildContext context) {
    final list = _all.where((c) {
      if (_dept != null && c.deptId != _dept) return false;
      if (_stage != null && c.stage != _stage) return false;
      if (_term != null && c.term != _term) return false;
      if (_q.isNotEmpty &&
          !c.nameAr.contains(_q) &&
          !c.code.toLowerCase().contains(_q.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: gradientAppBar(widget.title),
      bottomNavigationBar: widget.multi
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _sel.toList()),
                  icon: const Icon(Icons.check),
                  label: Text('حفظ (${_sel.length} مادة)'),
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                FilterBar(
                  searchHint: 'ابحث عن مادة',
                  onSearch: (v) => setState(() => _q = v.trim()),
                  children: [
                    DeptChip(
                        depts: _depts,
                        value: _dept,
                        onChanged: (v) => setState(() => _dept = v)),
                    ChoiceMenuChip<int>(
                      label: 'المرحلة',
                      value: _stage,
                      options: const {
                        1: 'الأولى',
                        2: 'الثانية',
                        3: 'الثالثة',
                        4: 'الرابعة'
                      },
                      onChanged: (v) => setState(() => _stage = v),
                    ),
                    ChoiceMenuChip<int>(
                      label: 'الفصل',
                      value: _term,
                      options: const {1: 'الأول', 2: 'الثاني'},
                      onChanged: (v) => setState(() => _term = v),
                    ),
                  ],
                ),
                Expanded(
                  child: list.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off, text: 'لا توجد مواد مطابقة')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final c = list[i];
                            final on = _sel.contains(c.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: widget.multi
                                  ? CheckboxListTile(
                                      value: on,
                                      activeColor: AppColors.royal,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      onChanged: (v) => setState(() => v == true
                                          ? _sel.add(c.id)
                                          : _sel.remove(c.id)),
                                      title: Text(c.nameAr,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                          '${c.code} • ${stageName(c.stage)} • ${_deptName(c.deptId)}',
                                          style:
                                              const TextStyle(fontSize: 12)),
                                    )
                                  : ListTile(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      onTap: () => widget.onPicked != null
                                          ? widget.onPicked!(context, c)
                                          : Navigator.pop(context, [c.id]),
                                      title: Text(c.nameAr,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                          '${c.code} • ${stageName(c.stage)} • ${_deptName(c.deptId)}',
                                          style:
                                              const TextStyle(fontSize: 12)),
                                      trailing: const Icon(Icons.chevron_right),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
