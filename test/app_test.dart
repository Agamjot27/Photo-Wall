import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:photo_wall/app/photo_wall_app.dart';
import 'package:photo_wall/features/photos/widgets/decoded_photo_image.dart';

import 'support/test_loader.dart';

void main() {
  testWidgets('Forui gallery fits a narrow screen in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = makeTestLoader();
    await tester.pumpWidget(
      PhotoWallApp(themeMode: ThemeMode.dark, loader: loader),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FScaffold), findsOneWidget);
    expect(find.text('100 photos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app starts on a lazy three-column photo grid', (tester) async {
    final loader = makeTestLoader();
    await tester.pumpWidget(PhotoWallApp(loader: loader));
    await tester.pumpAndSettle();

    expect(find.text('Photo Wall'), findsOneWidget);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(find.byType(DecodedPhotoImage).evaluate().length, lessThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Top returns to the first row after a short scroll', (
    tester,
  ) async {
    final loader = makeTestLoader();
    await tester.pumpWidget(PhotoWallApp(loader: loader));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -50));
    await tester.pump();
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, greaterThan(0));
    expect(position.pixels, lessThan(80));

    await tester.tap(find.byKey(const ValueKey('scroll-to-top-action')));
    await tester.pump();
    expect(position.pixels, 0);
  });

  testWidgets('live cache panel stays visible while scrolling and can hide', (
    tester,
  ) async {
    final loader = makeTestLoader();
    await tester.pumpWidget(PhotoWallApp(loader: loader));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cache-debug-panel')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cache-dock-action')));
    await tester.pump();
    expect(find.byKey(const ValueKey('cache-debug-panel')), findsOneWidget);
    expect(find.textContaining('Evictions'), findsOneWidget);
    expect(find.textContaining('Downloads'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(0, -900));
    await tester.pump();
    expect(find.byKey(const ValueKey('cache-debug-panel')), findsOneWidget);
    final topAction = tester.widget<TextButton>(
      find.byKey(const ValueKey('scroll-to-top-action')),
    );
    expect(topAction.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('scroll-to-top-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      closeTo(0, 1),
    );
    await tester.tap(find.byKey(const ValueKey('cache-dock-action')));
    await tester.pump();
    expect(find.byKey(const ValueKey('cache-debug-panel')), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
