import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _activate = false; // وضع تفعيل حساب جديد
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _done(AppUser u) async {
    await AppState.refreshSettings();
    AppState.user.value = u;
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    final pw = _pw.text;
    if (id.isEmpty || pw.isEmpty) {
      showSnack(context, 'أدخل الرقم الجامعي وكلمة المرور', error: true);
      return;
    }
    if (_activate) {
      if (pw.length < 6) {
        showSnack(context, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
            error: true);
        return;
      }
      if (pw != _pw2.text) {
        showSnack(context, 'كلمتا المرور غير متطابقتين', error: true);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final u = _activate
          ? await repo.activateAccount(id, pw)
          : await repo.signInWithId(id, pw);
      await _done(u);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    String? demoEmail;
    if (repo.isDemo) {
      demoEmail = await _askText(
          'الدخول بحساب Google (تجريبي)',
          'في الوضع التجريبي اكتب البريد المرتبط بحسابك',
          'example@gmail.com',
          TextInputType.emailAddress);
      if (demoEmail == null) return;
    }
    setState(() => _busy = true);
    try {
      final u = await repo.signInWithGoogle(demoEmail: demoEmail);
      await _done(u);
    } on NotLinkedException catch (e) {
      if (mounted) await _linkFlow(e.email);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ربط حساب Google برقم جامعي مفعّل.
  Future<void> _linkFlow(String email) async {
    final id = TextEditingController();
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ربط حساب Google'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'البريد $email غير مرتبط بعد. أدخل رقمك الجامعي وكلمة المرور مرة واحدة لربطه، وبعدها يمكنك الدخول بـ Google مباشرة.\n\nإذا لم تفعّل حسابك بعد، فعّله أولاً من "تفعيل حساب جديد".',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: id,
                decoration: const InputDecoration(
                    labelText: 'الرقم الجامعي / الوظيفي',
                    prefixIcon: Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pw,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: Icon(Icons.lock_outline)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('ربط ودخول')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final u = await runBusy(
        context, () => repo.linkGoogleWithId(email, id.text.trim(), pw.text),
        success: 'تم ربط حساب Google بنجاح');
    if (u != null) await _done(u);
  }

  Future<String?> _askText(
      String title, String hint, String placeholder, TextInputType type) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hint, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              keyboardType: type,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(hintText: placeholder),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('متابعة')),
        ],
      ),
    );
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
              padding: EdgeInsets.fromLTRB(22, top + 36, 22, 30),
              children: [
                const Center(child: AppLogo(size: 104)),
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
                const SizedBox(height: 28),
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
          Text(_activate ? 'تفعيل حساب جديد' : 'تسجيل الدخول',
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              _activate
                  ? 'أول مرة؟ أدخل رقمك المعرفي واختر كلمة مرور خاصة بك'
                  : 'للطلبة والدكاترة والإدارة',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 18),
          TextField(
            controller: _id,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'الرقم الجامعي (المعرفي) / الوظيفي',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            obscureText: _obscure,
            textInputAction:
                _activate ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) => _activate ? null : _submit(),
            decoration: InputDecoration(
              labelText: _activate ? 'كلمة المرور الجديدة' : 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_activate) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pw2,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _gradientButton(
            label: _activate ? 'تفعيل ودخول' : 'دخول',
            icon: _activate ? Icons.verified_user : Icons.login,
            onTap: _busy ? null : _submit,
          ),
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
            onPressed: _busy ? null : _google,
            icon: const _GoogleMark(),
            label: const Text('الدخول بحساب Google'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _activate = !_activate;
                      _pw.clear();
                      _pw2.clear();
                    }),
            child: Text(_activate
                ? 'لديك حساب مفعّل؟ تسجيل الدخول'
                : 'أول مرة؟ تفعيل حساب جديد'),
          ),
        ],
      ),
    );
  }

  Widget _gradientButton(
      {required String label, required IconData icon, VoidCallback? onTap}) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.mainGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(label,
                            style: const TextStyle(
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
            Text(
                'المدير: ${AppConfig.demoAdminId} / ${AppConfig.demoAdminPassword}'),
            Text(
                'دكتور: ${AppConfig.demoDoctorId} / ${AppConfig.demoDoctorPassword}'),
            const Text(
                'طالب: فعّل الحساب برقمك المعرفي من "تفعيل حساب جديد"'),
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
