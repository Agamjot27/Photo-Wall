import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/memory_image_cache.dart';

ui.Image makeImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xFFFFFFFF), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

void main() {
  testWidgets('LRU eviction keeps active clone valid', (tester) async {
    final cache = MemoryImageCache(maxBytes: 8);
    final a = cache.admit('a', makeImage(1, 1));
    a.dispose();
    final b = cache.admit('b', makeImage(1, 1));
    b.dispose();
    final active = cache.get('a')!;
    final c = cache.admit('c', makeImage(1, 1));
    c.dispose();
    expect(cache.get('b'), isNull);
    expect(cache.sizeBytes, 8);
    expect(cache.evictionCount, 1);
    expect(active.width, 1);
    active.dispose();
    cache.clear();
    expect(cache.sizeBytes, 0);
  });

  testWidgets('oversize image is not retained but caller owns it', (
    tester,
  ) async {
    final cache = MemoryImageCache(maxBytes: 4);
    final image = cache.admit('large', makeImage(2, 2));
    expect(cache.sizeBytes, 0);
    expect(cache.length, 0);
    expect(image.width, 2);
    image.dispose();
  });

  testWidgets('replacement and clear do not count as capacity evictions', (
    tester,
  ) async {
    final cache = MemoryImageCache(maxBytes: 12);
    cache.admit('a', makeImage(1, 1)).dispose();
    cache.admit('a', makeImage(1, 1)).dispose();
    expect(cache.sizeBytes, 4);
    cache.clear();
    expect(cache.sizeBytes, 0);
    expect(cache.evictionCount, 0);
  });
}
