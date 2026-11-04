import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('photo-wall-cache-test-');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Uint8List bytes(int count, int value) =>
      Uint8List.fromList(List.filled(count, value));

  test('persists compressed bytes and a valid index across restart', () async {
    final cache = DiskImageCache(directory, maxBytes: 100);
    await cache.initialize();
    await cache.write('https://photos.test/a', bytes(7, 1));
    expect(cache.sizeBytes, 7);
    final reopened = DiskImageCache(directory, maxBytes: 100);
    await reopened.initialize();
    expect(await reopened.read('https://photos.test/a'), bytes(7, 1));
    expect(reopened.sizeBytes, 7);
  });

  test('evicts least recently used file and rejects oversize data', () async {
    var time = 0;
    final cache = DiskImageCache(
      directory,
      maxBytes: 10,
      clock: () => DateTime.fromMicrosecondsSinceEpoch(++time),
    );
    await cache.initialize();
    await cache.write('a', bytes(4, 1));
    await cache.write('b', bytes(4, 2));
    await cache.read('a');
    await cache.write('c', bytes(4, 3));
    expect(await cache.read('b'), isNull);
    expect(await cache.read('a'), bytes(4, 1));
    expect(await cache.read('c'), bytes(4, 3));
    expect(cache.sizeBytes, 8);
    expect(await cache.write('huge', bytes(11, 0)), isFalse);
    expect(cache.sizeBytes, 8);
  });

  test(
    'recovers missing files, partial files, and stale size metadata',
    () async {
      final cache = DiskImageCache(directory, maxBytes: 10);
      await cache.initialize();
      await cache.write('a', bytes(4, 1));
      await cache.write('b', bytes(4, 2));
      await File(
        '${directory.path}${Platform.pathSeparator}${cache.keyFor('a')}.img',
      ).delete();
      await File(
        '${directory.path}${Platform.pathSeparator}${cache.keyFor('b')}.img',
      ).writeAsBytes(bytes(2, 2));
      await File(
        '${directory.path}${Platform.pathSeparator}orphan.img',
      ).writeAsBytes(bytes(1, 0));
      await File(
        '${directory.path}${Platform.pathSeparator}failed.part',
      ).writeAsBytes(bytes(1, 0));
      final reopened = DiskImageCache(directory, maxBytes: 10);
      await reopened.initialize();
      expect(reopened.sizeBytes, 0);
      expect(await reopened.read('a'), isNull);
      expect(await reopened.read('b'), isNull);
      expect(await directory.list().toList(), hasLength(1));
    },
  );

  test('concurrent writes remain within budget', () async {
    final cache = DiskImageCache(directory, maxBytes: 10);
    await cache.initialize();
    await Future.wait([
      for (var i = 0; i < 20; i++) cache.write('photo-$i', bytes(3, i)),
    ]);
    expect(cache.sizeBytes, lessThanOrEqualTo(10));
    final reopened = DiskImageCache(directory, maxBytes: 10);
    await reopened.initialize();
    expect(reopened.sizeBytes, cache.sizeBytes);
  });
}
