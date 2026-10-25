import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// الدخول: اسم المستخدم/الرقم المعرفي وكلمة المرور، أو حساب Google الجامعي.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  Portal _portal = Portal.management;

  /// هل يطابق الحساب التبويب المختار؟
  String? _mismatch(AppUser u) {
    switch (_portal) {
      case Portal.management:
        return isManagement(u.role)
            ? null
            : 'هذا الحساب ليس من الإدارة؛ ادخل من تبويب "${u.role == Role.student ? 'الطالب' : 'التدريسي'}"';
      case Portal.teacher:
        return (u.role == Role.doctor ||
                u.role == Role.head ||
                u.role == Role.dean)
            ? null
            : (u.role == Role.student
                ? 'هذا حساب طالب؛ ادخل من تبويب "الطالب"'
                : 'هذا الحساب إداري؛ ادخل من تبويب "الإدارة"');
      case Portal.student:
        return u.role == Role.student
            ? null
            : 'هذا الحساب ليس حساب طالب؛ ادخل من تبويب "${isManagement(u.role) ? 'الإدارة' : 'التدريسي'}"';
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _finish(AppUser u, bool mustChange) async {
    // البوابة تُحدَّد تلقائياً من نوع الحساب (كما في نظام الكنترول)
    _portal = u.role == Role.student
        ? Portal.student
        : isManagement(u.role)
            ? Portal.management
            : Portal.teacher;
    final why = _mismatch(u);
    if (why != null) {
      await repo.signOut();
      throw AppException(why);
    }
    await AppState.savePortal(_portal);
    AppState.mustChangePassword.value = mustChange;
    await AppState.afterLogin(u);
  }

  Future<void> _signInPassword() async {
    final user = _user.text.trim();
    if (user.isEmpty) {
      showSnack(context, 'خانة اسم المستخدم فارغة', error: true);
      return;
    }
    if (_pw.text.isEmpty) {
      showSnack(context, 'خانة كلمة المرور فارغة', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await repo.signInWithPassword(user, _pw.text);
      await _finish(r.user, r.mustChangePassword);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInGoogle({bool superAdmin = false}) async {
    setState(() => _busy = true);
    try {
      final u = await repo.signInWithGoogle(
          demoEmail: superAdmin ? 'superadmin' : null);
      await _finish(u, false);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [Color(0xFF141C33), Color(0xFF070B16)],
            stops: [0, 0.7],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.8),
                    radius: 0.9,
                    colors: [
                      const Color(0xFFF59E0B).withOpacity(0.22),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.8, 0.8),
                    radius: 0.8,
                    colors: [
                      const Color(0xFF0EA5E9).withOpacity(0.12),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: CustomPaint(painter: _LoginGrid())),
            SafeArea(
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 860;
                final content = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _hero(240)),
                          const SizedBox(width: 40),
                          SizedBox(width: 420, child: _box()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _hero(150),
                          const SizedBox(height: 20),
                          _box(),
                        ],
                      );
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: content,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(double crest) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: crest,
          height: crest,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFBBF24).withOpacity(0.40),
                  blurRadius: 46,
                  spreadRadius: 2),
            ],
          ),
          child: Image.asset('assets/images/crest.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 18),
        Text(AppConfig.universityName,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: crest > 200 ? 40 : 29,
                height: 1.2,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        GoldText('نظام الحضور الذكي والنتائج',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: crest > 200 ? 25 : 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text('AL-MAAQAL INTERNATIONAL UNIVERSITY · BASRA',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(
                fontFamily: 'monospace',
                color: AppColors.muted,
                fontSize: 11.5,
                letterSpacing: 1.8)),
        if (repo.isDemo) ...[
          const SizedBox(height: 16),
          _localBanner(),
        ],
      ],
    );
  }

  Widget _box() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xF50F172A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x80FBBF24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 60,
              offset: const Offset(0, 28)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withOpacity(0.14),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.line),
              ),
              child: const Text('SECURE SIGN-IN',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.gold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7)),
            ),
          ),
          const SizedBox(height: 10),
          const Text('تسجيل الدخول',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
              'بحساب تطبيق الحضور (مثل doc01 أو admin)، والطالب برقمه الجامعي.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 16),
          _label('اسم المستخدم'),
          TextField(
            controller: _user,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            style: const TextStyle(fontSize: 16),
            decoration: _input(),
          ),
          const SizedBox(height: 14),
          _label('كلمة المرور'),
          TextField(
            controller: _pw,
            obscureText: _obscure,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signInPassword(),
            style: const TextStyle(fontSize: 16),
            decoration: _input(
              suffix: IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                    color: AppColors.muted),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _loginButton(),
          if (!repo.isDemo && !kIsWeb) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF0B1222),
                  side: const BorderSide(color: Color(0x33FFFFFF)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _busy ? null : () => _signInGoogle(),
                child: const Text('الدخول بحساب Google الجامعي',
                    style:
                        TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 2, left: 2),
        child: Text(t,
            style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      );

  InputDecoration _input({Widget? suffix}) => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF243049),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        suffixIcon: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.2)),
      );

  Widget _loginButton() {
    return Opacity(
      opacity: _busy ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.amberGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFD97706).withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _busy ? null : _signInPassword,
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('دخول',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _localBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: AppColors.gold, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'غير متصل بخادم الجامعة بعد: البيانات محفوظة على هذا الجهاز فقط.',
              style: TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  }

class _LoginGrid extends CustomPainter {
  const _LoginGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.05)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
