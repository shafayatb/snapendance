import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-owned image storage (plan U2): not the cache, so Android does not clear it.
class CaptureFiles {
  CaptureFiles(this.directory);

  final Directory directory;

  static Future<CaptureFiles> appDocuments() async => CaptureFiles(
    Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'captures'),
    ),
  );

  static final _name = DateFormat("'IMG_'yyyyMMdd_HHmmss_SSS");

  /// Copies the camera's temporary file in, then deletes the temporary file.
  Future<File> save(String temporaryPath, DateTime capturedAt) async {
    await directory.create(recursive: true);
    final base = _name.format(capturedAt);
    var target = File(p.join(directory.path, '$base.jpg'));
    for (var n = 1; await target.exists(); n++) {
      target = File(p.join(directory.path, '${base}_$n.jpg'));
    }
    final saved = await File(temporaryPath).copy(target.path);
    try {
      await File(temporaryPath).delete();
    } on FileSystemException {
      // The copy is saved; a leftover temporary file is the system's to clean.
    }
    return saved;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<List<String>> list() async {
    if (!await directory.exists()) return const [];
    return directory
        .list()
        .where((entry) => entry is File)
        .map((entry) => entry.path)
        .toList();
  }
}
