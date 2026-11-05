import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/features/photos/screens/photo_viewer_screen.dart';
import 'package:photo_wall/features/photos/screens/photo_wall_screen.dart';
import 'package:photo_wall/features/photos/widgets/decoded_photo_image.dart';

import 'support/test_loader.dart';

void main() {
  testWidgets(
    'viewer opens selected photo and both back paths preserve scroll',
    (tester) async {
      final loader = makeTestLoader();
      await tester.pumpWidget(
        MaterialApp(home: PhotoWallScreen(loader: loader)),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(GridView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      final offset = position.pixels;
      expect(offset, greaterThan(0));
      final tile = find.byType(InkWell).hitTestable().first;
      final photo =
          tester
              .widget<DecodedPhotoImage>(
                find.descendant(
                  of: tile,
                  matching: find.byType(DecodedPhotoImage),
                ),
              )
              .photo;

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PhotoViewerScreen>(find.byType(PhotoViewerScreen))
            .photo
            .id,
        photo.id,
      );
      expect(
        tester
            .widget<DecodedPhotoImage>(
              find.descendant(
                of: find.byType(PhotoViewerScreen),
                matching: find.byType(DecodedPhotoImage),
              ),
            )
            .fullScreen,
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(position.pixels, offset);

      await tester.tap(find.byType(InkWell).hitTestable().first);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(position.pixels, offset);
      expect(tester.takeException(), isNull);
    },
  );
}
