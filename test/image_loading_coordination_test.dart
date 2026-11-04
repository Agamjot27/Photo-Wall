import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/decoded_image_loader.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';
import 'package:photo_wall/core/images/load_scheduler.dart';
import 'package:photo_wall/core/images/memory_image_cache.dart';
import 'package:photo_wall/features/photos/models/photo_catalog.dart';

ui.Image tinyImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xFF000000), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(1, 1);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('identical subscribers share work and one may leave safely', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-shared-',
    );
    final memory = MemoryImageCache(maxBytes: 1024);
    try {
      final disk = DiskImageCache(directory);
      await disk.initialize();
      final started = Completer<void>();
      final release = Completer<void>();
      var downloads = 0;
      var decodes = 0;
      final source = ImageBytesRepository(
        disk,
        fetch: (uri) async {
          downloads++;
          started.complete();
          await release.future;
          return Uint8List.fromList([1]);
        },
      );
      final scheduler = LoadScheduler();
      final loader = DecodedImageLoader(
        repository: Future.value(source),
        memoryCache: memory,
        scheduler: scheduler,
        decoder: (bytes, {required fullScreen}) async {
          decodes++;
          return tinyImage();
        },
      );
      final first = loader.request(photoCatalog.first, fullScreen: false);
      final second = loader.request(photoCatalog.first, fullScreen: false);
      final cancelled = expectLater(
        first.future,
        throwsA(isA<LoadCancelled>()),
      );
      await started.future;
      expect(downloads, 1);
      expect(loader.inFlightCount, 1);
      first.cancel();
      await cancelled;
      release.complete();
      final image = await second.future;
      expect(image.width, 1);
      image.dispose();
      expect(decodes, 1);
      expect(loader.inFlightCount, 0);
      expect(scheduler.activeCount, 0);
      expect(memory.sizeBytes, 4);
    } finally {
      memory.clear();
      await directory.delete(recursive: true);
    }
  });
}
