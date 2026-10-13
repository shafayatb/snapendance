import 'dart:async';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../domain/upload_models.dart';
import 'capture_files.dart';

/// A capture could not be stored; nothing was recorded.
class CaptureSaveException implements Exception {
  const CaptureSaveException(this.cause);

  final Object cause;

  @override
  String toString() => 'CaptureSaveException: $cause';
}

/// The upload queue: captured images, their batches, and their upload state (plan U1-U4).
///
/// The database is the source of truth. [changes] announces writes made through this instance;
/// writes from the background worker's isolate are seen by reading again.
class UploadQueueRepository {
  UploadQueueRepository(this._db, this._files, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Database _db;
  final CaptureFiles _files;
  final DateTime Function() _clock;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  /// Copies the camera's temporary file into app storage, then records it in the open batch.
  /// Throws [CaptureSaveException]; a failure leaves neither a file nor a row behind.
  Future<UploadItem> addCapture(String temporaryPath) async {
    final capturedAt = _clock();
    final File saved;
    try {
      saved = await _files.save(temporaryPath, capturedAt);
    } on Object catch (error) {
      throw CaptureSaveException(error);
    }
    try {
      final size = await saved.length();
      final item = await _db.transaction((txn) async {
        final batchId = await _openBatchId(txn) ?? await _createBatch(txn);
        final fileName = saved.uri.pathSegments.last;
        final id = await txn.insert('items', {
          'batch_id': batchId,
          'file_path': saved.path,
          'file_name': fileName,
          'size_bytes': size,
          'captured_at': capturedAt.millisecondsSinceEpoch,
          'status': ItemStatus.pending.name,
        });
        return UploadItem(
          id: id,
          batchId: batchId,
          filePath: saved.path,
          fileName: fileName,
          sizeBytes: size,
          capturedAt: capturedAt,
          status: ItemStatus.pending,
        );
      });
      _changes.add(null);
      return item;
    } on Object catch (error) {
      await _files.delete(saved.path).catchError((_) {});
      throw CaptureSaveException(error);
    }
  }

  Future<int?> _openBatchId(DatabaseExecutor db) async {
    final rows = await db.query(
      'batches',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: [BatchStatus.open.name],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id'] as int;
  }

  Future<int> _createBatch(DatabaseExecutor db) => db.insert('batches', {
    'status': BatchStatus.open.name,
    'created_at': _clock().millisecondsSinceEpoch,
  });

  Future<OpenBatch> openBatch() async {
    final batchId = await _openBatchId(_db);
    if (batchId == null) return const OpenBatch();
    final rows = await _db.query(
      'items',
      columns: ['file_path'],
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'id DESC',
    );
    if (rows.isEmpty) return const OpenBatch();
    return OpenBatch(
      count: rows.length,
      lastFilePath: rows.first['file_path'] as String,
    );
  }

  /// Freezes the open batch as queued and returns its size; 0 when there is nothing to submit.
  Future<int> submitOpenBatch() async {
    final submitted = await _db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT b.id AS id, COUNT(i.id) AS count FROM batches b '
        'JOIN items i ON i.batch_id = b.id WHERE b.status = ? GROUP BY b.id',
        [BatchStatus.open.name],
      );
      if (rows.isEmpty) return 0;
      // Guarded by status, so a second submit that read the same open batch changes nothing.
      final updated = await txn.update(
        'batches',
        {
          'status': BatchStatus.queued.name,
          'submitted_at': _clock().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [rows.single['id'], BatchStatus.open.name],
      );
      return updated == 0 ? 0 : rows.single['count'] as int;
    });
    if (submitted > 0) _changes.add(null);
    return submitted;
  }

  /// Submitted batches, newest first, each with its items in capture order.
  Future<List<QueuedBatch>> queuedBatches() async {
    final rows = await _db.rawQuery(
      'SELECT i.*, b.submitted_at AS batch_submitted_at FROM items i '
      'JOIN batches b ON b.id = i.batch_id WHERE b.status = ? '
      'ORDER BY b.id DESC, i.id ASC',
      [BatchStatus.queued.name],
    );
    final batches = <QueuedBatch>[];
    for (final row in rows) {
      final item = _item(row);
      if (batches.isEmpty || batches.last.id != item.batchId) {
        batches.add(
          QueuedBatch(
            id: item.batchId,
            submittedAt: _time(row['batch_submitted_at'])!,
            items: [],
          ),
        );
      }
      batches.last.items.add(item);
    }
    return batches;
  }

  /// Items of submitted batches that are not uploaded yet, failed ones included (plan U12).
  Future<int> pendingCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM items i JOIN batches b ON b.id = i.batch_id '
      'WHERE b.status = ? AND i.status != ?',
      [BatchStatus.queued.name, ItemStatus.uploaded.name],
    );
    return rows.single['count'] as int;
  }

  /// Startup repair (plan U3). Run before the camera can capture: a file copied but not yet
  /// recorded would look like an orphan.
  Future<void> reconcile() async {
    final rows = await _db.rawQuery(
      'SELECT i.id AS id, i.file_path AS file_path, i.status AS status, '
      'b.status AS batch_status FROM items i JOIN batches b ON b.id = i.batch_id',
    );
    var changed = false;

    final known = {for (final row in rows) row['file_path'] as String};
    for (final path in await _files.list()) {
      if (!known.contains(path)) await _files.delete(path);
    }

    for (final row in rows) {
      if (row['status'] == ItemStatus.uploaded.name) continue;
      if (await _files.exists(row['file_path'] as String)) continue;
      changed = true;
      if (row['batch_status'] == BatchStatus.open.name) {
        await _db.delete('items', where: 'id = ?', whereArgs: [row['id']]);
      } else {
        await _db.update(
          'items',
          {
            'status': ItemStatus.failed.name,
            'last_error': localFileMissingError,
            'claim_token': null,
            'claimed_until': null,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    if (changed) _changes.add(null);
  }

  UploadItem _item(Map<String, Object?> row) => UploadItem(
    id: row['id'] as int,
    batchId: row['batch_id'] as int,
    filePath: row['file_path'] as String,
    fileName: row['file_name'] as String,
    sizeBytes: row['size_bytes'] as int,
    capturedAt: _time(row['captured_at'])!,
    status: ItemStatus.values.byName(row['status'] as String),
    attempts: row['attempts'] as int,
    lastError: row['last_error'] as String?,
    lastAttemptAt: _time(row['last_attempt_at']),
    uploadedAt: _time(row['uploaded_at']),
  );

  static DateTime? _time(Object? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis as int);
}
