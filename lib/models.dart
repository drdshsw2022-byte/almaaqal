int asInt(dynamic v, [int def = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? def;
}

double asDouble(dynamic v, [double def = 0]) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? def;
}

String? asStrOrNull(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

List<String> asStrList(dynamic v) =>
    v is List ? v.map((e) => '$e').toList() : <String>[];

enum Role { admin, doctor, student }

const stageNames = {
  1: 'المرحلة الأولى',
  2: 'المرحلة الثانية',
  3: 'المرحلة الثالثة',
  4: 'المرحلة الرابعة',
  5: 'المرحلة الخامسة',
};

String stageName(int s) => stageNames[s] ?? 'المرحلة $s';

const shiftNames = {'morning': 'صباحي', 'evening': 'مسائي', 'all': 'الكل'};
String shiftName(String s) => shiftNames[s] ?? s;
String termName(int t) => t == 1 ? 'الفصل الأول' : 'الفصل الثاني';

class College {
  final String id;
  final String name;
  College({required this.id, required this.name});
  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory College.fromMap(Map<String, dynamic> m) =>
      College(id: '${m['id']}', name: '${m['name'] ?? ''}');
}

class Department {
  final String id;
  final String name;
  final String collegeId;
  Department({required this.id, required this.name, required this.collegeId});
  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'collegeId': collegeId};
  factory Department.fromMap(Map<String, dynamic> m) => Department(
      id: '${m['id']}',
      name: '${m['name'] ?? ''}',
      collegeId: '${m['collegeId'] ?? ''}');
}

class Course {
  final String id;
  final String deptId;
  final int semester; // 1..8
  final int stage; // 1..4
  final int term; // 1 أو 2
  final String code;
  final String nameAr;
  final String nameEn;
  final int ects;

  Course({
    required this.id,
    required this.deptId,
    required this.semester,
    required this.stage,
    required this.term,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.ects,
  });

  static String makeId(String deptId, int semester, String code) =>
      '$deptId|$semester|$code';

  Map<String, dynamic> toMap() => {
        'id': id,
        'deptId': deptId,
        'semester': semester,
        'stage': stage,
        'term': term,
        'code': code,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'ects': ects,
      };

  factory Course.fromMap(Map<String, dynamic> m) {
    final sem = asInt(m['semester'], 1);
    return Course(
      id: '${m['id']}',
      deptId: '${m['deptId'] ?? ''}',
      semester: sem,
      stage: asInt(m['stage'], (sem + 1) ~/ 2),
      term: asInt(m['term'], sem.isOdd ? 1 : 2),
      code: '${m['code'] ?? ''}',
      nameAr: '${m['nameAr'] ?? ''}',
      nameEn: '${m['nameEn'] ?? ''}',
      ects: asInt(m['ects']),
    );
  }
}

class Student {
  final String id; // الرقم المعرفي
  final String name;
  final int stage;
  final String shift; // morning | evening
  final String? deptId;
  final String? email; // حساب Google المرتبط
  final bool activated;

  Student({
    required this.id,
    required this.name,
    required this.stage,
    required this.shift,
    this.deptId,
    this.email,
    this.activated = false,
  });

  Student copyWith({
    String? name,
    int? stage,
    String? shift,
    String? deptId,
    bool clearDept = false,
    String? email,
    bool clearEmail = false,
    bool? activated,
  }) =>
      Student(
        id: id,
        name: name ?? this.name,
        stage: stage ?? this.stage,
        shift: shift ?? this.shift,
        deptId: clearDept ? null : (deptId ?? this.deptId),
        email: clearEmail ? null : (email ?? this.email),
        activated: activated ?? this.activated,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'stage': stage,
        'shift': shift,
        'deptId': deptId,
        'email': email,
        'activated': activated,
      };

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        id: '${m['id']}',
        name: '${m['name'] ?? ''}',
        stage: asInt(m['stage'], 1),
        shift: '${m['shift'] ?? 'morning'}',
        deptId: asStrOrNull(m['deptId']),
        email: asStrOrNull(m['email'])?.toLowerCase(),
        activated: m['activated'] == true,
      );
}

class Staff {
  final String id; // الرقم الوظيفي
  final String name;
  final String role; // admin | doctor
  final String? email;
  final String? deptId;
  final List<String> courseIds;
  final bool activated;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.deptId,
    this.courseIds = const [],
    this.activated = false,
  });

  bool get isAdmin => role == 'admin';

  Staff copyWith({
    String? name,
    String? role,
    String? email,
    bool clearEmail = false,
    String? deptId,
    List<String>? courseIds,
    bool? activated,
  }) =>
      Staff(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        email: clearEmail ? null : (email ?? this.email),
        deptId: deptId ?? this.deptId,
        courseIds: courseIds ?? this.courseIds,
        activated: activated ?? this.activated,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'email': email,
        'deptId': deptId,
        'courseIds': courseIds,
        'activated': activated,
      };

  factory Staff.fromMap(Map<String, dynamic> m) => Staff(
        id: '${m['id']}',
        name: '${m['name'] ?? ''}',
        role: '${m['role'] ?? 'doctor'}',
        email: asStrOrNull(m['email'])?.toLowerCase(),
        deptId: asStrOrNull(m['deptId']),
        courseIds: asStrList(m['courseIds']),
        activated: m['activated'] == true,
      );
}

