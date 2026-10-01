import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/message.dart';
import '../models/mothership_report.dart';
import '../models/teaching_session.dart';

class DatabaseHelper {
  // Private constructor so only one DatabaseHelper instance exists.
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  // ============================================================
  // DATABASE ACCESS
  // ============================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'earth_exe.db');

    return openDatabase(
      path,
      version: 1,

      // SQLite foreign keys need to be explicitly enabled.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // ============================================================
  // DATABASE CREATION
  // ============================================================

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE teaching_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL,
        concept TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE message (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        sender TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,

        FOREIGN KEY (session_id)
          REFERENCES teaching_session (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE mothership_report (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL UNIQUE,
        report_content TEXT NOT NULL,
        student_correction TEXT,
        verified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,

        FOREIGN KEY (session_id)
          REFERENCES teaching_session (id)
          ON DELETE CASCADE
      )
    ''');
  }

  // ============================================================
  // DATABASE MIGRATIONS
  // ============================================================

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Future migrations will go here.
    //
    // Example:
    //
    // if (oldVersion < 2) {
    //   await db.execute(
    //     'ALTER TABLE teaching_session ADD COLUMN example TEXT',
    //   );
    // }
  }

  // ============================================================
  // TEACHING SESSION
  // ============================================================

  Future<int> createSession(TeachingSession session) async {
    final db = await database;

    final data = session.toMap();

    // SQLite generates the primary key.
    data.remove('id');

    return db.insert(
      'teaching_session',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<TeachingSession?> getSession(int sessionId) async {
    final db = await database;

    final result = await db.query(
      'teaching_session',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return TeachingSession.fromMap(result.first);
  }

  Future<List<TeachingSession>> getAllSessions() async {
    final db = await database;

    final result = await db.query(
      'teaching_session',
      orderBy: 'started_at DESC',
    );

    return result.map((row) => TeachingSession.fromMap(row)).toList();
  }

  Future<void> completeSession(int sessionId) async {
    final db = await database;

    await db.update(
      'teaching_session',
      {'status': 'completed', 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await database;

    await db.delete(
      'teaching_session',
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    // Messages and the Mothership Report belonging to this
    // session are automatically deleted because of ON DELETE CASCADE.
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Future<int> addMessage(Message message) async {
    final db = await database;

    final data = message.toMap();

    // SQLite generates the primary key.
    data.remove('id');

    return db.insert(
      'message',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Message>> getMessagesForSession(int sessionId) async {
    final db = await database;

    final result = await db.query(
      'message',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );

    return result.map((row) => Message.fromMap(row)).toList();
  }

  // ============================================================
  // MOTHERSHIP REPORT
  // ============================================================

  Future<int> createReport(MothershipReport report) async {
    final db = await database;

    final data = report.toMap();

    // SQLite generates the primary key.
    data.remove('id');

    return db.insert(
      'mothership_report',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<MothershipReport?> getReportForSession(int sessionId) async {
    final db = await database;

    final result = await db.query(
      'mothership_report',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MothershipReport.fromMap(result.first);
  }

  Future<void> correctReport({
    required int sessionId,
    required String correction,
  }) async {
    final db = await database;

    await db.update(
      'mothership_report',
      {'student_correction': correction, 'verified': 1},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> verifyReport(int sessionId) async {
    final db = await database;

    await db.update(
      'mothership_report',
      {'verified': 1},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // ============================================================
  // DATABASE UTILITIES
  // ============================================================

  Future<void> closeDatabase() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
