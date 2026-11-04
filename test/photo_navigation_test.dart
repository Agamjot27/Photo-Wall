import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/features/photos/screens/photo_viewer_screen.dart';
import 'package:photo_wall/features/photos/screens/photo_wall_screen.dart';
import 'package:photo_wall/features/photos/widgets/photo_image.dart';

import 'support/test_images.dart';

void main() {
  testWidgets(
    'viewer opens selected photo and both back paths preserve scroll',
    (tester) async {
      final image = await readyTestImage(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoWallScreen(
            imageProviderFactory: (photo, {required fullScreen}) => image,
          ),
        ),
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
              .widget<PhotoImage>(
                find.descendant(of: tile, matching: find.byType(PhotoImage)),
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
        tester.widget<PhotoImage>(find.byType(PhotoImage)).fullScreen,
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
