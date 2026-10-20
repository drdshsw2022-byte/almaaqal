#!/usr/bin/env bash
# يولّد ملفات منصة Android (إن لم تكن موجودة) ويضبط إعداداتها للتطبيق.
set -euo pipefail

if [ ! -f android/app/build.gradle ] && [ ! -f android/app/build.gradle.kts ]; then
  flutter create --platforms=android --org iq.edu.almaqal \
    --project-name almaqal_attendance --no-pub .
fi

# ملف الاختبار الافتراضي يشير إلى MyApp غير الموجود
rm -f test/widget_test.dart

APP_GRADLE=android/app/build.gradle
SETTINGS=android/settings.gradle
MANIFEST=android/app/src/main/AndroidManifest.xml

if [ -f "$APP_GRADLE" ]; then
  # Firebase Auth يتطلب Android 6.0 فأعلى
  sed -i -E 's/minSdk(Version)?( *= *| +)flutter\.minSdkVersion/minSdk = 23/' "$APP_GRADLE"
fi

if [ -f "$SETTINGS" ]; then
  # مكتبات Firebase الحديثة تحتاج Kotlin 1.9 فأعلى
  sed -i -E 's/(id "org\.jetbrains\.kotlin\.android" version ")[^"]*(")/\11.9.24\2/' "$SETTINGS"
fi

# اسم التطبيق على الهاتف
sed -i -E 's/android:label="[^"]*"/android:label="حضور المعقل"/' "$MANIFEST"

# صلاحيات الإنترنت والكاميرا
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#&\n    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.CAMERA"/>#' "$MANIFEST"
fi

echo "----- settings.gradle -----"; cat "$SETTINGS" || true
echo "----- app/build.gradle -----"; cat "$APP_GRADLE" || true
echo "----- AndroidManifest.xml -----"; cat "$MANIFEST"
