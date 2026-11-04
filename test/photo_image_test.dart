import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/features/photos/models/photo.dart';
import 'package:photo_wall/features/photos/models/photo_catalog.dart';
import 'package:photo_wall/features/photos/widgets/photo_image.dart';

import 'support/test_images.dart';

void main() {
  testWidgets('failed image retries successfully without changing photo', (
    tester,
  ) async {
    final ready = await readyTestImage(tester);
    final failed = ControlledImageProvider(
      () => Future<ImageInfo>.error(StateError('offline')),
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoImage(
          photo: photoCatalog.first,
          imageProviderFactory: (photo, {required fullScreen}) {
            calls++;
            return calls == 1 ? failed : ready;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Photo failed to load. Retry'), findsOneWidget);
    await tester.tap(find.byTooltip('Photo failed to load. Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byTooltip('Photo failed to load. Retry'), findsNothing);
    expect(tester.widget<Image>(find.byType(Image)).image, ready);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('loading result from old photo cannot replace new photo', (
    tester,
  ) async {
    final ready = await readyTestImage(tester);
    final pending = Completer<ImageInfo>();
    final delayed = ControlledImageProvider(() => pending.future);
    ImageProvider<Object> factory(Photo photo, {required bool fullScreen}) =>
        photo.id == photoCatalog.first.id ? delayed : ready;

    Widget screen(int index) => MaterialApp(
      home: PhotoImage(
        photo: photoCatalog[index],
        imageProviderFactory: factory,
      ),
    );
    await tester.pumpWidget(screen(0));
    expect(find.byKey(const ValueKey('photo-loading')), findsOneWidget);
    await tester.pumpWidget(screen(1));
    await tester.pumpAndSettle();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xFFFF0000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final lateImage = picture.toImageSync(1, 1);
    picture.dispose();
    pending.complete(ImageInfo(image: lateImage));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, ready);
    expect(find.byKey(const ValueKey('photo-loading')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('disposing during retry does not update the removed widget', (
    tester,
  ) async {
    final eviction = Completer<bool>();
    final failed = ControlledImageProvider(
      () => Future<ImageInfo>.error(StateError('offline')),
      eviction: eviction,
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoImage(
          photo: photoCatalog.first,
          imageProviderFactory: (photo, {required fullScreen}) {
            calls++;
            return failed;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Photo failed to load. Retry'));
    await tester.pumpWidget(const SizedBox());
    eviction.complete(true);
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 250));
  });
}
