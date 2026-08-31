import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const _databaseName = 'mwoitji.db';
  static const _databaseVersion = 1;
  static const _foodTable = 'foods';
  static const _settingsTable = 'app_settings';

  Future<Database>? _databaseFuture;

  Future<Database> get database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final databasePath = path.join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onOpen: _removeLegacySamples,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE $_foodTable (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            expiry_date INTEGER,
            purchase_date INTEGER NOT NULL,
            storage TEXT NOT NULL,
            category TEXT NOT NULL,
            manufacture_date INTEGER,
            amount_value REAL NOT NULL DEFAULT 1,
            amount_unit TEXT NOT NULL DEFAULT 'piece',
            status TEXT NOT NULL,
            completed_at INTEGER
          )
        ''');
        await database.execute('''
          CREATE TABLE $_settingsTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  Future<void> _removeLegacySamples(Database database) async {
    const cleanupKey = 'legacy_samples_removed';
    final cleaned = await database.query(
      _settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [cleanupKey],
      limit: 1,
    );
    if (cleaned.isNotEmpty) return;

    await database.transaction((transaction) async {
      await transaction.delete(
        _foodTable,
        where:
            "(id = 1 AND name = '우유') OR "
            "(id = 2 AND name = '두부') OR "
            "(id = 3 AND name = '냉동 만두')",
      );
      await transaction.insert(_settingsTable, {
        'key': cleanupKey,
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<FoodItem>> getFoods() async {
    final db = await database;
    final rows = await db.query(
      _foodTable,
      orderBy: 'expiry_date IS NULL ASC, expiry_date ASC',
    );
    return rows.map(_fromMap).toList();
  }

  Future<void> insertFood(FoodItem food) async {
    final db = await database;
    await db.insert(
      _foodTable,
      _toMap(food),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFood(FoodItem food) async {
    final db = await database;
    await db.update(
      _foodTable,
      _toMap(food),
      where: 'id = ?',
      whereArgs: [food.id],
    );
  }

  Future<void> deleteFood(int id) async {
    final db = await database;
    await db.delete(_foodTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      _settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(_settingsTable, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, Object?> _toMap(FoodItem food) => {
    'id': food.id,
    'name': food.name,
    'expiry_date': food.expiryDate?.millisecondsSinceEpoch,
    'purchase_date': food.purchaseDate.millisecondsSinceEpoch,
    'storage': food.storage.name,
    'category': food.category.name,
    'manufacture_date': food.manufactureDate?.millisecondsSinceEpoch,
    'amount_value': food.amountValue,
    'amount_unit': food.amountUnit.name,
    'status': food.status.name,
    'completed_at': food.completedAt?.millisecondsSinceEpoch,
  };

  FoodItem _fromMap(Map<String, Object?> row) => FoodItem(
    id: row['id']! as int,
    name: row['name']! as String,
    expiryDate: _dateFromDatabase(row['expiry_date']),
    purchaseDate: DateTime.fromMillisecondsSinceEpoch(
      row['purchase_date']! as int,
    ),
    storage: _enumByName(
      StorageType.values,
      row['storage']! as String,
      StorageType.fridge,
    ),
    category: _enumByName(
      FoodCategory.values,
      row['category']! as String,
      FoodCategory.other,
    ),
    manufactureDate: _dateFromDatabase(row['manufacture_date']),
    amountValue: (row['amount_value']! as num).toDouble(),
    amountUnit: _enumByName(
      FoodUnit.values,
      row['amount_unit']! as String,
      FoodUnit.piece,
    ),
    status: _enumByName(
      FoodStatus.values,
      row['status']! as String,
      FoodStatus.stored,
    ),
    completedAt: _dateFromDatabase(row['completed_at']),
  );

  DateTime? _dateFromDatabase(Object? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch(value as int);

  T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
