import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../models.dart';

/// واجهة مصدر البيانات. لها تنفيذان:
/// [FirebaseRepo] للتشغيل الحقيقي متعدد الأجهزة، و[LocalRepo] للوضع التجريبي.
abstract class Repo {
  bool get isDemo;

  // ---------- الحساب (البريد الجامعي فقط) ----------
  Future<AppUser?> restoreSession();

  /// الدخول بحساب Google الجامعي. في الوضع التجريبي يُمرَّر البريد مباشرة.
  Future<AppUser> signInWithGoogle({String? demoEmail});
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
  Future<Student?> studentByEmail(String email);
  Future<Student?> studentByNfc(String uid);
  Future<void> saveStudent(Student s);
  Future<void> deleteStudent(String id);
  Future<void> setStudentsDept(List<String> ids, String? deptId);

  /// ربط شريحة NFC بطالب (null لإلغاء الربط). يرمي خطأ إن كانت مرتبطة بغيره.
  Future<void> setStudentNfc(String studentId, String? uid);

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

/// رمز هوية الطالب المشفّر في QR وفي NFC: ALMAQAL-ST|<الرقم المعرفي>
class StudentCode {
  static String encode(Student s) => '${AppConfig.studentCodePrefix}|${s.id}';

  /// يستخرج الرقم المعرفي أو البريد من نص ممسوح.
  /// يقبل: رمز التطبيق، أو الرقم المعرفي وحده (هوية مطبوعة)، أو البريد الجامعي.
  static ({String? id, String? email}) parse(String raw) {
    final t = raw.trim();
    if (t.startsWith('${AppConfig.studentCodePrefix}|')) {
      final parts = t.split('|');
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return (id: parts[1], email: null);
      }
      return (id: null, email: null);
    }
    if (t.contains('@')) return (id: null, email: t.toLowerCase());
    if (RegExp(r'^[0-9A-Za-z\-]{4,32}$').hasMatch(t)) {
      return (id: t, email: null);
    }
    return (id: null, email: null);
  }
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
