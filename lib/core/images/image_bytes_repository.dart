import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'disk_image_cache.dart';

typedef ImageFetcher = Future<Uint8List> Function(Uri url);

class ImageBytesRepository {
  ImageBytesRepository(this.cache, {ImageFetcher? fetch})
    : _fetch = fetch ?? fetchImageBytes;

  final DiskImageCache cache;
  final ImageFetcher _fetch;
  int _activeDownloads = 0;
  int _cacheGeneration = 0;
  Future<void>? _clearPending;

  int get activeDownloads => _activeDownloads;

  Future<(Uint8List, bool)> load(String url, {bool admitToDisk = true}) async {
    final generation = _cacheGeneration;
    await _clearPending;
    final cached = await cache.read(url);
    if (cached != null) return (cached, true);
    return (
      await _download(
        url,
        admitToDisk: admitToDisk,
        expectedGeneration: generation,
      ),
      false,
    );
  }

  Future<Uint8List> download(String url, {bool admitToDisk = true}) =>
      _download(url, admitToDisk: admitToDisk);

  Future<Uint8List> _download(
    String url, {
    required bool admitToDisk,
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? _cacheGeneration;
    await _clearPending;
    _activeDownloads++;
    late final Uint8List bytes;
    try {
      bytes = await _fetch(Uri.parse(url));
    } finally {
      _activeDownloads--;
    }
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
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await (() async {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Image request failed: ${response.statusCode}',
          uri: url,
        );
      }
      const maximumBytes = 20 * 1024 * 1024;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (builder.length + chunk.length > maximumBytes) {
          throw const FormatException('Image response exceeds 20 MiB');
        }
        builder.add(chunk);
      }
      if (builder.length == 0) {
        throw const FormatException('Empty image response');
      }
      return builder.takeBytes();
    })().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}

/// Phase 3 still uses Flutter's decoded ImageCache; Phase 4 replaces that layer.
class DiskCachedImageProvider extends ImageProvider<String> {
  const DiskCachedImageProvider({required this.url, required this.repository});

  final String url;
  final Future<ImageBytesRepository> repository;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(url);

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: _loadCodec(decode), scale: 1);
  }

  Future<Codec> _loadCodec(ImageDecoderCallback decode) async {
    final source = await repository;
    final (bytes, fromDisk) = await source.load(url);
    try {
      return await decode(await ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      if (!fromDisk) rethrow;
      await source.invalidate(url);
      return decode(
        await ImmutableBuffer.fromUint8List(await source.download(url)),
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DiskCachedImageProvider &&
      other.url == url &&
      identical(other.repository, repository);

  @override
  int get hashCode => Object.hash(url, identityHashCode(repository));
}
