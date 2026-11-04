import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';

void main() {
  test('disk hit avoids a second download, even after cache restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-source-test-',
    );
    try {
      final firstCache = DiskImageCache(directory, maxBytes: 100);
      await firstCache.initialize();
      var downloads = 0;
      Future<Uint8List> fetch(Uri url) async {
        downloads++;
        return Uint8List.fromList([1, 2, 3]);
      }

      const url = 'https://photos.test/image';
      final first = ImageBytesRepository(firstCache, fetch: fetch);
      final (initial, initialDiskHit) = await first.load(url);
      expect(initial, [1, 2, 3]);
      expect(initialDiskHit, isFalse);

      final reopened = DiskImageCache(directory, maxBytes: 100);
      await reopened.initialize();
      final second = ImageBytesRepository(reopened, fetch: fetch);
      final (stored, diskHit) = await second.load(url);
      expect(stored, [1, 2, 3]);
      expect(diskHit, isTrue);
      expect(downloads, 1);

      await second.invalidate(url);
      final (refetched, miss) = await second.load(url);
      expect(refetched, [1, 2, 3]);
      expect(miss, isFalse);
      expect(downloads, 2);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
