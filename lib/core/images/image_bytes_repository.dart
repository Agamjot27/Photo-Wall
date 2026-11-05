import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'disk_image_cache.dart';
import 'load_scheduler.dart';

typedef ImageFetcher = Future<Uint8List> Function(Uri url);

class ImageBytesRepository {
  ImageBytesRepository(this.cache, {ImageFetcher? fetch})
    : _fetchOverride = fetch;

  final DiskImageCache cache;
  final ImageFetcher? _fetchOverride;
  HttpClient? _client;
  int _activeDownloads = 0;
  int _cacheGeneration = 0;
  Future<void>? _clearPending;

  int get activeDownloads => _activeDownloads;

  void dispose() {
    _client?.close(force: true);
    _client = null;
  }

  Future<(Uint8List, bool)> load(
    String url, {
    bool admitToDisk = true,
    LoadCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final generation = _cacheGeneration;
    await _clearPending;
    final cached = await cache.read(url);
    cancellation?.throwIfCancelled();
    if (cached != null) return (cached, true);
    return (
      await _download(
        url,
        admitToDisk: admitToDisk,
        expectedGeneration: generation,
        cancellation: cancellation,
      ),
      false,
    );
  }

  Future<Uint8List> download(
    String url, {
    bool admitToDisk = true,
    LoadCancellation? cancellation,
  }) => _download(url, admitToDisk: admitToDisk, cancellation: cancellation);

  Future<Uint8List> _download(
    String url, {
    required bool admitToDisk,
    int? expectedGeneration,
    LoadCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final generation = expectedGeneration ?? _cacheGeneration;
    await _clearPending;
    cancellation?.throwIfCancelled();
    _activeDownloads++;
    late final Uint8List bytes;
    try {
      final uri = Uri.parse(url);
      bytes =
          await (_fetchOverride?.call(uri) ??
              fetchImageBytes(
                uri,
                client:
                    _client ??=
                        HttpClient()
                          ..connectionTimeout = const Duration(seconds: 10),
                cancellation: cancellation,
              ));
    } finally {
      _activeDownloads--;
    }
    cancellation?.throwIfCancelled();
    if (admitToDisk && generation == _cacheGeneration) {
      try {
        await cache.write(url, bytes);
      } on FileSystemException {
        // A full or unavailable cache cannot prevent displaying downloaded bytes.
      }
    }
    return bytes;
  }

  Future<void> invalidate(String url) => cache.invalidate(url);

  Future<void> clearDiskCache() async {
    _cacheGeneration++;
    final clear = cache.clear();
    _clearPending = clear;
    try {
      await clear;
    } finally {
      if (identical(_clearPending, clear)) _clearPending = null;
    }
  }
}

Future<Uint8List> fetchImageBytes(
  Uri url, {
  Duration timeout = const Duration(seconds: 30),
  LoadCancellation? cancellation,
  HttpClient? client,
}) async {
  cancellation?.throwIfCancelled();
  final ownsClient = client == null;
  final activeClient =
      client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));
  final result = Completer<Uint8List>();
  HttpClientRequest? pendingRequest;
  StreamSubscription<List<int>>? subscription;
  void fail(Object error, StackTrace stack) {
    if (!result.isCompleted) result.completeError(error, stack);
  }

  void abortTransport() {
    pendingRequest?.abort();
    final currentSubscription = subscription;
    if (currentSubscription != null) unawaited(currentSubscription.cancel());
  }

  final deadline = Timer(timeout, () {
    fail(
      TimeoutException('Image request timed out', timeout),
      StackTrace.current,
    );
    abortTransport();
  });
  if (cancellation != null) {
    unawaited(
      cancellation.whenCancelled.then((_) {
        fail(LoadCancelled(), StackTrace.current);
        abortTransport();
      }),
    );
  }

  unawaited(() async {
    try {
      pendingRequest = await activeClient.getUrl(url);
      if (result.isCompleted) {
        abortTransport();
        return;
      }
      cancellation?.throwIfCancelled();
      final response = await pendingRequest!.close();
      pendingRequest = null;
      if (result.isCompleted) {
        subscription = response.listen((_) {});
        await subscription!.cancel();
        return;
      }
      cancellation?.throwIfCancelled();
      if (response.statusCode != HttpStatus.ok) {
        subscription = response.listen((_) {});
        await subscription!.cancel();
        throw HttpException(
          'Image request failed: ${response.statusCode}',
          uri: url,
        );
      }
      const maximumBytes = 20 * 1024 * 1024;
      final builder = BytesBuilder(copy: false);
      subscription = response.listen(
        (chunk) {
          if (builder.length + chunk.length > maximumBytes) {
            fail(
              const FormatException('Image response exceeds 20 MiB'),
              StackTrace.current,
            );
            abortTransport();
            return;
          }
          builder.add(chunk);
        },
        onError: fail,
        onDone: () {
          if (builder.length == 0) {
            fail(
              const FormatException('Empty image response'),
              StackTrace.current,
            );
          } else if (!result.isCompleted) {
            result.complete(builder.takeBytes());
          }
        },
        cancelOnError: true,
      );
    } catch (error, stack) {
      fail(error, stack);
      abortTransport();
    }
  }());
  try {
    return await result.future;
  } finally {
    deadline.cancel();
    abortTransport();
    if (ownsClient) activeClient.close(force: true);
  }
}
