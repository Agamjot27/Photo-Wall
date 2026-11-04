import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:photo_wall/core/images/decoded_image_loader.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';
import 'package:photo_wall/core/images/memory_image_cache.dart';
import 'package:photo_wall/features/photos/screens/cache_diagnostics_screen.dart';

void main() {
  testWidgets('shows cache counters and a manual clear action', (tester) async {
    final directory =
        (await tester.runAsync(
          () => Directory.systemTemp.createTemp('photo-wall-diagnostics-'),
        ))!;
    final memory = MemoryImageCache();
    try {
      final disk = DiskImageCache(directory);
      await tester.runAsync(() async {
        await disk.initialize();
        await disk.write('photo', Uint8List.fromList([1, 2, 3]));
      });
      final source = ImageBytesRepository(disk);
      final loader = DecodedImageLoader(
        repository: Future.value(source),
        memoryCache: memory,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FTheme(
            data: FThemes.zinc.light,
            child: CacheDiagnosticsScreen(
              loader: loader,
              repository: Future.value(source),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Cache diagnostics'), findsOneWidget);
      expect(find.text('3 B / 104857600 B'), findsOneWidget);
      expect(find.text('Memory evictions'), findsOneWidget);
      expect(find.text('Ongoing downloads'), findsOneWidget);
      expect(find.text('Ongoing decodes'), findsOneWidget);
      expect(find.text('Clear caches'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      memory.clear();
      await tester.runAsync(() => directory.delete(recursive: true));
    }
  });
}
