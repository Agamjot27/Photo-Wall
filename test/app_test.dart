import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:photo_wall/app/photo_wall_app.dart';
import 'package:photo_wall/features/photos/screens/photo_wall_screen.dart';

void main() {
  testWidgets('Forui gallery fits a narrow screen in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      PhotoWallApp(
        themeMode: ThemeMode.dark,
        imageProviderFactory: (photo, {required fullScreen}) => image,
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(image, tester.element(find.byType(PhotoWallScreen)));
    });
    await tester.pumpAndSettle();
    expect(find.byType(FScaffold), findsOneWidget);
    expect(find.text('100 photos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app starts on a lazy three-column photo grid', (tester) async {
    final image = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      PhotoWallApp(
        imageProviderFactory: (photo, {required fullScreen}) => image,
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(image, tester.element(find.byType(PhotoWallScreen)));
    });
    await tester.pumpAndSettle();

    expect(find.text('Photo Wall'), findsOneWidget);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(find.byType(Image).evaluate().length, lessThan(100));
    expect(tester.takeException(), isNull);
  });
}
