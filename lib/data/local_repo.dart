import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';
import 'repo.dart';

/// تنفيذ محلي (الوضع التجريبي): كل البيانات على الجهاز نفسه.
class LocalRepo implements Repo {
  late SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  final Map<String, College> _colleges = {};
  final Map<String, Department> _departments = {};
  final Map<String, Course> _courses = {};
  final Map<String, Student> _students = {};
  final Map<String, Staff> _staff = {};
  final Map<String, LectureSession> _sessions = {};
  final Map<String, AttendanceRecord> _attendance = {};
  AppSettings _settings = const AppSettings();
  String? _currentEmail;

  static const _key = 'almaqal_local_db_v3';

  @override
  bool get isDemo => true;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw == null) {
      await _seed();
      return;
    }
    final m = jsonDecode(raw) as Map<String, dynamic>;
    Map<String, dynamic> mp(dynamic e) => Map<String, dynamic>.from(e as Map);
    for (final e in (m['colleges'] as List? ?? [])) {
      final c = College.fromMap(mp(e));
      _colleges[c.id] = c;
    }
    for (final e in (m['departments'] as List? ?? [])) {
      final d = Department.fromMap(mp(e));
      _departments[d.id] = d;
    }
    for (final e in (m['courses'] as List? ?? [])) {
      final c = Course.fromMap(mp(e));
      _courses[c.id] = c;
    }
    for (final e in (m['students'] as List? ?? [])) {
      final s = Student.fromMap(mp(e));
      _students[s.id] = s;
    }
    for (final e in (m['staff'] as List? ?? [])) {
      final s = Staff.fromMap(mp(e));
      _staff[s.id] = s;
    }
    for (final e in (m['sessions'] as List? ?? [])) {
      final s = LectureSession.fromMap(mp(e));
      _sessions[s.id] = s;
    }
    for (final e in (m['attendance'] as List? ?? [])) {
      final a = AttendanceRecord.fromMap(mp(e));
      _attendance[a.id] = a;
    }
    _settings = AppSettings.fromMap(
        m['settings'] == null ? null : mp(m['settings']));
    _currentEmail = m['currentEmail'] as String?;
  }

  Future<void> _save() async {
    final m = {
      'colleges': _colleges.values.map((e) => e.toMap()).toList(),
      'departments': _departments.values.map((e) => e.toMap()).toList(),
      'courses': _courses.values.map((e) => e.toMap()).toList(),
      'students': _students.values.map((e) => e.toMap()).toList(),
      'staff': _staff.values.map((e) => e.toMap()).toList(),
      'sessions': _sessions.values.map((e) => e.toMap()).toList(),
      'attendance': _attendance.values.map((e) => e.toMap()).toList(),
      'settings': _settings.toMap(),
      'currentEmail': _currentEmail,
    };
    await _prefs.setString(_key, jsonEncode(m));
    _changes.add(null);
  }

  Future<void> _seed() async {
    final d = await SeedData.load();
    for (final c in d.colleges) {
      _colleges[c.id] = c;
    }
    for (final x in d.departments) {
      _departments[x.id] = x;
    }
    for (final c in d.courses) {
      _courses[c.id] = c;
    }
    for (final s in d.students) {
      _students[s.id] = s;
    }
    final admin = Staff(
        id: AppConfig.demoAdminEmail, name: 'مدير النظام', role: 'admin');
    _staff[admin.id] = admin;
    for (final e in AppConfig.superAdminEmails) {
      _staff[e] = Staff(id: e, name: 'مدير النظام', role: 'admin');
    }
    final demoCourses = d.courses
        .where((c) => c.deptId == 'ai' && (c.stage == 2 || c.stage == 3))
        .map((c) => c.id)
        .toList();
    final doc = Staff(
        id: AppConfig.demoDoctorEmail,
        name: 'د. حساب تجريبي',
        role: 'doctor',
        deptId: 'ai',
        courseIds: demoCourses);
    _staff[doc.id] = doc;
    for (final x in [
      Staff(
          id: AppConfig.demoPresidentEmail,
          name: 'أ.د. رئيس الجامعة',
          role: 'president'),
      Staff(
          id: AppConfig.demoDeanEmail,
          name: 'أ.د. عميد كلية الهندسة',
          role: 'dean',
          collegeId: 'eng'),
      Staff(
          id: AppConfig.demoHeadEmail,
          name: 'أ.م.د. رئيس قسم الذكاء الاصطناعي',
          role: 'head',
          deptId: 'ai',
          courseIds: demoCourses.take(3).toList()),
    ]) {
      _staff[x.id] = x;
    }
    await _save();
  }

  /// يجد المستخدم بالبريد: الكادر أولاً، ثم الطلاب (بحقل البريد أو <الرقم>@النطاق).
  AppUser? _userByEmail(String email) {
    final e = email.trim().toLowerCase();
    final st = _staff[e];
    if (st != null) return AppUser.staff(st);
    for (final s in _students.values) {
      if (s.email == e) return AppUser.student(s);
    }
    final local = e.split('@').first;
    if (AppConfig.isUniversityEmail(e)) {
      final s = _students[local];
      if (s != null && s.email == null) return AppUser.student(s);
    }
    return null;
  }

  // ---------------- الحساب ----------------
  @override
  Future<AppUser?> restoreSession() async {
    final e = _currentEmail;
    if (e == null) return null;
    return _userByEmail(e);
  }

  @override
  Future<AppUser> signInWithGoogle({String? demoEmail}) async {
    final email = (demoEmail ?? '').trim().toLowerCase();
    if (email.isEmpty) throw AppException('أدخل البريد الجامعي');
    if (!AppConfig.isAllowedEmail(email)) {
      throw AppException(
          'يُقبل البريد الجامعي الرسمي فقط (@${AppConfig.universityDomain})');
    }
    final u = _userByEmail(email);
    if (u == null) throw NotRegisteredException(email);
    _currentEmail = email;
    await _save();
    return u;
  }

  @override
  Future<void> signOut() async {
    _currentEmail = null;
    await _save();
  }

  // ---------------- تهيئة ----------------
  @override
  Future<bool> isSeeded() async => _courses.isNotEmpty;

  @override
  Future<void> seedFromAssets(void Function(String msg) onProgress) async {
    onProgress('جاري تحميل البيانات...');
    final d = await SeedData.load();
    for (final c in d.colleges) {
      _colleges.putIfAbsent(c.id, () => c);
    }
    for (final x in d.departments) {
      _departments.putIfAbsent(x.id, () => x);
    }
    for (final c in d.courses) {
      _courses.putIfAbsent(c.id, () => c);
    }
    for (final s in d.students) {
      final old = _students[s.id];
      _students[s.id] = old == null
          ? s
          : old.copyWith(
              name: s.name,
              stage: s.stage,
              shift: s.shift,
              deptId: s.deptId ?? old.deptId,
              email: s.email ?? old.email);
    }
    await _save();
    onProgress('تمت التهيئة');
  }

  // ---------------- الهيكل ----------------
  @override
  Future<List<College>> colleges() async => _colleges.values.toList();
  @override
  Future<void> saveCollege(College c) async {
    _colleges[c.id] = c;
    await _save();
  }

  @override
  Future<void> deleteCollege(String id) async {
    _colleges.remove(id);
    await _save();
  }

  @override
  Future<List<Department>> departments() async => _departments.values.toList();
  @override
  Future<void> saveDepartment(Department d) async {
    _departments[d.id] = d;
    await _save();
  }

  @override
  Future<void> deleteDepartment(String id) async {
    _departments.remove(id);
    await _save();
  }

  @override
  Future<List<Course>> courses() async => _courses.values.toList();
  @override
  Future<void> saveCourse(Course c) async {
    _courses[c.id] = c;
    await _save();
  }

  @override
  Future<void> deleteCourse(String id) async {
    _courses.remove(id);
    await _save();
  }

  // ---------------- الطلاب ----------------
  @override
  Future<List<Student>> students() async => _students.values.toList();
  @override
  Future<Student?> student(String id) async => _students[id];

  @override
  Future<Student?> studentByEmail(String email) async =>
      _userByEmail(email)?.student;

  @override
  Future<Student?> studentByNfc(String uid) async {
    final u = uid.toUpperCase();
    for (final s in _students.values) {
      if (s.nfcUid == u) return s;
    }
    return null;
  }

  @override
  Future<void> saveStudent(Student s) async {
    _students[s.id] = s;
    await _save();
  }

  @override
  Future<void> deleteStudent(String id) async {
    _students.remove(id);
    await _save();
  }

  @override
  Future<void> setStudentsDept(List<String> ids, String? deptId) async {
    for (final id in ids) {
      final s = _students[id];
      if (s != null) {
        _students[id] = s.copyWith(deptId: deptId, clearDept: deptId == null);
      }
    }
    await _save();
  }

  @override
  Future<void> setStudentNfc(String studentId, String? uid) async {
    final s = _students[studentId];
    if (s == null) throw AppException('الطالب غير موجود');
    if (uid != null) {
      final other = await studentByNfc(uid);
      if (other != null && other.id != studentId) {
        throw AppException('هذه البطاقة مرتبطة بالطالب ${other.name}');
      }
    }
    _students[studentId] = s.copyWith(
        nfcUid: uid?.toUpperCase(), clearNfc: uid == null);
    await _save();
  }

  // ---------------- الكادر ----------------
  @override
  Future<List<Staff>> staff() async => _staff.values.toList();
  @override
  Future<void> saveStaff(Staff s) async {
    _staff[s.id] = s;
    await _save();
  }

  @override
  Future<void> deleteStaff(String id) async {
    _staff.remove(id);
    await _save();
  }

  // ---------------- الإعدادات ----------------
  @override
  Future<AppSettings> settings() async => _settings;
  @override
  Future<void> saveSettings(AppSettings s) async {
    _settings = s;
    await _save();
  }

  // ---------------- المحاضرات ----------------
  @override
  Future<LectureSession> createSession(LectureSession s) async {
    final id = 'S${DateTime.now().millisecondsSinceEpoch}';
    final created = s.copyWith(id: id);
    _sessions[id] = created;
    await _save();
    return created;
  }

  @override
  Future<void> closeSession(String id) async {
    final s = _sessions[id];
    if (s == null) return;
    _sessions[id] = s.copyWith(
        active: false, endedAt: DateTime.now().millisecondsSinceEpoch);
    await _save();
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.remove(id);
    _attendance.removeWhere((k, v) => v.sessionId == id);
    await _save();
  }

  @override
  Future<LectureSession?> session(String id) async => _sessions[id];

  @override
  Future<List<LectureSession>> sessionsForCourse(String courseId) async =>
      _sessions.values.where((s) => s.courseId == courseId).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<LectureSession>> sessionsForDoctor(String doctorId) async =>
      _sessions.values.where((s) => s.doctorId == doctorId).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<LectureSession>> recentSessions({int limit = 50}) async {
    final l = _sessions.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return l.take(limit).toList();
  }

  List<AttendanceRecord> _forSession(String sid) =>
      _attendance.values.where((a) => a.sessionId == sid).toList()
        ..sort((a, b) => b.time.compareTo(a.time));

  @override
  Stream<List<AttendanceRecord>> watchAttendance(String sessionId) async* {
    yield _forSession(sessionId);
    await for (final _ in _changes.stream) {
      yield _forSession(sessionId);
    }
  }

  @override
  Future<List<AttendanceRecord>> attendanceForCourse(String courseId) async =>
      _attendance.values.where((a) => a.courseId == courseId).toList();

  @override
  Future<List<AttendanceRecord>> attendanceForStudent(String studentId) async =>
      _attendance.values.where((a) => a.studentId == studentId).toList();

  @override
  Future<List<LectureSession>> sessionsSince(int ms) async =>
      _sessions.values.where((s) => s.startedAt >= ms).toList();

  @override
  Future<List<AttendanceRecord>> attendanceSince(int ms) async =>
      _attendance.values.where((a) => a.time >= ms).toList();

  @override
  Future<void> saveStudentsBulk(List<Student> list) async {
    for (final s in list) {
      _students[s.id] = s;
    }
    await _save();
  }

  @override
  Future<void> saveCoursesBulk(List<Course> list) async {
    for (final c in list) {
      _courses[c.id] = c;
    }
    await _save();
  }

  @override
  Future<void> saveStaffBulk(List<Staff> list) async {
    for (final s in list) {
      _staff[s.id] = s;
    }
    await _save();
  }

  @override
  Future<void> markAttendance(AttendanceRecord r) async {
    if (_attendance.containsKey(r.id)) {
      throw AppException('${r.studentName} مسجّل حضوره مسبقاً');
    }
    _attendance[r.id] = r;
    await _save();
  }

  @override
  Future<void> removeAttendance(String recordId) async {
    _attendance.remove(recordId);
    await _save();
  }
}
