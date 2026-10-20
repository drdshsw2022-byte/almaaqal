import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'config.dart';
import 'data/firebase_repo.dart';
import 'data/local_repo.dart';
import 'models.dart';
import 'screens/admin/admin_home.dart';
import 'screens/doctor/doctor_home.dart';
import 'screens/login_screen.dart';
import 'screens/student/student_home.dart';
import 'theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AlmaqalApp());
}

class AlmaqalApp extends StatelessWidget {
  const AlmaqalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حضور ${AppConfig.universityName}',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const BootScreen(),
    );
  }
}

/// شاشة الإقلاع: تهيئة مصدر البيانات واستعادة الجلسة.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _error = null);
    try {
      if (AppConfig.firebaseEnabled) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: AppConfig.fbApiKey,
            appId: AppConfig.fbAppId,
            messagingSenderId: AppConfig.fbSenderId,
            projectId: AppConfig.fbProjectId,
            storageBucket: AppConfig.fbStorageBucket,
          ),
        );
        AppState.repo = FirebaseRepo();
      } else {
        final local = LocalRepo();
        await local.init();
        AppState.repo = local;
      }
      final results = await Future.wait([
        AppState.repo.restoreSession(),
        Future.delayed(const Duration(milliseconds: 1200)),
      ]);
      final user = results.first as AppUser?;
      if (user != null) await AppState.refreshSettings();
      AppState.user.value = user;
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return ValueListenableBuilder<AppUser?>(
        valueListenable: AppState.user,
        builder: (context, user, _) {
          if (user == null) return const LoginScreen();
          return switch (user.role) {
            Role.admin => const AdminHome(),
            Role.doctor => const DoctorHome(),
            Role.student => const StudentHome(),
          };
        },
      );
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 120),
              const SizedBox(height: 24),
              const Text(AppConfig.universityName,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${AppConfig.city} • ${AppConfig.appName}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 15)),
              const SizedBox(height: 36),
              if (_error == null)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      color: AppColors.gold, strokeWidth: 3),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _boot,
                        child: const Text('إعادة المحاولة',
                            style: TextStyle(color: AppColors.gold)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
