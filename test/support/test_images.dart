import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<MemoryImage> readyTestImage(WidgetTester tester) async {
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
    ),
  );
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  await tester.runAsync(() async {
    await precacheImage(image, tester.element(find.byType(SizedBox).first));
  });
  return image;
}

class ControlledImageProvider extends ImageProvider<ControlledImageProvider> {
  ControlledImageProvider(this.result, {this.eviction});

  final Future<ImageInfo> Function() result;
  final Completer<bool>? eviction;

  @override
  Future<ControlledImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    ControlledImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(result());
  }

  @override
  Future<bool> evict({
    ImageCache? cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) {
    return eviction?.future ??
        super.evict(cache: cache, configuration: configuration);
  }
}
