import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'student.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'class_attendance.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students(
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            indexNo   TEXT NOT NULL UNIQUE,
            fullName  TEXT NOT NULL,
            programme TEXT NOT NULL,
            level     INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE attendance(
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId INTEGER NOT NULL,
            date      TEXT NOT NULL,
            status    TEXT NOT NULL,
            UNIQUE(studentId, date),
            FOREIGN KEY(studentId) REFERENCES students(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<int> insertStudent(Student s) async {
    final db = await database;
    return db.insert('students', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Student>> allStudents() async {
    final db = await database;
    final rows = await db.query('students', orderBy: 'fullName ASC');
    return rows.map(Student.fromMap).toList();
  }

  Future<List<Student>> searchStudents(String term) async {
    final db = await database;
    final rows = await db.query(
      'students',
      where: 'fullName LIKE ?',
      whereArgs: ['%$term%'],
      orderBy: 'fullName ASC',
    );
    return rows.map(Student.fromMap).toList();
  }

  Future<int> updateStudent(Student s) async {
    final db = await database;
    return db.update('students', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> attendanceStatus(int studentId, String date) async {
    final db = await database;
    final rows = await db.query(
      'attendance',
      columns: ['status'],
      where: 'studentId = ? AND date = ?',
      whereArgs: [studentId, date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String;
  }

  Future<Map<int, String>> attendanceForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
    return {
      for (final row in rows)
        row['studentId'] as int: row['status'] as String,
    };
  }

  Future<void> setAttendance(int studentId, String date, String status) async {
    final db = await database;
    await db.insert(
      'attendance',
      {'studentId': studentId, 'date': date, 'status': status},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> levelStatistics() async {
    final db = await database;
    return db.rawQuery(
      'SELECT level, COUNT(*) AS count FROM students GROUP BY level ORDER BY level ASC',
    );
  }

  Future<Map<String, int>> todayAttendanceSummary(String date) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS count FROM attendance WHERE date = ? GROUP BY status',
      [date],
    );
    return {
      for (final row in rows)
        row['status'] as String: row['count'] as int,
    };
  }
}
