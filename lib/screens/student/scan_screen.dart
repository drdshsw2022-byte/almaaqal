import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_state.dart';
import '../../data/repo.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// مسح رمز QR الخاص بالمحاضرة وتسجيل الحضور.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    _handling = true;
    await _controller.stop();
    String? error;
    LectureSession? session;
    try {
      session = await _register(raw);
    } catch (e) {
      error = friendlyError(e);
    }
    if (!mounted) return;
    await _showResult(error, session);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      _handling = false;
      await _controller.start();
    }
  }

  Future<LectureSession> _register(String raw) async {
    final me = AppState.user.value!.student!;
    final q = QrToken.parse(raw);
    if (q == null) {
      throw AppException('هذا الرمز ليس رمز حضور لجامعة المعقل');
    }
    final s = await repo.session(q.sessionId);
    if (s == null) throw AppException('المحاضرة غير موجودة');
    if (!s.active) throw AppException('انتهت هذه المحاضرة ولم يعد التسجيل متاحاً');
    if (!QrToken.verify(s, q, DateTime.now())) {
      throw AppException(
          'انتهت صلاحية الرمز. امسح الرمز المعروض حالياً على شاشة الدكتور');
    }
    // التحقق من أن الطالب ضمن المحاضرة
    final fresh = await repo.student(me.id) ?? me;
    if (fresh.stage != s.stage) {
      throw AppException(
          'هذه المحاضرة لطلبة ${stageName(s.stage)} وأنت في ${stageName(fresh.stage)}');
    }
    if (fresh.deptId != null && fresh.deptId != s.deptId) {
      throw AppException('هذه المحاضرة ليست من مواد قسمك');
    }
    if (s.shift != 'all' && s.shift != fresh.shift) {
      throw AppException(
          'هذه المحاضرة للدوام ${shiftName(s.shift)} فقط');
    }
    await repo.markAttendance(AttendanceRecord(
      sessionId: s.id,
      courseId: s.courseId,
      studentId: fresh.id,
      studentName: fresh.name,
      time: DateTime.now().millisecondsSinceEpoch,
      method: 'qr',
    ));
    return s;
  }

  Future<void> _showResult(String? error, LectureSession? s) {
    final ok = error == null;
    return showDialog(
      context: context,
      builder: (c) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ok
                        ? AppColors.grad(AppColors.emerald, const Color(0xFF059669))
                        : AppColors.grad(AppColors.rose, const Color(0xFFBE123C)),
                  ),
                  child: Icon(ok ? Icons.check_rounded : Icons.close_rounded,
                      color: Colors.white, size: 56),
                ),
              ),
              const SizedBox(height: 16),
              Text(ok ? 'تم تسجيل حضورك بنجاح' : 'تعذّر تسجيل الحضور',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                ok
                    ? '${s!.courseName}\n${s.doctorName}\n${fmtDateTime(DateTime.now())}'
                    : (error ?? ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(c),
                child: Text(ok ? 'تم' : 'إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.72;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: gradientAppBar('مسح رمز الحضور', actions: [
        IconButton(
          onPressed: () => _controller.toggleTorch(),
          icon: const Icon(Icons.flashlight_on_outlined),
        ),
      ]),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, e, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذّر تشغيل الكاميرا. تأكد من منح التطبيق إذن الكاميرا من إعدادات الهاتف.\n(${e.errorCode.name})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: w,
              height: w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.gold, width: 4),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      spreadRadius: 1000),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'وجّه الكاميرا نحو رمز QR المعروض على شاشة الدكتور',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
