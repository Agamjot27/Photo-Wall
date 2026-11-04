import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/features/photos/screens/photo_wall_screen.dart';

void main() {
  testWidgets('app starts on a lazy three-column photo grid', (tester) async {
    final image = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoWallScreen(
          imageProviderFactory: (photo, {required fullScreen}) => image,
        ),
      ),
    );
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
