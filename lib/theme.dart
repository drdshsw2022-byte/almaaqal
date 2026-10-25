import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// هوية «البوابة التقنية الموحدة» (it-basra.com/amu):
/// ليل كحلي عميق + ذهبي كهرماني متوهّج + بطاقات زجاجية بحدود ذهبية.
class AppColors {
  // الخلفيات
  static const night = Color(0xFF060A17); // الخلفية العميقة
  static const navy = Color(0xFF0D1428); // مركز التوهج
  static const bg = Color(0xFF060A17);
  static const card = Color(0xFF0E1527); // سطح البطاقات
  static const surface2 = Color(0xFF151D33); // حقول وعناصر داخلية
  static const line = Color(0x47F59E0B); // حدود ذهبية شفافة (28%)
  static const lineSoft = Color(0x1FFFFFFF);

  // الألوان المميزة
  static const royal = Color(0xFFF59E0B); // اللون الأساسي: كهرماني
  static const violet = Color(0xFFB45309); // كهرماني داكن
  static const gold = Color(0xFFFBBF24); // ذهبي فاتح للعناوين
  static const cyan = Color(0xFF38BDF8); // أزرق سماوي للشارات
  static const emerald = Color(0xFF10B981);
  static const rose = Color(0xFFF43F5E);
  static const orange = Color(0xFFF97316);

  // النصوص
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const onAccent = Color(0xFF1A1203);

  /// ترويسات الصفحات: توهّج كهرماني دافئ يذوب في الكحلي.
  static const mainGradient = LinearGradient(
    colors: [Color(0xFF3A2708), Color(0xFF111A33), night],
    stops: [0, 0.55, 1],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// الأزرار والعناصر المختارة (كزر «اللجنة الامتحانية»).
  static const amberGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// نص العناوين الذهبي.
  static const titleGradient = LinearGradient(
    colors: [Color(0xFFFACC15), Color(0xFFFDE68A), Color(0xFFFBBF24)],
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static LinearGradient grad(Color a, Color b) => LinearGradient(
      colors: [a, b], begin: Alignment.topRight, end: Alignment.bottomLeft);

  /// أيقونات البطاقات (أخضر، أزرق، كهرماني... كما في البوابة).
  static final tilePalette = <LinearGradient>[
    grad(const Color(0xFFF59E0B), const Color(0xFFB45309)),
    grad(const Color(0xFF3B82F6), const Color(0xFF1D4ED8)),
    grad(const Color(0xFF10B981), const Color(0xFF047857)),
    grad(const Color(0xFFFBBF24), const Color(0xFFD97706)),
    grad(const Color(0xFFF43F5E), const Color(0xFFBE123C)),
    grad(const Color(0xFF8B5CF6), const Color(0xFF6D28D9)),
    grad(const Color(0xFF0EA5E9), const Color(0xFF0369A1)),
    grad(const Color(0xFF14B8A6), const Color(0xFF0F766E)),
  ];

  /// خلفية الصفحة: توهّج دائري كحلي كما في البوابة.
  static const pageBackground = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0, -0.75),
      radius: 1.3,
      colors: [navy, Color(0xFF060A17), Color(0xFF02040A)],
      stops: [0, 0.55, 1],
    ),
  );

  /// بطاقة زجاجية بحد ذهبي.
  static BoxDecoration glass({double radius = 22, bool glow = false}) =>
      BoxDecoration(
        color: card.withOpacity(0.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 30,
              offset: const Offset(0, 14),
              spreadRadius: -10),
          if (glow)
            BoxShadow(
                color: royal.withOpacity(0.18),
                blurRadius: 24,
                spreadRadius: -4),
        ],
      );
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: AppColors.royal,
    onPrimary: Colors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.onAccent,
    tertiary: AppColors.cyan,
    surface: AppColors.card,
    onSurface: AppColors.text,
    error: AppColors.rose,
    outline: AppColors.line,
    outlineVariant: AppColors.lineSoft,
    surfaceContainerHighest: AppColors.surface2,
    surfaceContainerHigh: AppColors.surface2,
    surfaceContainer: AppColors.card,
    surfaceContainerLow: AppColors.card,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.card,
    dividerColor: AppColors.lineSoft,
  );
  final text = GoogleFonts.cairoTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  final shape16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
          fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
    ),
    cardTheme: CardTheme(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lineSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lineSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.royal, width: 1.6),
      ),
      labelStyle: GoogleFonts.cairo(color: AppColors.muted),
      hintStyle: GoogleFonts.cairo(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 6,
        shadowColor: const Color(0x66D97706),
        shape: shape16,
        textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        shape: shape16,
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        minimumSize: const Size.fromHeight(52),
        shape: shape16,
        side: const BorderSide(color: AppColors.line),
        textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFD97706),
      foregroundColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: AppColors.text),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.gold,
      textColor: AppColors.text,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface2,
      selectedColor: AppColors.royal.withOpacity(0.25),
      side: const BorderSide(color: AppColors.lineSoft),
      labelStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: TabBarTheme(
      indicatorColor: AppColors.gold,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      dividerColor: Colors.transparent,
      labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.royal.withOpacity(0.22),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.muted)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? const Color(0xFFD97706)
              : AppColors.surface2),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? const Color(0xFFD97706) : null),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.royal),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.surface2),
      headingTextStyle: GoogleFonts.cairo(
          fontWeight: FontWeight.w800, color: AppColors.gold, fontSize: 12.5),
      dataTextStyle: GoogleFonts.cairo(color: AppColors.text, fontSize: 12.5),
      dividerThickness: 0.5,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line)),
      textStyle: GoogleFonts.cairo(color: AppColors.text),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line)),
      contentTextStyle: GoogleFonts.cairo(color: Colors.white),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.gold,
      collapsedIconColor: AppColors.muted,
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface2)),
    ),
  );
}
