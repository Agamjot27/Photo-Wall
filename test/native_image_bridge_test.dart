import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/decoded_image_loader.dart';
import 'package:photo_wall/core/images/native_image_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.assignment.photowall/image');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('native decoding receives bytes and validates its dimensions', () async {
    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
    );
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'decodeDownsampled');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['bytes'], imageBytes);
      expect(args['maxWidth'], 400);
      expect(args['maxHeight'], 400);
      expect(args['format'], 'jpeg');
      calls++;
      return {'width': 1, 'height': 1, 'bytes': imageBytes};
    });
    final bridge = NativeImageBridge(channel: channel);
    final thumbnail = await decodePhoto(
      imageBytes,
      fullScreen: false,
      nativeBridge: bridge,
    );
    expect((thumbnail.width, thumbnail.height), (1, 1));
    thumbnail.dispose();
    final viewer = await decodePhoto(
      imageBytes,
      fullScreen: true,
      nativeBridge: bridge,
    );
    viewer.dispose();
    expect(calls, 1);

    await expectLater(
      bridge.decodeDownsampled(
        bytes: imageBytes,
        path: 'both',
        maxWidth: 400,
        maxHeight: 400,
      ),
      throwsArgumentError,
    );
  });

  test('native memory information validates the channel response', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getMemoryInfo');
      return {
        'availMemBytes': 200,
        'totalMemBytes': 1000,
        'thresholdBytes': 100,
        'lowMemory': false,
      };
    });
    final info = await NativeImageBridge(channel: channel).getMemoryInfo();
    expect(info.availMemBytes, 200);
    expect(info.totalMemBytes, 1000);
    expect(info.thresholdBytes, 100);
    expect(info.lowMemory, isFalse);
  });

  test(
    'path input and invalid dimensions follow the channel contract',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map<Object?, Object?>;
        expect(args['path'], '/cache/photo.jpg');
        expect(args['bytes'], isNull);
        expect(args['format'], 'png');
        return {
          'width': 20,
          'height': 10,
          'bytes': Uint8List.fromList([1]),
        };
      });
      final bridge = NativeImageBridge(channel: channel);
      final result = await bridge.decodeDownsampled(
        path: '/cache/photo.jpg',
        maxWidth: 20,
        maxHeight: 20,
      );
      expect((result.width, result.height), (20, 10));
      await expectLater(
        bridge.decodeDownsampled(
          path: '/cache/photo.jpg',
          maxWidth: 0,
          maxHeight: 20,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'invalid native image response fails rather than caching bad data',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'width': 401, 'height': 1, 'bytes': Uint8List(1)},
      );
      await expectLater(
        NativeImageBridge(channel: channel).decodeDownsampled(
          bytes: Uint8List.fromList([1]),
          maxWidth: 400,
          maxHeight: 400,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
