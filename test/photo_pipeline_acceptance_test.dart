import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/decoded_image_loader.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';
import 'package:photo_wall/core/images/memory_image_cache.dart';
import 'package:photo_wall/features/photos/models/photo_catalog.dart';

ui.Image tinyImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xFF123456), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(2, 2);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt disk image is replaced by a valid network decode', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-corrupt-acceptance-',
    );
    final memory = MemoryImageCache(maxBytes: 1024);
    try {
      final disk = DiskImageCache(directory, maxBytes: 1024);
      await disk.initialize();
      final photo = photoCatalog.first;
      await disk.write(photo.thumbnailUrl, Uint8List.fromList([0, 1, 2]));
      final validImage = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
      );
      var downloads = 0;
      final source = ImageBytesRepository(
        disk,
        fetch: (_) async {
          downloads++;
          return validImage;
        },
      );
      final loader = DecodedImageLoader(
        repository: Future.value(source),
        memoryCache: memory,
      );

      final image = await loader.load(photo, fullScreen: false);
      expect((image.width, image.height), (1, 1));
      image.dispose();
      expect(downloads, 1);
      expect(await disk.read(photo.thumbnailUrl), validImage);
      memory.clear();
      (await loader.load(photo, fullScreen: false)).dispose();
      expect(downloads, 1);
    } finally {
      memory.clear();
      await directory.delete(recursive: true);
    }
  });

  test(
    'cold, warm, disk, and offline restart use the right cache layer',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'photo-wall-acceptance-',
      );
      final memory = MemoryImageCache(maxBytes: 1024);
      final restartedMemory = MemoryImageCache(maxBytes: 1024);
      try {
        final disk = DiskImageCache(directory, maxBytes: 1024);
        await disk.initialize();
        var downloads = 0;
        var decodes = 0;
        final source = ImageBytesRepository(
          disk,
          fetch: (_) async {
            downloads++;
            return Uint8List.fromList([1, 2, 3]);
          },
        );
        Future<ui.Image> decode(
          Uint8List bytes, {
          required bool fullScreen,
        }) async {
          decodes++;
          return tinyImage();
        }

        final loader = DecodedImageLoader(
          repository: Future.value(source),
          memoryCache: memory,
          decoder: decode,
        );
        final photo = photoCatalog.first;
        (await loader.load(photo, fullScreen: false)).dispose();
        expect(
          (downloads, decodes, memory.sizeBytes, disk.sizeBytes),
          (1, 1, 16, 3),
        );

        (await loader.load(photo, fullScreen: false)).dispose();
        expect((downloads, decodes), (1, 1));

        memory.clear();
        (await loader.load(photo, fullScreen: false)).dispose();
        expect((downloads, decodes), (1, 2));

        (await loader.load(photo, fullScreen: true)).dispose();
        expect((downloads, decodes, disk.sizeBytes), (2, 3, 6));

        final reopenedDisk = DiskImageCache(directory, maxBytes: 1024);
        await reopenedDisk.initialize();
        final offlineSource = ImageBytesRepository(
          reopenedDisk,
          fetch: (_) => throw const SocketException('offline'),
        );
        final restarted = DecodedImageLoader(
          repository: Future.value(offlineSource),
          memoryCache: restartedMemory,
          decoder: decode,
        );
        (await restarted.load(photo, fullScreen: false)).dispose();
        (await restarted.load(photo, fullScreen: true)).dispose();
        expect(restartedMemory.sizeBytes, 16);
        expect(reopenedDisk.sizeBytes, 6);
        expect(offlineSource.activeDownloads, 0);
        expect(decodes, 5);
      } finally {
        memory.clear();
        restartedMemory.clear();
        await directory.delete(recursive: true);
      }
    },
  );
}
