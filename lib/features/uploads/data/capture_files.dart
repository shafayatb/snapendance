import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CaptureFiles {
  CaptureFiles(this.directory);

  final Directory directory;

  static Future<CaptureFiles> appDocuments() async => CaptureFiles(
    Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'captures'),
    ),
  );

  static final _name = DateFormat("'IMG_'yyyyMMdd_HHmmss_SSS");

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
      return saved;
    } on FileSystemException {
      return saved;
    }
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