class AppUser {
  final Role role;
  final Student? student;
  final Staff? staff;
  AppUser.student(Student s)
      : role = Role.student,
        student = s,
        staff = null;
  AppUser.staff(Staff s)
      : role = s.isAdmin ? Role.admin : Role.doctor,
        staff = s,
        student = null;

  String get id => student?.id ?? staff!.id;
  String get name => student?.name ?? staff!.name;
  String? get email => student?.email ?? staff?.email;
}

class LectureSession {
  final String id;
  final String courseId;
  final String courseName;
  final String deptId;
  final int stage;
  final String shift; // all | morning | evening
  final String doctorId;
  final String doctorName;
  final String title;
  final String secret;
  final int startedAt; // ms
  final int? endedAt;
  final bool active;

  LectureSession({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.deptId,
    required this.stage,
    required this.shift,
    required this.doctorId,
    required this.doctorName,
    required this.title,
    required this.secret,
    required this.startedAt,
    this.endedAt,
    this.active = true,
  });

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(startedAt);

  LectureSession copyWith({String? id, bool? active, int? endedAt}) =>
      LectureSession(
        id: id ?? this.id,
        courseId: courseId,
        courseName: courseName,
        deptId: deptId,
        stage: stage,
        shift: shift,
        doctorId: doctorId,
        doctorName: doctorName,
        title: title,
        secret: secret,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        active: active ?? this.active,
      );

  /// هل يخص هذا الطالب هذه المحاضرة؟
  bool appliesTo(Student s) =>
      s.stage == stage &&
      (shift == 'all' || shift == s.shift) &&
      (s.deptId == null || s.deptId == deptId);

  Map<String, dynamic> toMap() => {
        'id': id,
        'courseId': courseId,
        'courseName': courseName,
        'deptId': deptId,
        'stage': stage,
        'shift': shift,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'title': title,
        'secret': secret,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'active': active,
      };

  factory LectureSession.fromMap(Map<String, dynamic> m) => LectureSession(
        id: '${m['id']}',
        courseId: '${m['courseId'] ?? ''}',
        courseName: '${m['courseName'] ?? ''}',
        deptId: '${m['deptId'] ?? ''}',
        stage: asInt(m['stage'], 1),
        shift: '${m['shift'] ?? 'all'}',
        doctorId: '${m['doctorId'] ?? ''}',
        doctorName: '${m['doctorName'] ?? ''}',
        title: '${m['title'] ?? ''}',
        secret: '${m['secret'] ?? ''}',
        startedAt: asInt(m['startedAt']),
        endedAt: m['endedAt'] == null ? null : asInt(m['endedAt']),
        active: m['active'] == true,
      );
}

class AttendanceRecord {
  final String id; // sessionId_studentId
  final String sessionId;
  final String courseId;
  final String studentId;
  final String studentName;
  final int time;
  final String method; // qr | manual

  AttendanceRecord({
    required this.sessionId,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.time,
    required this.method,
  }) : id = '${sessionId}_$studentId';

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(time);

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'courseId': courseId,
        'studentId': studentId,
        'studentName': studentName,
        'time': time,
        'method': method,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> m) => AttendanceRecord(
        sessionId: '${m['sessionId'] ?? ''}',
        courseId: '${m['courseId'] ?? ''}',
        studentId: '${m['studentId'] ?? ''}',
        studentName: '${m['studentName'] ?? ''}',
        time: asInt(m['time']),
        method: '${m['method'] ?? 'qr'}',
      );
}

class AppSettings {
  final int currentTerm;
  final double warnPercent;
  final double failPercent;

  const AppSettings({
    this.currentTerm = 1,
    this.warnPercent = 10,
    this.failPercent = 15,
  });

  Map<String, dynamic> toMap() => {
        'currentTerm': currentTerm,
        'warnPercent': warnPercent,
        'failPercent': failPercent,
      };

  factory AppSettings.fromMap(Map<String, dynamic>? m) => m == null
      ? const AppSettings()
      : AppSettings(
          currentTerm: asInt(m['currentTerm'], 1),
          warnPercent: asDouble(m['warnPercent'], 10),
          failPercent: asDouble(m['failPercent'], 15),
        );
}

/// ملخص حضور طالب في مادة.
class StudentCourseStat {
  final Student student;
  final int total;
  final int present;
  StudentCourseStat(this.student, this.total, this.present);
  int get absent => total - present;
  double get absencePercent => total == 0 ? 0 : absent * 100 / total;
  double get attendancePercent => total == 0 ? 100 : present * 100 / total;
}

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

/// يُرمى عند تسجيل الدخول بحساب Google غير مرتبط بأي رقم جامعي.
class NotLinkedException extends AppException {
  final String email;
  NotLinkedException(this.email)
      : super('حساب Google ($email) غير مرتبط برقم جامعي بعد');
}
