import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/features/photos/models/photo_catalog.dart';
import 'package:photo_wall/features/photos/screens/photo_viewer_screen.dart';
import 'package:photo_wall/features/photos/screens/photo_wall_screen.dart';
import 'package:photo_wall/features/photos/widgets/decoded_photo_image.dart';

ui.Image makeImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xFF123456), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(2, 2);
  picture.dispose();
  return image;
}

void main() {
  testWidgets('leaving viewer releases each fullscreen decoded image', (
    tester,
  ) async {
    final fullImages = <ui.Image>[];
    Future<ui.Image> load(photo, {required bool fullScreen}) async {
      final image = makeImage();
      if (fullScreen) fullImages.add(image);
      return image;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: PhotoWallScreen(
          photos: [photoCatalog.first],
          decodedLoader: load,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var visit = 0; visit < 3; visit++) {
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(fullImages.length, visit + 1);
      expect(fullImages.last.debugDisposed, isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(fullImages.last.debugDisposed, isTrue);
      expect(find.byType(DecodedPhotoImage), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
