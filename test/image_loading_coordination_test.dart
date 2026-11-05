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

class AbortableRepository extends ImageBytesRepository {
  AbortableRepository(super.cache, this.started);

  final Completer<void> started;

  @override
  Future<(Uint8List, bool)> load(
    String url, {
    bool admitToDisk = true,
    LoadCancellation? cancellation,
  }) async {
    if (url == photoCatalog.first.thumbnailUrl) {
      started.complete();
      await cancellation!.whenCancelled;
      throw LoadCancelled();
    }
    return (Uint8List.fromList([1]), false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('abandoned active thumbnail gives the viewer its slot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-active-cancel-',
    );
    final memory = MemoryImageCache(maxBytes: 1024);
    try {
      final started = Completer<void>();
      final source = AbortableRepository(DiskImageCache(directory), started);
      final scheduler = LoadScheduler(maxActive: 1);
      final loader = DecodedImageLoader(
        repository: Future.value(source),
        memoryCache: memory,
        scheduler: scheduler,
        decoder: (bytes, {required fullScreen}) async => tinyImage(),
      );
      final stale = loader.request(photoCatalog.first, fullScreen: false);
      final cancelled = expectLater(
        stale.future,
        throwsA(isA<LoadCancelled>()),
      );
      await started.future;
      final viewer = loader.request(photoCatalog[1], fullScreen: true);
      expect(scheduler.queuedCount, 1);
      stale.cancel();
      await cancelled;
      final image = await viewer.future;
      expect(image.width, 1);
      image.dispose();
      expect(scheduler.activeCount, 0);
    } finally {
      memory.clear();
      await directory.delete(recursive: true);
    }
  });

  test(
    'replacing a cancelled queued request does not lose the new job',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'photo-wall-queue-',
      );
      final memory = MemoryImageCache(maxBytes: 1024);
      try {
        final disk = DiskImageCache(directory);
        await disk.initialize();
        final firstStarted = Completer<void>();
        final releaseFirst = Completer<void>();
        var downloads = 0;
        final source = ImageBytesRepository(
          disk,
          fetch: (uri) async {
            downloads++;
            if (uri.toString() == photoCatalog.first.thumbnailUrl) {
              firstStarted.complete();
              await releaseFirst.future;
            }
            return Uint8List.fromList([1]);
          },
        );
        final loader = DecodedImageLoader(
          repository: Future.value(source),
          memoryCache: memory,
          scheduler: LoadScheduler(maxActive: 1),
          decoder: (bytes, {required fullScreen}) async => tinyImage(),
        );
        final active = loader.request(photoCatalog.first, fullScreen: false);
        await firstStarted.future;
        final old = loader.request(photoCatalog[1], fullScreen: false);
        final cancelled = expectLater(
          old.future,
          throwsA(isA<LoadCancelled>()),
        );
        old.cancel();
        final replacement = loader.request(photoCatalog[1], fullScreen: false);
        await cancelled;
        releaseFirst.complete();
        (await active.future).dispose();
        (await replacement.future).dispose();
        expect(downloads, 2);
        expect(loader.inFlightCount, 0);
      } finally {
        memory.clear();
        await directory.delete(recursive: true);
      }
    },
  );

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
