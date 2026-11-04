import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';

void main() {
  test('a stalled image response ends with a timeout', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.write([1, 2, 3]);
    });
    try {
      final url = Uri.parse('http://127.0.0.1:${server.port}/photo');
      await expectLater(
        fetchImageBytes(url, timeout: const Duration(milliseconds: 250)),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      await server.close(force: true);
    }
  });

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

  test('clear prevents an active download from restoring old files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-clear-test-',
    );
    try {
      final disk = DiskImageCache(directory);
      await disk.initialize();
      final response = Completer<Uint8List>();
      final source = ImageBytesRepository(disk, fetch: (_) => response.future);
      final request = source.download('photo');
      await Future<void>.delayed(Duration.zero);
      expect(source.activeDownloads, 1);

      await source.clearDiskCache();
      response.complete(Uint8List.fromList([1, 2, 3]));
      expect(await request, [1, 2, 3]);
      expect(source.activeDownloads, 0);
      expect(disk.sizeBytes, 0);
      expect(await disk.read('photo'), isNull);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
