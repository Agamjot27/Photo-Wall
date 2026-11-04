import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/decoded_image_loader.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';
import 'package:photo_wall/core/images/memory_image_cache.dart';
import 'package:photo_wall/core/images/memory_pressure_observer.dart';
import 'package:photo_wall/features/photos/models/photo_catalog.dart';

ui.Image makeImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xFF00FF00), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(2, 2);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pressure trims cache but leaves a visible clone usable', (
    tester,
  ) async {
    final cache = MemoryImageCache(maxBytes: 1024);
    final active = cache.admit('photo', makeImage());
    var notifications = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryPressureObserver(
          onPressure: () {
            notifications++;
            cache.trimForPressure();
          },
          child: const SizedBox(),
        ),
      ),
    );
    tester.binding.handleMemoryPressure();
    expect(notifications, 1);
    expect(cache.sizeBytes, 0);
    expect(cache.evictionCount, 1);
    expect(active.width, 2);
    active.dispose();
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleMemoryPressure();
    expect(notifications, 1);
  });

  test('work started before pressure cannot repopulate the cache', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-pressure-',
    );
    final cache = MemoryImageCache(maxBytes: 1024);
    try {
      final disk = DiskImageCache(directory);
      await disk.initialize();
      final started = Completer<void>();
      final release = Completer<void>();
      var downloads = 0;
      final source = ImageBytesRepository(
        disk,
        fetch: (uri) async {
          downloads++;
          started.complete();
          await release.future;
          return Uint8List.fromList([1]);
        },
      );
      final loader = DecodedImageLoader(
        repository: Future.value(source),
        memoryCache: cache,
        decoder: (bytes, {required fullScreen}) async => makeImage(),
      );
      final request = loader.request(photoCatalog.first, fullScreen: false);
      await started.future;
      loader.handleMemoryPressure();
      release.complete();
      final visible = await request.future;
      expect(visible.width, 2);
      expect(cache.sizeBytes, 0);
      visible.dispose();

      final later = await loader.load(photoCatalog.first, fullScreen: false);
      later.dispose();
      expect(downloads, 1);
      expect(cache.sizeBytes, 16);
    } finally {
      cache.clear();
      await directory.delete(recursive: true);
    }
  });
}
