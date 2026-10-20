import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../models.dart';
import 'repo.dart';

/// التنفيذ الحقيقي على Firebase (Auth + Firestore).
///
/// الدخول بالرقم الجامعي يستخدم بريداً داخلياً: <الرقم>@id.almaqal.app
/// والدخول بـ Google يُربط بالطالب/الدكتور عبر حقل email.
class FirebaseRepo implements Repo {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: AppConfig.googleWebClientId.isEmpty
        ? null
        : AppConfig.googleWebClientId,
  );

  List<Student>? _studentsCache;
  List<Course>? _coursesCache;

  @override
  bool get isDemo => false;

  CollectionReference<Map<String, dynamic>> get _students =>
      _db.collection('students');
  CollectionReference<Map<String, dynamic>> get _staff =>
      _db.collection('staff');
  CollectionReference<Map<String, dynamic>> get _courses =>
      _db.collection('courses');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _attendance =>
      _db.collection('attendance');

  static String _idEmail(String id) =>
      '${id.trim().toLowerCase()}@${AppConfig.idEmailDomain}';

  static String? _idFromEmail(String? email) {
    if (email == null) return null;
    final suffix = '@${AppConfig.idEmailDomain}';
    return email.endsWith(suffix)
        ? email.substring(0, email.length - suffix.length)
        : null;
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return 'الرقم أو كلمة المرور غير صحيحة، أو الحساب غير مفعّل بعد';
      case 'email-already-in-use':
        return 'هذا الحساب مفعّل مسبقاً، سجّل الدخول بكلمة المرور';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'requires-recent-login':
        return 'سجّل الخروج ثم الدخول مجدداً وأعد المحاولة';
      default:
        return e.message ?? 'خطأ في المصادقة (${e.code})';
    }
  }

  /// يبحث عن ملف المستخدم بالرقم (الكادر أولاً ثم الطلاب).
  Future<AppUser?> _profileById(String id) async {
    final st = await _staff.doc(id).get();
    if (st.exists) return AppUser.staff(Staff.fromMap(st.data()!));
    final s = await _students.doc(id).get();
    if (s.exists) return AppUser.student(Student.fromMap(s.data()!));
    // المعرّفات قد تُحفظ بأحرف كبيرة (مثل D1001)
    final up = id.toUpperCase();
    if (up != id) {
      final st2 = await _staff.doc(up).get();
      if (st2.exists) return AppUser.staff(Staff.fromMap(st2.data()!));
    }
    return null;
  }

  Future<AppUser?> _profileByEmail(String email) async {
    email = email.toLowerCase();
    final st = await _staff.where('email', isEqualTo: email).limit(1).get();
    if (st.docs.isNotEmpty) {
      return AppUser.staff(Staff.fromMap(st.docs.first.data()));
    }
    final s = await _students.where('email', isEqualTo: email).limit(1).get();
    if (s.docs.isNotEmpty) {
      return AppUser.student(Student.fromMap(s.docs.first.data()));
    }
    if (AppConfig.superAdminEmails.contains(email)) {
      // تهيئة المدير العام تلقائياً عند أول دخول
      final admin = Staff(
          id: 'superadmin',
          name: 'مدير النظام',
          role: 'admin',
          email: email,
          activated: true);
      await _staff.doc(admin.id).set(admin.toMap());
      return AppUser.staff(admin);
    }
    return null;
  }

  // ---------------- الحساب ----------------
  @override
  Future<AppUser?> restoreSession() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    try {
      final id = _idFromEmail(u.email);
      if (id != null) return await _profileById(id);
      if (u.email != null) return await _profileByEmail(u.email!);
    } catch (_) {}
    return null;
  }

  @override
  Future<AppUser> signInWithId(String id, String password) async {
    id = id.trim();
    try {
      await _auth.signInWithEmailAndPassword(
          email: _idEmail(id), password: password);
    } on FirebaseAuthException catch (e) {
      throw AppException(_authError(e));
    }
    final p = await _profileById(id);
    if (p == null) {
      await _auth.signOut();
      throw AppException('لا يوجد ملف لهذا الرقم في قاعدة البيانات');
    }
    return p;
  }

  @override
  Future<AppUser> activateAccount(String id, String newPassword) async {
    id = id.trim();
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
          email: _idEmail(id), password: newPassword);
    } on FirebaseAuthException catch (e) {
      throw AppException(_authError(e));
    }
    final p = await _profileById(id);
    if (p == null) {
      // الرقم غير موجود في قاعدة البيانات: نحذف الحساب المؤقت
      await cred.user?.delete();
      await _auth.signOut();
      throw AppException(
          'الرقم $id غير موجود في قاعدة بيانات الجامعة. راجع المدير');
    }
    final already = p.student?.activated ?? p.staff!.activated;
    if (already) {
      await cred.user?.delete();
      await _auth.signOut();
      throw AppException(
          'هذا الرقم مفعّل مسبقاً. إذا لم تكن أنت من فعّله راجع المدير');
    }
    if (p.student != null) {
      await _students.doc(p.id).update({'activated': true});
      return AppUser.student(p.student!.copyWith(activated: true));
    }
    await _staff.doc(p.id).update({'activated': true});
    return AppUser.staff(p.staff!.copyWith(activated: true));
  }

  @override
  Future<AppUser> signInWithGoogle({String? demoEmail}) async {
    final acc = await _google.signIn();
    if (acc == null) throw AppException('تم إلغاء تسجيل الدخول');
    final ga = await acc.authentication;
    final credential = GoogleAuthProvider.credential(
        idToken: ga.idToken, accessToken: ga.accessToken);
    try {
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      await _google.signOut();
      throw AppException(_authError(e));
    }
    final email = (acc.email).toLowerCase();
    final p = await _profileByEmail(email);
    if (p == null) {
      await _auth.signOut();
      await _google.signOut();
      throw NotLinkedException(email);
    }
    return p;
  }

  @override
  Future<AppUser> linkGoogleWithId(
      String googleEmail, String id, String password) async {
    final user = await signInWithId(id, password);
    final email = googleEmail.toLowerCase();
    final taken = await _profileByEmail(email);
    if (taken != null && taken.id != user.id) {
      throw AppException('هذا البريد مرتبط بحساب آخر (${taken.id})');
    }
    if (user.student != null) {
      await _students.doc(user.id).update({'email': email});
      return AppUser.student(user.student!.copyWith(email: email));
    }
    await _staff.doc(user.id).update({'email': email});
    return AppUser.staff(user.staff!.copyWith(email: email));
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final u = _auth.currentUser;
    if (u == null || u.email == null) throw AppException('لم يتم تسجيل الدخول');
    if (_idFromEmail(u.email) == null) {
      throw AppException('حسابك مسجّل عبر Google ولا يحتاج كلمة مرور');
    }
    try {
      await u.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: u.email!, password: oldPassword));
      await u.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AppException(_authError(e));
    }
  }

  @override
  Future<void> signOut() async {
    _studentsCache = null;
    _coursesCache = null;
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // ---------------- تهيئة ----------------
  @override
  Future<bool> isSeeded() async {
    final d = await _db.collection('meta').doc('seed').get();
    return d.exists;
  }

  Future<void> _batchWrite(
      String collection, List<Map<String, dynamic>> items, bool merge,
      void Function(String) onProgress, String label) async {
    const chunk = 400;
    for (var i = 0; i < items.length; i += chunk) {
      final b = _db.batch();
      for (final m in items.skip(i).take(chunk)) {
        b.set(_db.collection(collection).doc('${m['id']}'), m,
            SetOptions(merge: merge));
      }
      await b.commit();
      final done = (i + chunk).clamp(0, items.length);
      onProgress('$label: $done / ${items.length}');
    }
  }

  @override
  Future<void> seedFromAssets(void Function(String msg) onProgress) async {
    onProgress('جاري قراءة الملفات...');
    final d = await SeedData.load();
    await _batchWrite('colleges', d.colleges.map((e) => e.toMap()).toList(),
        true, onProgress, 'الكليات');
    await _batchWrite('departments',
        d.departments.map((e) => e.toMap()).toList(), true, onProgress, 'الأقسام');
    await _batchWrite('courses', d.courses.map((e) => e.toMap()).toList(), true,
        onProgress, 'المواد');
    // للطلاب: لا نكتب الحقول التي قد تكون عُدّلت (القسم، البريد، التفعيل)
    await _batchWrite(
        'students',
        d.students
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'stage': s.stage,
                  'shift': s.shift,
                })
            .toList(),
        true,
        onProgress,
        'الطلاب');
    await _db.collection('settings').doc('app').set(
        const AppSettings().toMap(), SetOptions(merge: true));
    await _db.collection('meta').doc('seed').set({
      'at': DateTime.now().millisecondsSinceEpoch,
      'students': d.students.length,
      'courses': d.courses.length,
    });
    _studentsCache = null;
    _coursesCache = null;
    onProgress('تمت التهيئة بنجاح');
  }

  // ---------------- الهيكل ----------------
  @override
  Future<List<College>> colleges() async {
    final q = await _db.collection('colleges').get();
    return q.docs.map((d) => College.fromMap(d.data())).toList();
  }

  @override
  Future<void> saveCollege(College c) =>
      _db.collection('colleges').doc(c.id).set(c.toMap());

  @override
  Future<void> deleteCollege(String id) =>
      _db.collection('colleges').doc(id).delete();

  @override
  Future<List<Department>> departments() async {
    final q = await _db.collection('departments').get();
    return q.docs.map((d) => Department.fromMap(d.data())).toList();
  }

  @override
  Future<void> saveDepartment(Department d) =>
      _db.collection('departments').doc(d.id).set(d.toMap());

  @override
  Future<void> deleteDepartment(String id) =>
      _db.collection('departments').doc(id).delete();

  @override
  Future<List<Course>> courses() async {
    final cached = _coursesCache;
    if (cached != null) return cached;
    final q = await _courses.get();
    return _coursesCache = q.docs.map((d) => Course.fromMap(d.data())).toList();
  }

  @override
  Future<void> saveCourse(Course c) async {
    await _courses.doc(c.id).set(c.toMap());
    _coursesCache = null;
  }

  @override
  Future<void> deleteCourse(String id) async {
    await _courses.doc(id).delete();
    _coursesCache = null;
  }

  // ---------------- الطلاب ----------------
  @override
  Future<List<Student>> students() async {
    final cached = _studentsCache;
    if (cached != null) return cached;
    final q = await _students.get();
    return _studentsCache =
        q.docs.map((d) => Student.fromMap(d.data())).toList();
  }

  @override
  Future<Student?> student(String id) async {
    final d = await _students.doc(id).get();
    return d.exists ? Student.fromMap(d.data()!) : null;
  }

  @override
  Future<void> saveStudent(Student s) async {
    await _students.doc(s.id).set(s.toMap());
    _studentsCache = null;
  }

  @override
  Future<void> deleteStudent(String id) async {
    await _students.doc(id).delete();
    _studentsCache = null;
  }

  @override
  Future<void> setStudentsDept(List<String> ids, String? deptId) async {
    const chunk = 400;
    for (var i = 0; i < ids.length; i += chunk) {
      final b = _db.batch();
      for (final id in ids.skip(i).take(chunk)) {
        b.update(_students.doc(id), {'deptId': deptId});
      }
      await b.commit();
    }
    _studentsCache = null;
  }

  // ---------------- الكادر ----------------
  @override
  Future<List<Staff>> staff() async {
    final q = await _staff.get();
    return q.docs.map((d) => Staff.fromMap(d.data())).toList();
  }

  @override
  Future<void> saveStaff(Staff s) => _staff.doc(s.id).set(s.toMap());

  @override
  Future<void> deleteStaff(String id) => _staff.doc(id).delete();

  // ---------------- الإعدادات ----------------
  @override
  Future<AppSettings> settings() async {
    final d = await _db.collection('settings').doc('app').get();
    return AppSettings.fromMap(d.data());
  }

  @override
  Future<void> saveSettings(AppSettings s) =>
      _db.collection('settings').doc('app').set(s.toMap());

  // ---------------- المحاضرات ----------------
  @override
  Future<LectureSession> createSession(LectureSession s) async {
    final ref = _sessions.doc();
    final created = s.copyWith(id: ref.id);
    await ref.set(created.toMap());
    return created;
  }

  @override
  Future<void> closeSession(String id) => _sessions.doc(id).update(
      {'active': false, 'endedAt': DateTime.now().millisecondsSinceEpoch});

  @override
  Future<void> deleteSession(String id) async {
    final q = await _attendance.where('sessionId', isEqualTo: id).get();
    final b = _db.batch();
    for (final d in q.docs) {
      b.delete(d.reference);
    }
    b.delete(_sessions.doc(id));
    await b.commit();
  }

  @override
  Future<LectureSession?> session(String id) async {
    final d = await _sessions.doc(id).get();
    return d.exists ? LectureSession.fromMap(d.data()!) : null;
  }

  @override
  Stream<LectureSession?> watchSession(String id) => _sessions
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? LectureSession.fromMap(d.data()!) : null);

  List<LectureSession> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      q.docs.map((d) => LectureSession.fromMap(d.data())).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<LectureSession>> sessionsForCourse(String courseId) async =>
      _sorted(await _sessions.where('courseId', isEqualTo: courseId).get());

  @override
  Future<List<LectureSession>> sessionsForDoctor(String doctorId) async =>
      _sorted(await _sessions.where('doctorId', isEqualTo: doctorId).get());

  @override
  Future<List<LectureSession>> recentSessions({int limit = 50}) async =>
      _sorted(await _sessions
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get());

  @override
  Stream<List<AttendanceRecord>> watchAttendance(String sessionId) =>
      _attendance.where('sessionId', isEqualTo: sessionId).snapshots().map(
          (q) => q.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList()
            ..sort((a, b) => b.time.compareTo(a.time)));

  @override
  Future<List<AttendanceRecord>> attendanceForCourse(String courseId) async {
    final q = await _attendance.where('courseId', isEqualTo: courseId).get();
    return q.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
  }

  @override
  Future<List<AttendanceRecord>> attendanceForStudent(String studentId) async {
    final q = await _attendance.where('studentId', isEqualTo: studentId).get();
    return q.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
  }

  @override
  Future<void> markAttendance(AttendanceRecord r) async {
    final ref = _attendance.doc(r.id);
    final exists = (await ref.get()).exists;
    if (exists) throw AppException('تم تسجيل حضورك في هذه المحاضرة مسبقاً');
    await ref.set(r.toMap());
  }

  @override
  Future<void> removeAttendance(String recordId) =>
      _attendance.doc(recordId).delete();
}
