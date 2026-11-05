import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/decoded_image_loader.dart';
import 'package:photo_wall/core/images/disk_image_cache.dart';
import 'package:photo_wall/core/images/image_bytes_repository.dart';
import 'package:photo_wall/core/images/memory_image_cache.dart';
import 'package:photo_wall/features/photos/models/photo.dart';

ui.Image makeTestImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xFF123456), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(2, 2);
  picture.dispose();
  return image;
}

DecodedImageLoader makeTestLoader({PhotoDecoder? decoder}) {
  final memory = MemoryImageCache();
  addTearDown(memory.clear);
  final disk = DiskImageCache(Directory.systemTemp);
  final repository = ImageBytesRepository(
    disk,
    fetch: (_) async => Uint8List.fromList([1]),
  );
  return _WidgetLoader(
    repository,
    memory,
    decoder ?? (_, {required bool fullScreen}) async => makeTestImage(),
  );
}

class _WidgetLoader extends DecodedImageLoader {
  _WidgetLoader(
    ImageBytesRepository repository,
    MemoryImageCache memory,
    this._imageFactory,
  ) : super(repository: Future.value(repository), memoryCache: memory);

  final PhotoDecoder _imageFactory;

  @override
  ImageLoadRequest request(Photo photo, {required bool fullScreen}) =>
      ImageLoadRequest(
        _imageFactory(Uint8List(0), fullScreen: fullScreen),
        () {},
      );

  @override
  Future<ui.Image> load(Photo photo, {required bool fullScreen}) =>
      _imageFactory(Uint8List(0), fullScreen: fullScreen);
}
