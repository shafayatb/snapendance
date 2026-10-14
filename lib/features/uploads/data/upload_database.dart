import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<Database> openUploadDatabase({
  DatabaseFactory? factory,
  String? path,
}) async {
  final databases = factory ?? databaseFactory;
  return databases.openDatabase(
    path ?? p.join(await databases.getDatabasesPath(), 'uploads.db'),
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA busy_timeout = 5000');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final batch = db.batch()
          ..execute('''
            CREATE TABLE batches (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              status TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              submitted_at INTEGER
            )''')
          ..execute('''
            CREATE TABLE items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              batch_id INTEGER NOT NULL REFERENCES batches (id) ON DELETE CASCADE,
              file_path TEXT NOT NULL,
              file_name TEXT NOT NULL,
              size_bytes INTEGER NOT NULL,
              captured_at INTEGER NOT NULL,
              status TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              last_attempt_at INTEGER,
              uploaded_at INTEGER,
              claim_token TEXT,
              claimed_until INTEGER
            )''')
          ..execute('CREATE INDEX items_batch ON items (batch_id)')
          ..execute('CREATE INDEX items_status ON items (status)')
          ..execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )''');
        await batch.commit(noResult: true);
      },
    ),
  );
}
