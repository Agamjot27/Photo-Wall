import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:photo_wall/core/images/decoded_image_loader.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';
import 'package:photo_wall/core/images/load_scheduler.dart';
import 'package:photo_wall/core/images/memory_image_cache.dart';
import 'package:photo_wall/features/photos/models/photo_catalog.dart';
import 'package:photo_wall/features/photos/widgets/decoded_photo_image.dart';

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

  test('cancelled decode disposes its late image', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-decode-cancel-',
    );
    final memory = MemoryImageCache(maxBytes: 1024);
    try {
      final disk = DiskImageCache(directory);
      await disk.initialize();
      final source = ImageBytesRepository(
        disk,
        fetch: (_) async => Uint8List.fromList([1]),
      );
      final started = Completer<void>();
      final finish = Completer<ui.Image>();
      final loader = DecodedImageLoader(
        repository: Future.value(source),
        memoryCache: memory,
        decoder: (bytes, {required fullScreen}) {
          started.complete();
          return finish.future;
        },
      );
      final request = loader.request(photoCatalog.first, fullScreen: false);
      final cancelled = expectLater(
        request.future,
        throwsA(isA<LoadCancelled>()),
      );
      await started.future;
      final lateImage = makeImage();
      request.cancel();
      finish.complete(lateImage);
      await cancelled;
      await Future<void>.delayed(Duration.zero);
      expect(lateImage.debugDisposed, isTrue);
      expect(memory.sizeBytes, 0);
      expect(loader.scheduler.activeCount, 0);
    } finally {
      memory.clear();
      await directory.delete(recursive: true);
    }
  });
  testWidgets('failed decoded photo shows Retry and can recover', (
    tester,
  ) async {
    var attempts = 0;
    Future<ui.Image> load(photo, {required bool fullScreen}) async {
      attempts++;
      if (attempts == 1) throw const FormatException('bad image');
      return makeImage();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: FTheme(
          data: FThemes.zinc.light,
          child: DecodedPhotoImage(photo: photoCatalog.first, loader: load),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Photo could not load'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    expect(attempts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('thumbnail memory hit skips disk, network and decode', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo-wall-memory-test-',
    );
    final cache = MemoryImageCache(maxBytes: 32 * 1024 * 1024);
    try {
      final disk = DiskImageCache(directory);
      await disk.initialize();
      var downloads = 0;
      var decodes = 0;
      final repository = ImageBytesRepository(
        disk,
        fetch: (uri) async {
          downloads++;
          return Uint8List.fromList([1]);
        },
      );
      final loader = DecodedImageLoader(
        repository: Future.value(repository),
        memoryCache: cache,
        decoder: (bytes, {required fullScreen}) async {
          decodes++;
          return makeImage();
        },
      );
      final first = await loader.load(photoCatalog.first, fullScreen: false);
      first.dispose();
      final second = await loader.load(photoCatalog.first, fullScreen: false);
      second.dispose();
      expect(downloads, 1);
      expect(decodes, 1);
      expect(cache.sizeBytes, 16);
      final viewer = await loader.load(photoCatalog.first, fullScreen: true);
      viewer.dispose();
      expect(decodes, 2);
      expect(cache.sizeBytes, 16);
    } finally {
      cache.clear();
      await directory.delete(recursive: true);
    }
  });

  test(
    'clear leaves an active image usable without refilling either cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'photo-wall-clear-loader-',
      );
      final memory = MemoryImageCache(maxBytes: 1024);
      try {
        final disk = DiskImageCache(directory);
        await disk.initialize();
        final started = Completer<void>();
        final release = Completer<void>();
        var downloads = 0;
        final source = ImageBytesRepository(
          disk,
          fetch: (_) async {
            downloads++;
            if (downloads == 1) {
              started.complete();
              await release.future;
            }
            return Uint8List.fromList([1]);
          },
        );
        final loader = DecodedImageLoader(
          repository: Future.value(source),
          memoryCache: memory,
          decoder: (bytes, {required fullScreen}) async => makeImage(),
        );
        final active = loader.request(photoCatalog.first, fullScreen: false);
        await started.future;

        await loader.clearCaches();
        release.complete();
        final visible = await active.future;
        expect(visible.width, 2);
        expect(memory.sizeBytes, 0);
        expect(disk.sizeBytes, 0);
        visible.dispose();

        final next = await loader.load(photoCatalog.first, fullScreen: false);
        next.dispose();
        expect(downloads, 2);
        expect(memory.sizeBytes, 16);
        expect(disk.sizeBytes, 1);
      } finally {
        memory.clear();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('late result is disposed and cannot replace another photo', (
    tester,
  ) async {
    final first = Completer<ui.Image>();
    var calls = 0;
    Future<ui.Image> load(photo, {required bool fullScreen}) {
      calls++;
      return calls == 1 ? first.future : Future.value(makeImage());
    }

    await tester.pumpWidget(
      MaterialApp(
        home: DecodedPhotoImage(photo: photoCatalog.first, loader: load),
      ),
    );
    expect(find.byKey(const ValueKey('photo-loading')), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: DecodedPhotoImage(photo: photoCatalog[1], loader: load),
      ),
    );
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    final current = tester.widget<RawImage>(find.byType(RawImage)).image!;
    final old = makeImage();
    first.complete(old);
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, current);
    expect(old.debugDisposed, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(current.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
