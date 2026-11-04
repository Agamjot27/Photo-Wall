import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Stores compressed image bytes in an app-private cache directory.
class DiskImageCache {
  DiskImageCache(
    this.directory, {
    this.maxBytes = 100 * 1024 * 1024,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Directory directory;
  final int maxBytes;
  final DateTime Function() _clock;
  final Map<String, _Entry> _entries = {};
  Future<void> _tail = Future<void>.value();
  bool _ready = false;
  int _bytes = 0;

  int get sizeBytes => _bytes;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> initialize() => _serialized(() async {
    if (_ready) return;
    await directory.create(recursive: true);
    final index = File('${directory.path}${Platform.pathSeparator}index.json');
    final backup = File('${directory.path}${Platform.pathSeparator}index.bak');
    Map<String, dynamic> decoded = {};
    for (final source in [index, backup]) {
      try {
        if (await source.exists()) {
          final value = jsonDecode(await source.readAsString());
          if (value is Map<String, dynamic> && value['version'] == 1) {
            decoded = value;
            break;
          }
        }
      } catch (_) {
        // Recover by scanning and removing entries absent from a valid index.
      }
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is Map<String, dynamic>) {
      for (final pair in rawEntries.entries) {
        final value = pair.value;
        if (value is! Map<String, dynamic>) continue;
        final length = value['length'];
        final accessed = value['accessed'];
        if (length is! int || accessed is! int || length < 0) continue;
        final file = _fileFor(pair.key);
        if (await file.exists()) {
          final actual = await file.length();
          if (actual == length) {
            _entries[pair.key] = _Entry(actual, accessed);
            _bytes += actual;
          }
        }
      }
    }
    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (name.endsWith('.img') &&
          !_entries.containsKey(name.substring(0, name.length - 4))) {
        await file.delete();
      } else if (name.endsWith('.part')) {
        await file.delete();
      }
    }
    await _trim();
    await _persist();
    _ready = true;
  });

  String keyFor(String url) => sha256.convert(utf8.encode(url)).toString();

  File _fileFor(String key) =>
      File('${directory.path}${Platform.pathSeparator}$key.img');

  Future<Uint8List?> read(String url) => _serialized(() async {
    _requireReady();
    final key = keyFor(url);
    final entry = _entries[key];
    if (entry == null) return null;
    try {
      final bytes = await _fileFor(key).readAsBytes();
      if (bytes.length != entry.length) {
        await _remove(key);
        await _persist();
        return null;
      }
      entry.accessed = _clock().microsecondsSinceEpoch;
      await _persist();
      return bytes;
    } on FileSystemException {
      await _remove(key);
      await _persist();
      return null;
    }
  });

  /// Returns false when the image is too large for the configured cache.
  Future<bool> write(String url, Uint8List bytes) => _serialized(() async {
    _requireReady();
    if (bytes.length > maxBytes) return false;
    final key = keyFor(url);
    final file = _fileFor(key);
    final part = File('${file.path}.part');
    try {
      await part.writeAsBytes(bytes, flush: true);
      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      final previous = _entries[key];
      if (previous != null) _bytes -= previous.length;
      _entries[key] = _Entry(bytes.length, _clock().microsecondsSinceEpoch);
      _bytes += bytes.length;
      await _trim();
      await _persist();
      return true;
    } finally {
      if (await part.exists()) await part.delete();
    }
  });

  Future<void> invalidate(String url) => _serialized(() async {
    _requireReady();
    await _remove(keyFor(url));
    await _persist();
  });

  Future<void> _remove(String key) async {
    final entry = _entries.remove(key);
    if (entry != null) _bytes -= entry.length;
    final file = _fileFor(key);
    if (await file.exists()) await file.delete();
  }

  Future<void> _trim() async {
    final oldest =
        _entries.keys.toList()..sort((a, b) {
          final order = _entries[a]!.accessed.compareTo(_entries[b]!.accessed);
          return order != 0 ? order : a.compareTo(b);
        });
    for (final key in oldest) {
      if (_bytes <= maxBytes) break;
      await _remove(key);
    }
  }

  Future<void> _persist() async {
    final index = File('${directory.path}${Platform.pathSeparator}index.json');
    final backup = File('${directory.path}${Platform.pathSeparator}index.bak');
    final part = File('${directory.path}${Platform.pathSeparator}index.part');
    final entries = {
      for (final pair in _entries.entries)
        pair.key: {
          'length': pair.value.length,
          'accessed': pair.value.accessed,
        },
    };
    await part.writeAsString(
      jsonEncode({'version': 1, 'entries': entries}),
      flush: true,
    );
    if (await backup.exists()) await backup.delete();
    if (await index.exists()) await index.rename(backup.path);
    try {
      await part.rename(index.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await backup.exists() && !await index.exists()) {
        await backup.rename(index.path);
      }
      rethrow;
    }
  }

  void _requireReady() {
    if (!_ready) {
      throw StateError('DiskImageCache.initialize must finish first');
    }
  }
}

class _Entry {
  _Entry(this.length, this.accessed);
  final int length;
  int accessed;
}
