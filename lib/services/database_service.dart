import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/expense_models.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String dbName = 'takapulse_vault.db';
  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE modules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            subtitle TEXT,
            type TEXT NOT NULL,
            is_fixed INTEGER NOT NULL DEFAULT 0,
            default_amount REAL,
            badge_text TEXT,
            icon_key TEXT,
            accent_color INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            module_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            channel_or_note TEXT,
            category_label TEXT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            is_fixed_entry INTEGER NOT NULL DEFAULT 0,
            icon_key TEXT,
            accent_color INTEGER,
            timestamp TEXT NOT NULL,
            billing_month TEXT NOT NULL,
            FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_tx_month ON transactions(billing_month)',
        );

        await _seedDefaultModules(db);
      },
    );
  }

  Future<void> _seedDefaultModules(Database db) async {
    final defaults = [
      const ExpenseModule(
        name: 'Monthly Salary',
        subtitle: 'Regular Income',
        type: ModuleType.income,
        isFixed: true,
        defaultAmount: 120000,
        badgeText: 'Active',
        iconKey: 'work',
        accentColorValue: 0xFF47F3BB,
      ),
      const ExpenseModule(
        name: 'Electricity Bill',
        subtitle: 'DESCO Prepaid',
        type: ModuleType.expense,
        isFixed: false,
        defaultAmount: 3240,
        badgeText: 'Monthly Bill',
        iconKey: 'bolt',
        accentColorValue: 0xFF00EEFC,
      ),
      const ExpenseModule(
        name: 'Tuition Fee',
        subtitle: 'Semester installment',
        type: ModuleType.expense,
        isFixed: true,
        defaultAmount: 5000,
        badgeText: 'Fixed Monthly',
        iconKey: 'school',
        accentColorValue: 0xFF7DF4FF,
      ),
      const ExpenseModule(
        name: 'Daily Spending',
        subtitle: 'Snacks, lunch & commute',
        type: ModuleType.expense,
        isFixed: false,
        defaultAmount: null,
        badgeText: 'Variable',
        iconKey: 'local_mall',
        accentColorValue: 0xFFFFCCCF,
      ),
    ];

    for (final m in defaults) {
      await db.insert('modules', m.toMap());
    }
  }

  // --- Module Operations ---

  Future<List<ExpenseModule>> getModules() async {
    final db = await database;
    final rows = await db.query('modules', orderBy: 'id ASC');
    return rows.map(ExpenseModule.fromMap).toList();
  }

  Future<int> insertModule(ExpenseModule module) async {
    final db = await database;
    return await db.insert('modules', module.toMap());
  }

  Future<void> deleteModule(int id) async {
    final db = await database;
    await db.delete('modules', where: 'id = ?', whereArgs: [id]);
  }

  // --- Transaction Operations ---

  Future<int> logTransaction({
    required ExpenseModule module,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final db = await database;
    final txDate = date ?? DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(txDate);

    final tx = ExpenseTransaction(
      moduleId: module.id ?? 0,
      title: module.name,
      channelOrNote: (note != null && note.trim().isNotEmpty)
          ? note.trim()
          : (module.subtitle.isNotEmpty ? module.subtitle : 'Direct Entry'),
      categoryLabel: module.type == ModuleType.income ? 'Inflow' : module.name,
      type: module.type,
      amount: amount,
      isFixedEntry: module.isFixed,
      iconKey: module.iconKey,
      accentColorValue: module.accentColorValue,
      timestamp: txDate,
      billingMonth: monthKey,
    );

    // Update module's last/default amount reference for variable bills
    if (!module.isFixed && module.id != null) {
      await db.update(
        'modules',
        {'default_amount': amount},
        where: 'id = ?',
        whereArgs: [module.id],
      );
    }

    return await db.insert('transactions', tx.toMap());
  }

  Future<List<ExpenseTransaction>> getTransactionsForMonth(
    String billingMonth, {
    int? limit,
  }) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'billing_month = ?',
      whereArgs: [billingMonth],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(ExpenseTransaction.fromMap).toList();
  }

  Future<MonthlySummary> getMonthlySummary(String billingMonth) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT type, SUM(amount) as total
      FROM transactions
      WHERE billing_month = ?
      GROUP BY type
    ''', [billingMonth]);

    double inflow = 0;
    double outflow = 0;
    for (final row in rows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      if (row['type'] == 'INCOME') {
        inflow = total;
      } else {
        outflow = total;
      }
    }
    return MonthlySummary(totalInflow: inflow, totalOutflow: outflow);
  }

  Future<double> getTodaySpendingForModule(int moduleId) async {
    final db = await database;
    final todayPrefix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rows = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE module_id = ? AND timestamp LIKE ?
    ''', [moduleId, '$todayPrefix%']);

    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}