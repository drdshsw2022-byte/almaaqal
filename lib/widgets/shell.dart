import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../screens/common/profile_sheet.dart';
import '../theme.dart';
import 'common.dart';

/// عنصر في القائمة الجانبية.
class KNavItem {
  final IconData icon;
  final String label;
  final String? group; // عنوان المجموعة التي يبدأ بها العنصر
  const KNavItem(this.icon, this.label, {this.group});
}

/// هيكل التطبيق بنمط «نظام الكنترول»: قائمة جانبية يمين + شريط علوي بساعة البصرة.
/// على الهاتف تتحول القائمة إلى درج جانبي.
class KShell extends StatelessWidget {
  final String roleTitle;
  final String roleSubtitle;
  final List<KNavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget child;
  final Widget? bottomNav;

  const KShell({
    super.key,
    required this.roleTitle,
    required this.roleSubtitle,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.child,
    this.bottomNav,
  });

  static const wideBreakpoint = 980.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= wideBreakpoint;
      if (wide) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              SizedBox(width: 250, child: _sidebar(context, false)),
              Container(width: 1, color: AppColors.lineSoft),
              Expanded(
                child: Column(
                  children: [
                    const _TopBar(showMenu: false),
                    Expanded(
                        child: MediaQuery.removePadding(
                            context: context, removeTop: true, child: child)),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.transparent,
        drawer: Drawer(
          width: 270,
          backgroundColor: AppColors.night,
          shape: const RoundedRectangleBorder(),
          child: _sidebar(context, true),
        ),
        body: Column(
          children: [
            const _TopBar(showMenu: true),
            Expanded(
                child: MediaQuery.removePadding(
                    context: context, removeTop: true, child: child)),
          ],
        ),
        bottomNavigationBar: bottomNav,
      );
    });
  }

  Widget _sidebar(BuildContext context, bool inDrawer) {
    final user = AppState.user.value;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111A30), Color(0xFF080D1A)],
        ),
      ),
      child: SafeArea(
        right: false,
        left: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          children: [
            // الشعار والاسم
            Row(
              children: [
                const AppLogo(size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(AppConfig.universityName,
                          maxLines: 2,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              height: 1.25,
                              color: Colors.white)),
                      const Text('نظام الحضور الذكي',
                          style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5)),
                      Text('AL-MAAQAL UNIVERSITY',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                              color: AppColors.muted.withOpacity(0.8),
                              fontSize: 8.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // بطاقة المستخدم
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(roleSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.gold, fontSize: 11.5)),
                  if (user != null) ...[
                    const SizedBox(height: 2),
                    Text(user.displayId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 10.5)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _miniBtn(Icons.person_outline, 'حسابي', () {
                          if (inDrawer) Navigator.pop(context);
                          showProfileSheet(context);
                        }),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _miniBtn(Icons.logout, 'خروج', () => logout(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < items.length; i++) ...[
              if (items[i].group != null) _groupLabel(items[i].group!),
              _navTile(context, i, inDrawer),
            ],
            const SizedBox(height: 18),
            Text('© ${DateTime.now().year} ${AppConfig.universityName}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData i, String t, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, size: 15, color: AppColors.text),
              const SizedBox(width: 4),
              Text(t,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _groupLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Row(
          children: [
            Text(t,
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: AppColors.line)),
          ],
        ),
      );

  Widget _navTile(BuildContext context, int i, bool inDrawer) {
    final on = i == selected;
    final it = items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (inDrawer) Navigator.pop(context);
          onSelect(i);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: on
                ? LinearGradient(colors: [
                    const Color(0xFFF59E0B).withOpacity(0.22),
                    const Color(0xFFD97706).withOpacity(0.10),
                  ])
                : null,
            border: Border.all(
                color: on ? AppColors.line : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(it.icon,
                  size: 18, color: on ? AppColors.gold : AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: on ? AppColors.gold : AppColors.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الشريط العلوي: حالة الاتصال + توقيت البصرة.
class _TopBar extends StatelessWidget {
  final bool showMenu;
  const _TopBar({required this.showMenu});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final online = !repo.isDemo;
    return Container(
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xCC0B1120),
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          if (showMenu)
            Builder(
              builder: (c) => IconButton(
                onPressed: () => Scaffold.of(c).openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: AppColors.gold),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.lineSoft),
              color: AppColors.card.withOpacity(0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle,
                    size: 8,
                    color: online ? AppColors.emerald : AppColors.orange),
                const SizedBox(width: 6),
                Text(online ? 'متصل بالخادم' : 'وضع محلي',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Spacer(),
          const BasraClock(),
        ],
      ),
    );
  }
}

/// ساعة البصرة (GMT+3) بأرقام ذهبية.
class BasraClock extends StatefulWidget {
  const BasraClock({super.key});

  @override
  State<BasraClock> createState() => _BasraClockState();
}

class _BasraClockState extends State<BasraClock> {
  Timer? _t;
  DateTime _now = _basra();

  static DateTime _basra() =>
      DateTime.now().toUtc().add(const Duration(hours: 3));

  static const _days = [
    'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ];
  static const _months = [
    'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب',
    'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _basra());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Widget _box(String v) => Container(
        width: 28,
        padding: const EdgeInsets.symmetric(vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.lineSoft),
        ),
        child: Text(v,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()])),
      );

  @override
  Widget build(BuildContext context) {
    final n = _now;
    final h12 = n.hour % 12 == 0 ? 12 : n.hour % 12;
    String two(int x) => x.toString().padLeft(2, '0');
    final date = '${_days[n.weekday - 1]}، ${n.day} ${_months[n.month - 1]} ${n.year}';
    return LayoutBuilder(builder: (context, c) {
      final narrow = MediaQuery.of(context).size.width < 560;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!narrow) ...[
            Text(date,
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: AppColors.gold, borderRadius: BorderRadius.circular(5)),
            child: Text(n.hour < 12 ? 'ص' : 'م',
                style: const TextStyle(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
          ),
          const SizedBox(width: 5),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _box(two(h12)),
                const Text(' : ', style: TextStyle(color: AppColors.muted)),
                _box(two(n.minute)),
                const Text(' : ', style: TextStyle(color: AppColors.muted)),
                _box(two(n.second)),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// منطقة محتوى لها ملاحتها الخاصة، فتبقى القائمة الجانبية ظاهرة عند فتح صفحات فرعية.
class KSection extends StatefulWidget {
  final WidgetBuilder builder;
  const KSection({super.key, required this.builder});

  @override
  State<KSection> createState() => _KSectionState();
}

class _KSectionState extends State<KSection> {
  final _nav = GlobalKey<NavigatorState>();
  final _tick = ValueNotifier<int>(0);

  @override
  void didUpdateWidget(covariant KSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // أعد بناء الصفحة الأساسية عند تغيّر بيانات الأب
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tick.value++;
    });
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPop: () => _nav.currentState?.maybePop(),
      child: Navigator(
        key: _nav,
        onGenerateRoute: (_) => PageRouteBuilder(
          pageBuilder: (c, _, __) => ValueListenableBuilder<int>(
              valueListenable: _tick,
              builder: (c, _, __) => widget.builder(c)),
          transitionDuration: Duration.zero,
        ),
      ),
    );
  }
}

/// عنوان قسم بنمط الكنترول: وسم صغير + عنوان + وصف.
class KSectionHeader extends StatelessWidget {
  final String tag;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const KSectionHeader(
      {super.key,
      required this.tag,
      required this.title,
      this.subtitle,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(tag,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.gold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w900)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
