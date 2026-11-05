import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../features/photos/models/photo.dart';
import 'image_bytes_repository.dart';
import 'load_scheduler.dart';
import 'memory_image_cache.dart';
import 'native_image_bridge.dart';

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
       _decoder = decoder;

  final Future<ImageBytesRepository> repository;
  final MemoryImageCache memoryCache;
  final LoadScheduler scheduler;
  final PhotoDecoder? _decoder;
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
      final cancellation = LoadCancellation();
      final job = scheduler.schedule(
        () => _execute(
          url,
          key,
          fullScreen: fullScreen,
          admissionEpoch: admissionEpoch,
          cancellation: cancellation,
        ),
        urgent: fullScreen,
      );
      late final _SharedLoad current;
      current = _SharedLoad(job, cancellation, () {
        if (identical(_inFlight[key], current)) _inFlight.remove(key);
      });
      shared = current;
      _inFlight[key] = shared;
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
    required LoadCancellation cancellation,
  }) async {
    cancellation.throwIfCancelled();
    if (!fullScreen) {
      final cached = memoryCache.get(key);
      if (cached != null) return cached;
    }
    final source = await repository;
    cancellation.throwIfCancelled();
    final (bytes, fromDisk) = await source.load(
      url,
      admitToDisk: admissionEpoch == _admissionEpoch,
      cancellation: cancellation,
    );
    cancellation.throwIfCancelled();
    ui.Image image;
    try {
      image = await _decode(
        bytes,
        fullScreen: fullScreen,
        cancellation: cancellation,
      );
    } catch (error) {
      if (error is LoadCancelled || !fromDisk) rethrow;
      cancellation.throwIfCancelled();
      await source.invalidate(url);
      image = await _decode(
        await source.download(
          url,
          admitToDisk: admissionEpoch == _admissionEpoch,
          cancellation: cancellation,
        ),
        fullScreen: fullScreen,
        cancellation: cancellation,
      );
    }
    if (fullScreen) return image;
    if (admissionEpoch != _admissionEpoch) return image;
    return memoryCache.admit(key, image);
  }

  Future<ui.Image> _decode(
    Uint8List bytes, {
    required bool fullScreen,
    required LoadCancellation cancellation,
  }) async {
    _activeDecodes++;
    try {
      cancellation.throwIfCancelled();
      final image =
          await (_decoder?.call(bytes, fullScreen: fullScreen) ??
              decodePhoto(
                bytes,
                fullScreen: fullScreen,
                cancellation: cancellation,
              ));
      if (cancellation.isCancelled) {
        image.dispose();
        throw LoadCancelled();
      }
      return image;
    } finally {
      _activeDecodes--;
    }
  }
}

class _SharedLoad {
  _SharedLoad(this.job, this.cancellation, this.onLastSubscriberCancelled);

  final ScheduledJob<ui.Image> job;
  final LoadCancellation cancellation;
  final void Function() onLastSubscriberCancelled;
  final Set<Completer<ui.Image>> _subscribers = {};

  ImageLoadRequest subscribe() {
    final subscriber = Completer<ui.Image>();
    _subscribers.add(subscriber);
    return ImageLoadRequest(subscriber.future, () {
      if (!_subscribers.remove(subscriber)) return;
      subscriber.completeError(LoadCancelled());
      if (_subscribers.isEmpty) {
        onLastSubscriberCancelled();
        cancellation.cancel();
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
  NativeImageBridge? nativeBridge,
  LoadCancellation? cancellation,
}) async {
  cancellation?.throwIfCancelled();
  var sourceBytes = bytes;
  if (!fullScreen &&
      (nativeBridge != null || Platform.isAndroid || Platform.isIOS)) {
    try {
      sourceBytes =
          (await (nativeBridge ?? NativeImageBridge()).decodeDownsampled(
            bytes: bytes,
            maxWidth: 400,
            maxHeight: 400,
            format: 'jpeg',
            cancellation: cancellation,
          )).bytes;
    } on LoadCancelled {
      rethrow;
    } catch (_) {
      // A channel failure does not make valid compressed source bytes corrupt.
      sourceBytes = bytes;
    }
  }
  cancellation?.throwIfCancelled();
  final codec = await ui.instantiateImageCodec(
    sourceBytes,
    targetWidth: fullScreen ? null : 400,
    allowUpscaling: false,
  );
  try {
    cancellation?.throwIfCancelled();
    final frame = await codec.getNextFrame();
    if (cancellation?.isCancelled ?? false) {
      frame.image.dispose();
      throw LoadCancelled();
    }
    return frame.image;
  } finally {
    codec.dispose();
  }
}
