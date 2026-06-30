import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class DatabaseHelper {
  static const String _dbName = 'vetevB4W.db';
  static const int _dbVersion = 1;
  static Database? _database;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // tabEmpresas
    await db.execute('''
      CREATE TABLE tabEmpresas (
        ID INTEGER PRIMARY KEY,
        IDPlataforma INTEGER,
        nome TEXT,
        conection TEXT
      )
    ''');

    // tabSubEmpresas
    await db.execute('''
      CREATE TABLE tabSubEmpresas (
        ID INTEGER PRIMARY KEY,
        idEmpresa INTEGER,
        nome TEXT
      )
    ''');

    // tabTypeClaims
    await db.execute('''
      CREATE TABLE tabTypeClaims (
        ID INTEGER PRIMARY KEY,
        IDPlataforma INTEGER,
        nome TEXT
      )
    ''');

    // tabLines
    await db.execute('''
      CREATE TABLE tabLines (
        ID INTEGER PRIMARY KEY,
        IDPlataforma INTEGER,
        nomeabrev TEXT,
        nome TEXT
      )
    ''');

    // TabSchedules
    await db.execute('''
      CREATE TABLE TabSchedules (
        ID INTEGER PRIMARY KEY,
        LineID INTEGER,
        Schedule TEXT,
        Destino TEXT,
        Monday INTEGER,
        Tuesday INTEGER,
        Wednesday INTEGER,
        Thursday INTEGER,
        Friday INTEGER,
        Saturday INTEGER,
        Sunday INTEGER,
        Holydays INTEGER,
        Type INTEGER,
        ShowNotifications INTEGER DEFAULT 0,
        ShowLastTimes INTEGER DEFAULT 0
      )
    ''');

    // tabProximosSCHEDULES
    await db.execute('''
      CREATE TABLE tabProximosSCHEDULES (
        ID INTEGER PRIMARY KEY,
        Line TEXT,
        Schedule TEXT,
        Destino TEXT,
        Viatura INTEGER,
        Tempo INTEGER,
        Tipo INTEGER,
        IdViatura INTEGER
      )
    ''');

    // tabCourses
    await db.execute('''
      CREATE TABLE tabCourses (
        ID INTEGER PRIMARY KEY,
        OrderStop INTEGER,
        ScheduleID INTEGER,
        LineID INTEGER,
        Schedule TEXT,
        BusStop TEXT,
        CoordX TEXT,
        CoordY TEXT,
        DIRECTION INTEGER,
        SourceID INTEGER
      )
    ''');

    await _insertInitialData(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS tabEmpresas');
    await db.execute('DROP TABLE IF EXISTS tabSubEmpresas');
    await db.execute('DROP TABLE IF EXISTS tabTypeClaims');
    await db.execute('DROP TABLE IF EXISTS tabLines');
    await db.execute('DROP TABLE IF EXISTS TabSchedules');
    await db.execute('DROP TABLE IF EXISTS tabProximosSCHEDULES');
    await db.execute('DROP TABLE IF EXISTS tabCourses');
    await _onCreate(db, newVersion);
  }

  static Future<void> _insertInitialData(Database db) async {
    // Empresas
    await db.insert('tabEmpresas', {'IDPlataforma': 46, 'nome': 'HEINEKEN', 'conection': 'connectionHNK'});
    await db.insert('tabEmpresas', {'IDPlataforma': 47, 'nome': 'SIEMENS GAMESA', 'conection': 'connectionSMG'});

    // Subempresas Heineken
    for (final sub in ['ADECCO', 'GOOD JOB', 'ESUMÉDICA', 'ZINCOMETAL', 'EGEO', 'SOC. CENTRAL DE CERVEJAS', 'XPO', 'SINAL MAIS', 'DIGIBÉRIA', 'ENGIE']) {
      await db.insert('tabSubEmpresas', {'idEmpresa': 1, 'nome': sub});
    }
    // Subempresas Siemens
    for (final sub in ['SIEMENS GAMESA', 'VETEV']) {
      await db.insert('tabSubEmpresas', {'idEmpresa': 2, 'nome': sub});
    }
  }

  // ===========================
  // EMPRESAS
  // ===========================
  static Future<List<Map<String, dynamic>>> getEmpresas() async {
    final db = await database;
    return db.rawQuery('SELECT * FROM tabEmpresas');
  }

  static Future<List<Map<String, dynamic>>> getSubEmpresas(String empresaNome) async {
    final db = await database;
    final empresa = await db.rawQuery(
      'SELECT ID FROM tabEmpresas WHERE nome = ?',
      [empresaNome],
    );
    if (empresa.isEmpty) return [];
    final empresaId = empresa.first['ID'];
    return db.rawQuery(
      'SELECT * FROM tabSubEmpresas WHERE idEmpresa = ?',
      [empresaId],
    );
  }

  // ===========================
  // LINHAS
  // ===========================
  static Future<List<Map<String, dynamic>>> getLinhas() async {
    final db = await database;
    return db.rawQuery('SELECT * FROM tabLines ORDER BY ID');
  }

  static Future<String> getNomeLinha(int idLinha) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT nome FROM tabLines WHERE IDPlataforma = ?',
      [idLinha],
    );
    if (result.isEmpty) return '';
    return result.first['nome'] as String? ?? '';
  }

  static Future<int> getNumeroParagens(int idLinha) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT SourceID) as total FROM tabCourses WHERE LineID = ?',
      [idLinha],
    );
    return result.first['total'] as int? ?? 0;
  }

  // ===========================
  // HORÁRIOS
  // ===========================
  static Future<List<Map<String, dynamic>>> getHorarios(int idLinha, int type) async {
    final db = await database;
    return db.rawQuery(
      'SELECT * FROM TabSchedules WHERE LineID = ? AND Type = ? ORDER BY Schedule',
      [idLinha, type],
    );
  }

  // ===========================
  // PERCURSOS
  // ===========================
  static Future<List<Map<String, dynamic>>> getRoute(int lineId, int scheduleId, int direction) async {
    final db = await database;
    return db.rawQuery(
      'SELECT CoordX, CoordY, BusStop, SourceID FROM tabCourses WHERE LineID = ? AND ScheduleID = ? AND DIRECTION = ? ORDER BY OrderStop ASC',
      [lineId, scheduleId, direction],
    );
  }

  static Future<double> getCoordX(int lineId, int direction, int busStop) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT CoordX FROM tabCourses WHERE LineID = ? AND Direction = ? AND SourceID = ?',
      [lineId, direction, busStop],
    );
    if (result.isEmpty) return 0.0;
    return double.tryParse(result.first['CoordX'].toString()) ?? 0.0;
  }

  static Future<double> getCoordY(int lineId, int direction, int busStop) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT CoordY FROM tabCourses WHERE LineID = ? AND Direction = ? AND SourceID = ?',
      [lineId, direction, busStop],
    );
    if (result.isEmpty) return 0.0;
    return double.tryParse(result.first['CoordY'].toString()) ?? 0.0;
  }

  // ===========================
  // INSERÇÃO DE DADOS DO SERVIDOR
  // ===========================
  static Future<void> clearAndInsertLinhas(List<Map<String, dynamic>> linhas) async {
    final db = await database;
    await db.delete('tabLines');
    for (final linha in linhas) {
      await db.insert('tabLines', linha, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> clearAndInsertSchedules(List<Map<String, dynamic>> schedules) async {
    final db = await database;
    await db.delete('TabSchedules');
    for (final schedule in schedules) {
      await db.insert('TabSchedules', schedule, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> clearAndInsertCourses(List<Map<String, dynamic>> courses) async {
    final db = await database;
    await db.delete('tabCourses');
    for (final course in courses) {
      await db.insert('tabCourses', course, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> clearAndInsertTypeClaims(List<Map<String, dynamic>> typeClaims) async {
    final db = await database;
    await db.delete('tabTypeClaims');
    for (final tc in typeClaims) {
      await db.insert('tabTypeClaims', tc, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> getTypeClaims() async {
    final db = await database;
    return db.rawQuery('SELECT * FROM tabTypeClaims ORDER BY ID');
  }

  static Future<void> clearProximosSchedules() async {
    final db = await database;
    await db.delete('tabProximosSCHEDULES');
  }

  static Future<void> insertProximosSchedules(List<Map<String, dynamic>> items) async {
    final db = await database;
    for (final item in items) {
      await db.insert('tabProximosSCHEDULES', item, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> getProximosSchedules() async {
    final db = await database;
    return db.rawQuery('SELECT * FROM tabProximosSCHEDULES ORDER BY Schedule');
  }
}
