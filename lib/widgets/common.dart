import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../services/nfc_service.dart';
import '../theme.dart';

/// شعار التطبيق.
class AppLogo extends StatelessWidget {
  final double size;
  final bool light; // النسخة الذهبية على خلفية بيضاء
  const AppLogo({super.key, this.size = 72, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.45),
              blurRadius: size * 0.35,
              spreadRadius: size * 0.02),
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: size * 0.2,
              offset: Offset(0, size * 0.06)),
        ],
      ),
      child: Image.asset(
          light ? 'assets/images/logo_light.png' : 'assets/images/logo.png',
          fit: BoxFit.contain),
    );
  }
}

/// بطاقة ترحيب (Hero) بنمط نظام الكنترول.
class GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget? bottom;
  final IconData roleIcon;
  final List<String> chips;

  const GradientHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.bottom,
    this.roleIcon = Icons.person,
    this.chips = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF1A1F2E), Color(0xFF0E1527), Color(0xFF0B1120)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.amberGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Icon(roleIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.13),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                          '${AppConfig.universityName} • ${AppConfig.appName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 5),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            height: 1.3)),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 12.5)),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in chips) MonoChip(c)],
            ),
          ],
          if (bottom != null) ...[const SizedBox(height: 14), bottom!],
        ],
      ),
    );
  }
}

/// شارة صغيرة بخط أحادي المسافة (كوسوم نظام الكنترول).
class MonoChip extends StatelessWidget {
  final String text;
  final Color color;
  const MonoChip(this.text, {super.key, this.color = AppColors.muted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// شريط تطبيق نحيف للصفحات الداخلية.
PreferredSizeWidget gradientAppBar(String title,
    {List<Widget>? actions, PreferredSizeWidget? bottom}) {
  return AppBar(
    title: Text(title,
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
    centerTitle: false,
    toolbarHeight: 50,
    actions: actions,
    bottom: bottom,
    backgroundColor: const Color(0xE60B1120),
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
    ),
  );
}

/// بطاقة إحصائية مدمجة: رقم كبير + وصف قصير.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final c = gradient.colors.first;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.15,
                          fontWeight: FontWeight.w900)),
                ),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.withOpacity(0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
        ],
      ),
    );
  }
}

/// نص بتدرج ذهبي (كعنوان البوابة).
class GoldText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  const GoldText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => AppColors.titleGradient.createShader(r),
      child: Text(text,
          textAlign: textAlign,
          style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

/// خلفية نظام الكنترول: خطوط شبكة ذهبية خافتة فوق تدرج داكن.
class ConstellationBackground extends StatelessWidget {
  final Widget child;
  const ConstellationBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.6, -1.0),
          radius: 1.6,
          colors: [Color(0xFF0C1426), Color(0xFF070B16), Color(0xFF05080F)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        child: child,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 34.0;
    final p = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.045)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// زر إجراء أفقي مدمج: أيقونة + عنوان + وصف.
class ActionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  const ActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.lineSoft),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFFF59E0B).withOpacity(0.06),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.royal.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, size: 44, color: AppColors.royal),
          ),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 15)),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, this.color = AppColors.royal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// حالة الطالب في مادة حسب نسبة الغياب.
({String label, Color color}) absenceStatus(double percent) {
  final s = AppState.settings;
  if (percent >= s.failPercent) {
    return (label: 'محروم', color: AppColors.rose);
  }
  if (percent >= s.warnPercent) {
    return (label: 'إنذار', color: AppColors.orange);
  }
  return (label: 'منتظم', color: AppColors.emerald);
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.rose : AppColors.night,
    ));
}

Future<bool> confirmDialog(BuildContext context, String title, String body,
    {String ok = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: danger ? AppColors.rose : AppColors.royal),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// ينفذ عملية مع مؤشر انتظار ويعرض الخطأ إن وجد.
Future<T?> runBusy<T>(BuildContext context, Future<T> Function() task,
    {String? success}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
    ),
  );
  try {
    final r = await task();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      if (success != null) showSnack(context, success);
    }
    return r;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showSnack(context, friendlyError(e), error: true);
    }
    return null;
  }
}

String friendlyError(Object e) {
  if (e is AppException) return e.message;
  final s = e.toString();
  if (s.contains('ApiException: 10') || s.contains('sign_in_failed')) {
    return 'إعداد تسجيل الدخول بـ Google غير مكتمل (تحقق من بصمة SHA-1 في Firebase)';
  }
  if (s.contains('permission-denied')) {
    return 'لا تملك صلاحية لهذه العملية';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
  }
  return s.replaceFirst('Exception: ', '');
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year}/${two(d.month)}/${two(d.day)}';
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${two(d.minute)} ${d.hour < 12 ? 'ص' : 'م'}';
}

String fmtDateTime(DateTime d) => '${fmtDate(d)} • ${fmtTime(d)}';

const weekDays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد'
];
String dayName(DateTime d) => weekDays[d.weekday - 1];

/// تسجيل الخروج والرجوع لشاشة الدخول.
Future<void> logout(BuildContext context) async {
  final ok = await confirmDialog(
      context, 'تسجيل الخروج', 'هل تريد تسجيل الخروج من حسابك؟',
      ok: 'خروج');
  if (!ok) return;
  await AppState.repo.signOut();
  await NfcService.setStudentPayload(null);
  AppState.mustChangePassword.value = false;
  AppState.user.value = null;
}

class CircleProgress extends StatelessWidget {
  final double percent; // 0..100
  final Color color;
  final double size;
  const CircleProgress(
      {super.key, required this.percent, required this.color, this.size = 54});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0).toDouble(),
              strokeWidth: 5,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('${percent.round()}%',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.24,
                  color: color)),
        ],
      ),
    );
  }
}
