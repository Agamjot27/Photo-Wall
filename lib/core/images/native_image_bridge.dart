import 'package:flutter/services.dart';

class NativeDecodedImage {
  const NativeDecodedImage(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final Uint8List bytes;
}

class NativeMemoryInfo {
  const NativeMemoryInfo({
    required this.availMemBytes,
    required this.totalMemBytes,
    required this.thresholdBytes,
    required this.lowMemory,
  });

  final int availMemBytes;
  final int totalMemBytes;
  final int thresholdBytes;
  final bool lowMemory;
}

class NativeImageBridge {
  NativeImageBridge({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.assignment.photowall/image');

  final MethodChannel _channel;

  Future<NativeDecodedImage> decodeDownsampled({
    String? path,
    Uint8List? bytes,
    required int maxWidth,
    required int maxHeight,
    String format = 'png',
  }) async {
    if ((path == null) == (bytes == null)) {
      throw ArgumentError('Provide exactly one of path or bytes');
    }
    if (maxWidth <= 0 || maxHeight <= 0) {
      throw ArgumentError('Output dimensions must be positive');
    }
    final result = await _channel
        .invokeMapMethod<String, dynamic>('decodeDownsampled', {
          'path': path,
          'bytes': bytes,
          'maxWidth': maxWidth,
          'maxHeight': maxHeight,
          'format': format,
        });
    final width = result?['width'];
    final height = result?['height'];
    final outputBytes = result?['bytes'];
    if (width is! int ||
        height is! int ||
        width <= 0 ||
        height <= 0 ||
        width > maxWidth ||
        height > maxHeight ||
        outputBytes is! Uint8List ||
        outputBytes.isEmpty) {
      throw const FormatException('Invalid native image response');
    }
    return NativeDecodedImage(width, height, outputBytes);
  }

  Future<NativeMemoryInfo> getMemoryInfo() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getMemoryInfo',
    );
    final available = result?['availMemBytes'];
    final total = result?['totalMemBytes'];
    final threshold = result?['thresholdBytes'];
    final lowMemory = result?['lowMemory'];
    if (available is! int ||
        total is! int ||
        threshold is! int ||
        lowMemory is! bool ||
        available < 0 ||
        total <= 0 ||
        threshold < 0) {
      throw const FormatException('Invalid native memory response');
    }
    return NativeMemoryInfo(
      availMemBytes: available,
      totalMemBytes: total,
      thresholdBytes: threshold,
      lowMemory: lowMemory,
    );
  }
}
