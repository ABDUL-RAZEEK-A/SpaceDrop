import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../features/lobby/domain/models/lobby.dart';
import '../../features/participants/domain/models/participant.dart';
import '../../features/file_transfer/domain/models/shared_file.dart';
import '../../features/history/domain/models/transfer_history.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('beaconsync.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE lobbies (
        lobbyId TEXT PRIMARY KEY,
        lobbyName TEXT,
        hostDeviceId TEXT,
        hostDeviceName TEXT,
        hostIp TEXT,
        port INTEGER,
        createdAt INTEGER,
        status TEXT,
        maxParticipants INTEGER,
        lobbyType TEXT,
        pinEnabled INTEGER,
        pin TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE participants (
        participantId TEXT PRIMARY KEY,
        deviceId TEXT,
        deviceName TEXT,
        lobbyId TEXT,
        status TEXT,
        joinedAt INTEGER,
        permission TEXT,
        sessionToken TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE join_requests (
        requestId TEXT PRIMARY KEY,
        lobbyId TEXT,
        deviceId TEXT,
        deviceName TEXT,
        status TEXT,
        requestedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE shared_files (
        fileId TEXT PRIMARY KEY,
        lobbyId TEXT,
        fileName TEXT,
        filePath TEXT,
        fileSize INTEGER,
        checksum TEXT,
        mimeType TEXT,
        createdAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE transfer_history (
        transferId TEXT PRIMARY KEY,
        fileName TEXT,
        fileSize INTEGER,
        senderName TEXT,
        direction TEXT,
        status TEXT,
        completedAt INTEGER,
        errorReason TEXT
      )
    ''');
  }

  // Lobby Methods
  Future<void> insertLobby(Lobby lobby) async {
    final db = await instance.database;
    await db.insert(
      'lobbies',
      lobby.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Lobby?> getLobby(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'lobbies',
      where: 'lobbyId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Lobby.fromMap(maps.first);
    return null;
  }

  // Participant Methods
  Future<void> insertParticipant(Participant participant) async {
    final db = await instance.database;
    await db.insert(
      'participants',
      participant.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Participant>> getAllParticipants() async {
    final db = await instance.database;
    final result = await db.query('participants');
    return result.map((json) => Participant.fromMap(json)).toList();
  }

  // SharedFile Methods
  Future<void> insertSharedFile(SharedFile file) async {
    final db = await instance.database;
    await db.insert(
      'shared_files',
      file.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SharedFile>> getSharedFiles(String lobbyId) async {
    final db = await instance.database;
    final result = await db.query(
      'shared_files',
      where: 'lobbyId = ?',
      whereArgs: [lobbyId],
    );
    return result.map((json) => SharedFile.fromMap(json)).toList();
  }

  // Transfers Methods
  // Transfer History Methods
  Future<void> insertTransferHistory(TransferHistory history) async {
    final db = await instance.database;
    await db.insert(
      'transfer_history',
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransferHistory>> getAllTransferHistory() async {
    final db = await instance.database;
    final result = await db.query('transfer_history', orderBy: 'completedAt DESC');
    return result.map((json) => TransferHistory.fromMap(json)).toList();
  }
}
