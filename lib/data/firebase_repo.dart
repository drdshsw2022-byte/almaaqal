import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../models.dart';
import 'repo.dart';

/// التنفيذ الحقيقي على Firebase (Auth + Firestore).
///
/// الدخول بحساب Google الجامعي (@almaaqal.edu.iq) فقط.
/// الكادر: مستند staff/<البريد>. الطالب: مستند students/<الرقم المعرفي> بحقل email.
class FirebaseRepo implements Repo {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn(
    scopes: const ['email'],
    hostedDomain: AppConfig.universityDomain,
    serverClientId: AppConfig.googleWebClientId.isEmpty
        ? null
        : AppConfig.googleWebClientId,
  );
  // للمدير العام من خارج نطاق الجامعة
  final _googleAny = GoogleSignIn(
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

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'تعذّر الاتصال بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'user-disabled':
        return 'هذا الحساب معطّل';
      default:
        return e.message ?? 'خطأ في المصادقة (${e.code})';
    }
  }

  Future<AppUser?> _profileByEmail(String email) async {
    email = email.toLowerCase();
    final st = await _staff.doc(email).get();
    if (st.exists) return AppUser.staff(Staff.fromMap(st.data()!));
    final s = await _students.where('email', isEqualTo: email).limit(1).get();
    if (s.docs.isNotEmpty) {
      return AppUser.student(Student.fromMap(s.docs.first.data()));
    }
    // بريد بصيغة <الرقم المعرفي>@النطاق لطالب لم يُسجَّل بريده بعد
    if (AppConfig.isUniversityEmail(email)) {
      final byId = await _students.doc(email.split('@').first).get();
      if (byId.exists) {
        final stu = Student.fromMap(byId.data()!);
        if (stu.email == null) return AppUser.student(stu);
      }
    }
    if (AppConfig.superAdminEmails.contains(email)) {
      // تهيئة المدير العام تلقائياً عند أول دخول
      final admin = Staff(id: email, name: 'مدير النظام', role: 'admin');
      await _staff.doc(admin.id).set(admin.toMap());
      return AppUser.staff(admin);
    }
    return null;
  }

  // ---------------- الحساب ----------------
  @override
  Future<AppUser?> restoreSession() async {
    final u = _auth.currentUser;
    if (u?.email == null) return null;
    try {
      return await _profileByEmail(u!.email!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> signInWithGoogle({String? demoEmail}) async {
    // demoEmail هنا = "superadmin" لفتح نافذة اختيار أي حساب للمدير العام
    final g = demoEmail == 'superadmin' ? _googleAny : _google;
    final acc = await g.signIn();
    if (acc == null) throw AppException('تم إلغاء تسجيل الدخول');
    final email = acc.email.toLowerCase();
    if (!AppConfig.isAllowedEmail(email)) {
      await g.signOut();
      throw AppException(
          'يُقبل البريد الجامعي الرسمي فقط (@${AppConfig.universityDomain})');
    }
    final ga = await acc.authentication;
    final credential = GoogleAuthProvider.credential(
        idToken: ga.idToken, accessToken: ga.accessToken);
    try {
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      await g.signOut();
      throw AppException(_authError(e));
    }
    final p = await _profileByEmail(email);
    if (p == null) {
      await _auth.signOut();
      await g.signOut();
      throw NotRegisteredException(email);
    }
    return p;
  }

  @override
  Future<void> signOut() async {
    _studentsCache = null;
    _coursesCache = null;
    for (final g in [_google, _googleAny]) {
      try {
        await g.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ---------------- تهيئة ----------------
  @override
  Future<bool> isSeeded() async {
    final d = await _db.collection('meta').doc('seed').get();
    return d.exists;
  }

  Future<void> _batchWrite(
      String collection,
      List<Map<String, dynamic>> items,
      void Function(String) onProgress,
      String label) async {
    const chunk = 400;
    for (var i = 0; i < items.length; i += chunk) {
      final b = _db.batch();
      for (final m in items.skip(i).take(chunk)) {
        b.set(_db.collection(collection).doc('${m['id']}'), m,
            SetOptions(merge: true));
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
        onProgress, 'الكليات');
    await _batchWrite('departments',
        d.departments.map((e) => e.toMap()).toList(), onProgress, 'الأقسام');
    await _batchWrite(
        'courses', d.courses.map((e) => e.toMap()).toList(), onProgress, 'المواد');
    // للطلاب: لا نمسح ربط NFC ولا ما عدّله المدير إن كان الملف لا يحويه
    await _batchWrite(
        'students',
        d.students
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'stage': s.stage,
                  'shift': s.shift,
                  if (s.deptId != null) 'deptId': s.deptId,
                  if (s.email != null) 'email': s.email,
                })
            .toList(),
        onProgress,
        'الطلاب');
    await _db
        .collection('settings')
        .doc('app')
        .set(const AppSettings().toMap(), SetOptions(merge: true));
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
  Future<Student?> studentByEmail(String email) async =>
      (await _profileByEmail(email))?.student;

  @override
  Future<Student?> studentByNfc(String uid) async {
    final q = await _students
        .where('nfcUid', isEqualTo: uid.toUpperCase())
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : Student.fromMap(q.docs.first.data());
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

  @override
  Future<void> setStudentNfc(String studentId, String? uid) async {
    if (uid != null) {
      final other = await studentByNfc(uid);
      if (other != null && other.id != studentId) {
        throw AppException('هذه البطاقة مرتبطة بالطالب ${other.name}');
      }
    }
    await _students
        .doc(studentId)
        .update({'nfcUid': uid?.toUpperCase()});
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
  Future<List<LectureSession>> sessionsSince(int ms) async =>
      _sorted(await _sessions.where('startedAt', isGreaterThanOrEqualTo: ms).get());

  @override
  Future<List<AttendanceRecord>> attendanceSince(int ms) async {
    final q = await _attendance.where('time', isGreaterThanOrEqualTo: ms).get();
    return q.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList();
  }

  Future<void> _bulk(String col, List<Map<String, dynamic>> items) async {
    const chunk = 400;
    for (var i = 0; i < items.length; i += chunk) {
      final b = _db.batch();
      for (final m in items.skip(i).take(chunk)) {
        b.set(_db.collection(col).doc('${m['id']}'), m, SetOptions(merge: true));
      }
      await b.commit();
    }
  }

  @override
  Future<void> saveStudentsBulk(List<Student> list) async {
    await _bulk('students', list.map((s) => s.toMap()).toList());
    _studentsCache = null;
  }

  @override
  Future<void> saveCoursesBulk(List<Course> list) async {
    await _bulk('courses', list.map((c) => c.toMap()).toList());
    _coursesCache = null;
  }

  @override
  Future<void> saveStaffBulk(List<Staff> list) =>
      _bulk('staff', list.map((s) => s.toMap()).toList());

  @override
  Future<void> markAttendance(AttendanceRecord r) async {
    final ref = _attendance.doc(r.id);
    final exists = (await ref.get()).exists;
    if (exists) throw AppException('${r.studentName} مسجّل حضوره مسبقاً');
    await ref.set(r.toMap());
  }

  @override
  Future<void> removeAttendance(String recordId) =>
      _attendance.doc(recordId).delete();
}
