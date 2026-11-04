import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../features/photos/models/photo.dart';
import 'image_bytes_repository.dart';
import 'load_scheduler.dart';
import 'memory_image_cache.dart';

typedef PhotoDecoder =
    Future<ui.Image> Function(Uint8List bytes, {required bool fullScreen});

class ImageLoadRequest {
  ImageLoadRequest(this.future, this.cancel);
  final Future<ui.Image> future;
  final void Function() cancel;
}

class DecodedImageLoader {
  DecodedImageLoader({
    required this.repository,
    required this.memoryCache,
    LoadScheduler? scheduler,
    PhotoDecoder? decoder,
  }) : scheduler = scheduler ?? LoadScheduler(),
       _decoder = decoder ?? decodePhoto;

  final Future<ImageBytesRepository> repository;
  final MemoryImageCache memoryCache;
  final LoadScheduler scheduler;
  final PhotoDecoder _decoder;
  final Map<String, _SharedLoad> _inFlight = {};
  int _admissionEpoch = 0;
  int _activeDecodes = 0;

  int get inFlightCount => _inFlight.length;
  int get activeDecodes => _activeDecodes;

  void handleMemoryPressure() {
    _admissionEpoch++;
    memoryCache.trimForPressure();
  }

  Future<void> clearCaches() async {
    _admissionEpoch++;
    memoryCache.clear();
    final source = await repository;
    await source.clearDiskCache();
  }

  Future<ui.Image> load(Photo photo, {required bool fullScreen}) =>
      request(photo, fullScreen: fullScreen).future;

  ImageLoadRequest request(Photo photo, {required bool fullScreen}) {
    final url = fullScreen ? photo.fullScreenUrl : photo.thumbnailUrl;
    final key = '$url|${fullScreen ? 'viewer' : '400'}';
    if (!fullScreen) {
      final cached = memoryCache.get(key);
      if (cached != null) {
        return ImageLoadRequest(Future.value(cached), () {});
      }
    }
    var shared = _inFlight[key];
    if (shared == null) {
      final admissionEpoch = _admissionEpoch;
      final job = scheduler.schedule(
        () => _execute(
          url,
          key,
          fullScreen: fullScreen,
          admissionEpoch: admissionEpoch,
        ),
        urgent: fullScreen,
      );
      shared = _SharedLoad(job, () => _inFlight.remove(key));
      _inFlight[key] = shared;
      final current = shared;
      unawaited(
        job.future.then(
          (image) {
            if (identical(_inFlight[key], current)) _inFlight.remove(key);
            current.complete(image);
          },
          onError: (Object error, StackTrace stack) {
            if (identical(_inFlight[key], current)) _inFlight.remove(key);
            current.fail(error, stack);
          },
        ),
      );
    }
    return shared.subscribe();
  }

  Future<ui.Image> _execute(
    String url,
    String key, {
    required bool fullScreen,
    required int admissionEpoch,
  }) async {
    if (!fullScreen) {
      final cached = memoryCache.get(key);
      if (cached != null) return cached;
    }
    final source = await repository;
    final (bytes, fromDisk) = await source.load(
      url,
      admitToDisk: admissionEpoch == _admissionEpoch,
    );
    ui.Image image;
    try {
      image = await _decode(bytes, fullScreen: fullScreen);
    } catch (_) {
      if (!fromDisk) rethrow;
      await source.invalidate(url);
      image = await _decode(
        await source.download(
          url,
          admitToDisk: admissionEpoch == _admissionEpoch,
        ),
        fullScreen: fullScreen,
      );
    }
    if (fullScreen) return image;
    if (admissionEpoch != _admissionEpoch) return image;
    return memoryCache.admit(key, image);
  }

  Future<ui.Image> _decode(Uint8List bytes, {required bool fullScreen}) async {
    _activeDecodes++;
    try {
      return await _decoder(bytes, fullScreen: fullScreen);
    } finally {
      _activeDecodes--;
    }
  }
}

class _SharedLoad {
  _SharedLoad(this.job, this.onCancelledQueued);

  final ScheduledJob<ui.Image> job;
  final void Function() onCancelledQueued;
  final Set<Completer<ui.Image>> _subscribers = {};

  ImageLoadRequest subscribe() {
    final subscriber = Completer<ui.Image>();
    _subscribers.add(subscriber);
    return ImageLoadRequest(subscriber.future, () {
      if (!_subscribers.remove(subscriber)) return;
      subscriber.completeError(LoadCancelled());
      if (_subscribers.isEmpty && !job.isStarted()) {
        onCancelledQueued();
        job.cancel();
      }
    });
  }

  void complete(ui.Image image) {
    for (final subscriber in _subscribers) {
      subscriber.complete(image.clone());
    }
    _subscribers.clear();
    image.dispose();
  }

  void fail(Object error, StackTrace stack) {
    for (final subscriber in _subscribers) {
      subscriber.completeError(error, stack);
    }
    _subscribers.clear();
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
