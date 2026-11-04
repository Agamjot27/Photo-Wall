import 'dart:ui' as ui;
import 'dart:typed_data';

import '../../features/photos/models/photo.dart';
import 'image_bytes_repository.dart';
import 'memory_image_cache.dart';

typedef PhotoDecoder =
    Future<ui.Image> Function(Uint8List bytes, {required bool fullScreen});

class DecodedImageLoader {
  DecodedImageLoader({
    required this.repository,
    required this.memoryCache,
    PhotoDecoder? decoder,
  }) : _decoder = decoder ?? decodePhoto;

  final Future<ImageBytesRepository> repository;
  final MemoryImageCache memoryCache;
  final PhotoDecoder _decoder;

  Future<ui.Image> load(Photo photo, {required bool fullScreen}) async {
    final url = fullScreen ? photo.fullScreenUrl : photo.thumbnailUrl;
    final key = '$url|400';
    if (!fullScreen) {
      final cached = memoryCache.get(key);
      if (cached != null) return cached;
    }
    final source = await repository;
    final (bytes, fromDisk) = await source.load(url);
    ui.Image image;
    try {
      image = await _decoder(bytes, fullScreen: fullScreen);
    } catch (_) {
      if (!fromDisk) rethrow;
      await source.invalidate(url);
      image = await _decoder(
        await source.download(url),
        fullScreen: fullScreen,
      );
    }
    if (fullScreen) return image;
    return memoryCache.admit(key, image);
  }
}

Future<ui.Image> decodePhoto(
  Uint8List bytes, {
  required bool fullScreen,
}) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: fullScreen ? null : 400,
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}
