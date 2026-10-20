import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../data/repo.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/reports_screen.dart';

/// شاشة المحاضرة الجارية: رمز QR متجدد + متابعة الحضور لحظياً.
class LiveSessionScreen extends StatefulWidget {
  final LectureSession session;
  final Course course;
  const LiveSessionScreen(
      {super.key, required this.session, required this.course});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  List<Student> _eligible = [];
  bool _focus = false; // وضع العرض المكبّر
  late final Stream<List<AttendanceRecord>> _attStream =
      repo.watchAttendance(widget.session.id);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final all = await repo.students();
      _eligible = all.where(widget.session.appliesTo).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _end() async {
    final ok = await confirmDialog(context, 'إنهاء المحاضرة',
        'بعد الإنهاء لن يتمكن الطلاب من تسجيل الحضور بالـ QR. يبقى بإمكانك التعديل اليدوي من التقرير.',
        ok: 'إنهاء');
    if (!ok || !mounted) return;
    final r = await runBusy(context, () async {
      await repo.closeSession(widget.session.id);
      return true;
    }, success: 'تم إنهاء المحاضرة');
    if (r == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(
              session: widget.session.copyWith(active: false),
              course: widget.course),
        ),
      );
    }
  }

  Future<void> _manualAdd(Set<String> presentIds) async {
    final candidates =
        _eligible.where((s) => !presentIds.contains(s.id)).toList();
    final picked = await showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _StudentSearchSheet(students: candidates),
    );
    if (picked == null || !mounted) return;
    await runBusy(
      context,
      () => repo.markAttendance(AttendanceRecord(
        sessionId: widget.session.id,
        courseId: widget.session.courseId,
        studentId: picked.id,
        studentName: picked.name,
        time: DateTime.now().millisecondsSinceEpoch,
        method: 'manual',
      )),
      success: 'تم تسجيل ${picked.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final payload = QrToken.payload(s, _now);
    final left = QrToken.secondsLeft(_now);
    final elapsed = _now.difference(s.startTime);
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _attStream,
      builder: (context, snap) {
        final recs = snap.data ?? const <AttendanceRecord>[];
        final presentIds = recs.map((r) => r.studentId).toSet();
        final total = _eligible.length;
        return Scaffold(
          backgroundColor: AppColors.night,
          appBar: _focus
              ? null
              : gradientAppBar('محاضرة جارية', actions: [
                  IconButton(
                    tooltip: 'إضافة يدوية',
                    onPressed: () => _manualAdd(presentIds),
                    icon: const Icon(Icons.person_add_alt),
                  ),
                ]),
          body: SafeArea(
            child: GestureDetector(
              onDoubleTap: () => setState(() => _focus = !_focus),
              child: Container(
                decoration:
                    const BoxDecoration(gradient: AppColors.mainGradient),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Text(widget.course.nameAr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    Text(
                        '${widget.course.code} • ${stageName(s.stage)} • ${shiftName(s.shift)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18),
                    Center(child: _qrCard(payload, left)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _stat('الحاضرون', '${presentIds.length}',
                            Icons.how_to_reg, AppColors.emerald),
                        const SizedBox(width: 10),
                        _stat('المتوقع', '$total', Icons.groups,
                            AppColors.cyan),
                        const SizedBox(width: 10),
                        _stat(
                            'المدة',
                            '${elapsed.inMinutes}:${two(elapsed.inSeconds % 60)}',
                            Icons.timer_outlined,
                            AppColors.gold),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : presentIds.length / total,
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.emerald),
                      ),
                    ),
                    if (!_focus) ...[
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rose),
                        onPressed: _end,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('إنهاء المحاضرة'),
                      ),
                      const SizedBox(height: 18),
                      Text('آخر المسجّلين (${recs.length})',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      if (recs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                              'بانتظار مسح الطلاب للرمز...\nاضغط مرتين على الشاشة لوضع العرض المكبّر',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7))),
                        )
                      else
                        ...recs.take(30).map((r) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                    r.method == 'qr'
                                        ? Icons.qr_code_scanner
                                        : Icons.edit_note,
                                    color: AppColors.gold),
                                title: Text(r.studentName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${r.studentId} • ${fmtTime(r.dateTime)}',
                                    style:
                                        const TextStyle(color: Colors.white60)),
                              ),
                            )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _qrCard(String payload, int left) {
    final size = MediaQuery.of(context).size.width - (_focus ? 60 : 110);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: AppColors.cyan.withOpacity(0.45),
              blurRadius: 40,
              spreadRadius: 2)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: size.clamp(180.0, 420.0).toDouble(),
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square, color: AppColors.night),
            dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: AppColors.royal),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: left / AppConfig.qrWindowSeconds,
                  strokeWidth: 3,
                  color: AppColors.violet,
                  backgroundColor: AppColors.violet.withOpacity(0.15),
                ),
              ),
              const SizedBox(width: 8),
              Text('يتجدد الرمز خلال $left ث',
                  style: const TextStyle(
                      color: AppColors.night, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StudentSearchSheet extends StatefulWidget {
  final List<Student> students;
  const _StudentSearchSheet({required this.students});

  @override
  State<_StudentSearchSheet> createState() => _StudentSearchSheetState();
}

class _StudentSearchSheetState extends State<_StudentSearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.students
        .where((s) => _q.isEmpty || s.name.contains(_q) || s.id.contains(_q))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 8 + MediaQuery.of(context).viewInsets.bottom * 0),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                    hintText: 'ابحث عن الطالب بالاسم أو الرقم',
                    prefixIcon: Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.person_off, text: 'لا يوجد طلاب غائبون مطابقون')
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(list[i].name),
                        subtitle: Text(
                            '${list[i].id} • ${shiftName(list[i].shift)}'),
                        onTap: () => Navigator.pop(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
