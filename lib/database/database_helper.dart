import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
  static Future<Database>? _opening;

  /// Debug-only log line. Filter the console for "[DB]" to follow persistence.
  static void _log(String message) {
    if (kDebugMode) debugPrint('[DB] $message');
  }

  // ============================================================
  // DATABASE ACCESS
  // ============================================================

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final opening = _opening ??= _initializeDatabase();

    try {
      final db = await opening;
      _database = db;
      return db;
    } catch (_) {
      // Allow a retry on the next call.
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'earth_exe.db');

    _log('opening database at $path');

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
    _log('creating tables (first launch)');

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
  }

  // ============================================================
  // TEACHING SESSION
  // ============================================================

  Future<int> createSession(TeachingSession session) async {
    final db = await database;

    final data = session.toMap();

    // SQLite generates the primary key.
    data.remove('id');

    final id = await db.insert(
      'teaching_session',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    _log(
      'INSERT session id=$id domain=${session.domain} concept=${session.concept}',
    );
    return id;
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

  /// Newest first.
  Future<List<TeachingSession>> getAllSessions() async {
    final db = await database;

    final result = await db.query('teaching_session', orderBy: 'id DESC');

    _log('LOAD sessions count=${result.length}');
    return result.map((row) => TeachingSession.fromMap(row)).toList();
  }

  /// The most recent session of every domain that has one.
  Future<Map<String, TeachingSession>> getLatestSessionPerDomain() async {
    final sessions = await getAllSessions(); // newest first
    final latest = <String, TeachingSession>{};

    for (final session in sessions) {
      latest.putIfAbsent(session.domain, () => session);
    }

    return latest;
  }

  Future<void> completeSession(int sessionId) async {
    final db = await database;

    final rows = await db.update(
      'teaching_session',
      {'status': 'completed', 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    _log('UPDATE session id=$sessionId status=completed rows=$rows');

    if (rows == 0) {
      throw StateError('completeSession: no session with id $sessionId');
    }
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

  /// Removes "active" sessions in which the student never answered
  /// (leftovers from opening a domain and leaving again).
  Future<int> purgeEmptySessions() async {
    final db = await database;

    final removed = await db.delete(
      'teaching_session',
      where:
          "status = 'active' AND id NOT IN "
          "(SELECT session_id FROM message WHERE sender = 'HUMAN')",
    );

    _log('PURGE empty active sessions removed=$removed');
    return removed;
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Future<int> addMessage(Message message) async {
    final db = await database;

    final data = message.toMap();

    // SQLite generates the primary key.
    data.remove('id');

    final id = await db.insert(
      'message',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    _log(
      'INSERT message id=$id session=${message.sessionId} sender=${message.sender}',
    );
    return id;
  }

  /// Oldest first. Ordered by id (insertion order) so ties can never reorder a chat.
  Future<List<Message>> getMessagesForSession(int sessionId) async {
    final db = await database;

    final result = await db.query(
      'message',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );

    _log('LOAD messages session=$sessionId count=${result.length}');
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

    final id = await db.insert(
      'mothership_report',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    _log('INSERT report id=$id session=${report.sessionId}');
    return id;
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
      _log('LOAD report session=$sessionId -> none');
      return null;
    }

    final report = MothershipReport.fromMap(result.first);
    _log('LOAD report session=$sessionId -> found verified=${report.verified}');
    return report;
  }

  Future<void> correctReport({
    required int sessionId,
    required String correction,
  }) async {
    final db = await database;

    final rows = await db.update(
      'mothership_report',
      {'student_correction': correction, 'verified': 1},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    _log('UPDATE report session=$sessionId verified=1 rows=$rows');

    if (rows == 0) {
      throw StateError('correctReport: no report for session $sessionId');
    }
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

  /// Debug-only: prints one line per saved session.
  Future<void> debugDump() async {
    if (!kDebugMode) return;

    try {
      final db = await database;

      final rows = await db.rawQuery('''
        SELECT
          s.id AS id,
          s.domain AS domain,
          s.concept AS concept,
          s.status AS status,
          (SELECT COUNT(*) FROM message m WHERE m.session_id = s.id) AS messages,
          (SELECT COUNT(*) FROM mothership_report r WHERE r.session_id = s.id) AS has_report,
          (SELECT r.verified FROM mothership_report r WHERE r.session_id = s.id) AS verified
        FROM teaching_session s
        ORDER BY s.id
      ''');

      _log('---- DATABASE DUMP: ${rows.length} session(s) ----');
      for (final r in rows) {
        _log(
          'session #${r['id']} | ${r['domain']} | ${r['concept']} | '
          '${r['status']} | messages=${r['messages']} | '
          'report=${r['has_report'] == 1 ? 'yes' : 'no'} | '
          'verified=${r['verified'] ?? '-'}',
        );
      }
      _log('---- END DUMP ----');
    } catch (e, st) {
      debugPrint('[DB][ERROR] dump failed: $e\n$st');
    }
  }

  Future<void> closeDatabase() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
      _opening = null;
    }
  }
}
