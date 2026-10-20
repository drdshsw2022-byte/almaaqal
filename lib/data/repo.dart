import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../models.dart';

/// واجهة مصدر البيانات. لها تنفيذان:
/// [FirebaseRepo] للتشغيل الحقيقي متعدد الأجهزة، و[LocalRepo] للوضع التجريبي.
abstract class Repo {
  bool get isDemo;

  // ---------- الحساب ----------
  Future<AppUser?> restoreSession();
  Future<AppUser> signInWithId(String id, String password);
  Future<AppUser> activateAccount(String id, String newPassword);
  Future<AppUser> signInWithGoogle({String? demoEmail});
  Future<AppUser> linkGoogleWithId(
      String googleEmail, String id, String password);
  Future<void> changePassword(String oldPassword, String newPassword);
  Future<void> signOut();

  // ---------- تهيئة البيانات ----------
  Future<bool> isSeeded();
  Future<void> seedFromAssets(void Function(String msg) onProgress);

  // ---------- الهيكل ----------
  Future<List<College>> colleges();
  Future<void> saveCollege(College c);
  Future<void> deleteCollege(String id);
  Future<List<Department>> departments();
  Future<void> saveDepartment(Department d);
  Future<void> deleteDepartment(String id);
  Future<List<Course>> courses();
  Future<void> saveCourse(Course c);
  Future<void> deleteCourse(String id);

  // ---------- الطلاب ----------
  Future<List<Student>> students();
  Future<Student?> student(String id);
  Future<void> saveStudent(Student s);
  Future<void> deleteStudent(String id);
  Future<void> setStudentsDept(List<String> ids, String? deptId);

  // ---------- الكادر ----------
  Future<List<Staff>> staff();
  Future<void> saveStaff(Staff s);
  Future<void> deleteStaff(String id);

  // ---------- الإعدادات ----------
  Future<AppSettings> settings();
  Future<void> saveSettings(AppSettings s);

  // ---------- المحاضرات والحضور ----------
  Future<LectureSession> createSession(LectureSession s);
  Future<void> closeSession(String id);
  Future<void> deleteSession(String id);
  Future<LectureSession?> session(String id);
  Stream<LectureSession?> watchSession(String id);
  Future<List<LectureSession>> sessionsForCourse(String courseId);
  Future<List<LectureSession>> sessionsForDoctor(String doctorId);
  Future<List<LectureSession>> recentSessions({int limit = 50});
  Stream<List<AttendanceRecord>> watchAttendance(String sessionId);
  Future<List<AttendanceRecord>> attendanceForCourse(String courseId);
  Future<List<AttendanceRecord>> attendanceForStudent(String studentId);

  /// يسجل الحضور ويرمي [AppException] إذا كان مسجلاً مسبقاً.
  Future<void> markAttendance(AttendanceRecord r);
  Future<void> removeAttendance(String recordId);
}

/// البيانات الأولية المأخوذة من ملفي Students و Resources.
class SeedData {
  final List<College> colleges;
  final List<Department> departments;
  final List<Course> courses;
  final List<Student> students;
  SeedData(this.colleges, this.departments, this.courses, this.students);

  static Future<SeedData> load() async {
    final structure = jsonDecode(
        await rootBundle.loadString('assets/data/structure.json')) as Map;
    final courses = jsonDecode(
        await rootBundle.loadString('assets/data/courses.json')) as List;
    final students = jsonDecode(
        await rootBundle.loadString('assets/data/students.json')) as List;
    return SeedData(
      (structure['colleges'] as List)
          .map((e) => College.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      (structure['departments'] as List)
          .map((e) => Department.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      courses.map((e) => Course.fromMap(Map<String, dynamic>.from(e))).toList(),
      students
          .map((e) => Student.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

String randomSecret([int len = 32]) {
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
}

String hashPassword(String id, String password) =>
    sha256.convert(utf8.encode('almaqal::$id::$password')).toString();

/// رمز QR متجدد: ALMAQAL|sessionId|window|token
class QrToken {
  static const prefix = 'ALMAQAL';

  static int windowOf(DateTime t) =>
      t.millisecondsSinceEpoch ~/ (AppConfig.qrWindowSeconds * 1000);

  static String tokenFor(String secret, int window) =>
      sha256.convert(utf8.encode('$secret:$window')).toString().substring(0, 16);

  static String payload(LectureSession s, DateTime now) {
    final w = windowOf(now);
    return '$prefix|${s.id}|$w|${tokenFor(s.secret, w)}';
  }

  /// الثواني المتبقية قبل تجدد الرمز.
  static int secondsLeft(DateTime now) {
    final ms = AppConfig.qrWindowSeconds * 1000;
    return ((ms - now.millisecondsSinceEpoch % ms) / 1000).ceil();
  }

  static ParsedQr? parse(String raw) {
    final parts = raw.trim().split('|');
    if (parts.length != 4 || parts[0] != prefix) return null;
    final w = int.tryParse(parts[2]);
    if (w == null || parts[1].isEmpty) return null;
    return ParsedQr(parts[1], w, parts[3]);
  }

  static bool verify(LectureSession s, ParsedQr q, DateTime now) {
    if ((q.window - windowOf(now)).abs() > AppConfig.qrTolerance) return false;
    return q.token == tokenFor(s.secret, q.window);
  }
}

class ParsedQr {
  final String sessionId;
  final int window;
  final String token;
  ParsedQr(this.sessionId, this.window, this.token);
}

/// حسابات مشتركة بين التنفيذين.
class Stats {
  /// عدد المحاضرات التي تخص الطالب وعدد ما حضره، لكل مادة.
  static StudentCourseStat forStudent(Student s, List<LectureSession> sessions,
      Set<String> attendedSessionIds) {
    final applicable = sessions
        .where((x) =>
            x.appliesTo(s) &&
            (!x.active || attendedSessionIds.contains(x.id)))
        .toList();
    final present =
        applicable.where((x) => attendedSessionIds.contains(x.id)).length;
    return StudentCourseStat(s, applicable.length, present);
  }

  static List<Student> eligibleStudents(
          List<Student> all, Course c, String shift) =>
      all
          .where((s) =>
              s.stage == c.stage &&
              (s.deptId == null || s.deptId == c.deptId) &&
              (shift == 'all' || s.shift == shift))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
}
