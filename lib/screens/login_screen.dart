import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// الدخول بالبريد الجامعي الرسمي (حساب Google للجامعة) فقط.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
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
    _email.dispose();
    super.dispose();
  }

  Future<void> _signIn({String? demoEmail}) async {
    if (repo.isDemo) {
      demoEmail ??= _email.text.trim();
      if (demoEmail.isEmpty) {
        showSnack(context, 'اكتب بريدك الجامعي', error: true);
        return;
      }
      if (!demoEmail.contains('@')) {
        demoEmail = '$demoEmail@${AppConfig.universityDomain}';
      }
    }
    setState(() => _busy = true);
    try {
      final u = await repo.signInWithGoogle(demoEmail: demoEmail);
      final why = _mismatch(u);
      if (why != null) {
        await repo.signOut();
        throw AppException(why);
      }
      await AppState.savePortal(_portal);
      await AppState.afterLogin(u);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -60,
              child: _glow(220, AppColors.cyan.withOpacity(0.25)),
            ),
            Positioned(
              bottom: -80,
              right: -40,
              child: _glow(260, AppColors.gold.withOpacity(0.18)),
            ),
            ListView(
              padding: EdgeInsets.fromLTRB(22, top + 40, 22, 30),
              children: [
                const Center(child: AppLogo(size: 108)),
                const SizedBox(height: 18),
                const Text(AppConfig.universityName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900)),
                Text('${AppConfig.city} • نظام الحضور والغياب الذكي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 14)),
                const SizedBox(height: 30),
                _card(),
                if (repo.isDemo) ...[
                  const SizedBox(height: 16),
                  _demoBanner(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 14))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabBar(),
          const SizedBox(height: 18),
          Text('دخول ${_tabs.firstWhere((t) => t.$1 == _portal).$2}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'بالبريد الجامعي الرسمي @${AppConfig.universityDomain}',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 20),
          if (repo.isDemo) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _signIn(),
              decoration: const InputDecoration(
                labelText: 'البريد الجامعي',
                hintText: 'name@${AppConfig.universityDomain}',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _googleButton(),
          if (!repo.isDemo) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => _signIn(demoEmail: 'superadmin'),
              child: const Text('دخول المدير العام بحساب آخر',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: _tabs.map((t) {
          final on = t.$1 == _portal;
          return Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _portal = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: on ? AppColors.mainGradient : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(t.$3,
                        size: 22, color: on ? Colors.white : AppColors.muted),
                    const SizedBox(height: 2),
                    Text(t.$2,
                        style: TextStyle(
                            fontSize: 13,
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

  Widget _googleButton() {
    return Opacity(
      opacity: _busy ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.mainGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _busy ? null : () => _signIn(),
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
                        _GoogleMark(),
                        SizedBox(width: 10),
                        Text('الدخول بالبريد الجامعي',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoBanner() {
    Widget quick(String label, String email) => Padding(
          padding: const EdgeInsets.only(left: 8, top: 8),
          child: ActionChip(
            label: Text(label),
            onPressed: _busy ? null : () => _signIn(demoEmail: email),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.science_outlined, color: AppColors.gold, size: 20),
                SizedBox(width: 6),
                Text('الوضع التجريبي (بدون خادم)',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
                'اكتب البريد مباشرة بلا كلمة مرور. الطالب: رقمه المعرفي@almaaqal.edu.iq إلى أن تُضاف الإيميلات الرسمية.'),
            Wrap(
              children: switch (_portal) {
                Portal.management => [
                    quick('رئيس الجامعة', AppConfig.demoPresidentEmail),
                    quick('عميد', AppConfig.demoDeanEmail),
                    quick('رئيس قسم', AppConfig.demoHeadEmail),
                    quick('مدير النظام', AppConfig.demoAdminEmail),
                  ],
                Portal.teacher => [
                    quick('تدريسي', AppConfig.demoDoctorEmail),
                    quick('رئيس قسم يدرّس', AppConfig.demoHeadEmail),
                  ],
                Portal.student => [
                    quick('طالب تجريبي',
                        '1989616052@${AppConfig.universityDomain}'),
                  ],
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double s, Color c) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: const Text('G',
          style: TextStyle(
              color: Color(0xFF4285F4),
              fontWeight: FontWeight.w900,
              fontSize: 15,
              height: 1.1)),
    );
  }
}
