/// إعدادات التطبيق العامة.
///
/// إعدادات Firebase تُمرَّر وقت البناء عبر --dart-define (انظر README).
/// إذا تُركت فارغة يعمل التطبيق في "الوضع التجريبي" المحلي على جهاز واحد.
class AppConfig {
  static const universityName = 'جامعة المعقل الأهلية';
  static const city = 'البصرة';
  static const appName = 'نظام الحضور الذكي';

  /// حسابات Google التي تملك صلاحية المدير العام دائماً.
  static const superAdminEmails = <String>['drdsh.sw2022@gmail.com'];

  /// مدة صلاحية رمز QR الواحد بالثواني (يتجدد تلقائياً).
  static const qrWindowSeconds = 15;

  /// عدد النوافذ الزمنية المقبولة قبل/بعد الحالية (لتحمّل فروق ساعات الأجهزة).
  static const qrTolerance = 4;

  /// نطاق البريد الداخلي لتسجيل الدخول بالرقم الجامعي.
  static const idEmailDomain = 'id.almaqal.app';

  // ---------------- Firebase ----------------
  static const fbApiKey = String.fromEnvironment('FB_API_KEY');
  static const fbAppId = String.fromEnvironment('FB_APP_ID');
  static const fbSenderId = String.fromEnvironment('FB_SENDER_ID');
  static const fbProjectId = String.fromEnvironment('FB_PROJECT_ID');
  static const fbStorageBucket = String.fromEnvironment('FB_STORAGE_BUCKET');
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool get firebaseEnabled =>
      fbApiKey.isNotEmpty && fbAppId.isNotEmpty && fbProjectId.isNotEmpty;

  // ---------------- الوضع التجريبي ----------------
  static const demoAdminId = 'admin';
  static const demoAdminPassword = 'admin123';
  static const demoDoctorId = 'D1001';
  static const demoDoctorPassword = '123456';
}
