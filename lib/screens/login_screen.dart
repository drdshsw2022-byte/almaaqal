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

  static const _tabs = [
    (Portal.management, 'الإدارة', Icons.account_balance_rounded),
    (Portal.teacher, 'التدريسي', Icons.co_present_rounded),
    (Portal.student, 'الطالب', Icons.school_rounded),
  ];

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
      showSnack(
          context,
          _portal == Portal.student
              ? 'خانة الرقم المعرفي فارغة'
              : 'خانة اسم المستخدم فارغة',
          error: true);
      return;
    }
    if (_pw.text.isEmpty) {
      showSnack(context, 'خانة كلمة المرور فارغة', error: true);
      return;
    }
    if (_portal == Portal.student && !RegExp(r'^[0-9]+$').hasMatch(user)) {
      showSnack(context, 'الرقم المعرفي أرقام فقط', error: true);
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
          Text(
              _portal == Portal.student
                  ? 'بالرقم الجامعي وكلمة المرور.'
                  : 'بحساب تطبيق الحضور (مثل doc01 أو admin).',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 14),
          _tabBar(),
          const SizedBox(height: 14),
          TextField(
            controller: _user,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: _portal == Portal.student
                ? TextInputType.number
                : TextInputType.text,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _portal == Portal.student
                  ? 'الرقم المعرفي (الجامعي)'
                  : 'اسم المستخدم',
              prefixIcon: Icon(_portal == Portal.student
                  ? Icons.badge_outlined
                  : Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            obscureText: _obscure,
            onSubmitted: (_) => _signInPassword(),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _loginButton(),
          if (!repo.isDemo && !kIsWeb) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('أو',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _signInGoogle(),
              icon: const _GoogleMark(),
              label: const Text('بحساب Google الجامعي'),
            ),
            if (_portal == Portal.management)
              TextButton(
                onPressed: _busy ? null : () => _signInGoogle(superAdmin: true),
                child: const Text('دخول المدير العام بحساب آخر',
                    style: TextStyle(fontSize: 12)),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            _portal == Portal.student
                ? 'أول دخول: كلمة المرور الأولية هي رقمك المعرفي، وسيُطلب منك تغييرها.'
                : 'أول دخول: استخدم كلمة المرور الأولية التي سلّمتها لك الإدارة، وسيُطلب منك تغييرها.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        children: _tabs.map((t) {
          final on = t.$1 == _portal;
          return Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _portal = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: on ? AppColors.amberGradient : null,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.$3,
                        size: 17, color: on ? Colors.white : AppColors.muted),
                    const SizedBox(width: 5),
                    Text(t.$2,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: on ? Colors.white : AppColors.muted)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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
                        Icon(Icons.login, color: Colors.white),
                        SizedBox(width: 8),
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

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [
          Color(0xFFEA4335),
          Color(0xFFFBBC05),
          Color(0xFF34A853),
          Color(0xFF4285F4),
          Color(0xFFEA4335),
        ]),
      ),
      child: const Text('G',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              height: 1.1)),
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
