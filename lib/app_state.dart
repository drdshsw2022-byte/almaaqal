import 'package:flutter/material.dart';

import 'data/repo.dart';
import 'models.dart';

/// حالة التطبيق العامة (المستخدم الحالي ومصدر البيانات).
class AppState {
  AppState._();
  static late Repo repo;
  static final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);
  static AppSettings settings = const AppSettings();

  static Future<void> refreshSettings() async {
    try {
      settings = await repo.settings();
    } catch (_) {}
  }
}

Repo get repo => AppState.repo;
