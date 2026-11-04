import 'dart:collection';
import 'dart:ui' as ui;

/// Owns one disposable handle per cached decoded image.
class MemoryImageCache {
  MemoryImageCache({this.maxBytes = 32 * 1024 * 1024});

  final int maxBytes;
  final LinkedHashMap<String, ui.Image> _images = LinkedHashMap();
  int _bytes = 0;
  int _evictions = 0;

  int get sizeBytes => _bytes;
  int get evictionCount => _evictions;
  int get length => _images.length;

  ui.Image? get(String key) {
    final image = _images.remove(key);
    if (image == null) return null;
    _images[key] = image;
    return image.clone();
  }

  /// Takes ownership of [image]. Returns a separate handle owned by the caller.
  ui.Image admit(String key, ui.Image image) {
    final old = _images.remove(key);
    if (old != null) {
      _bytes -= _sizeOf(old);
      old.dispose();
    }
    final size = _sizeOf(image);
    if (size > maxBytes) return image;
    while (_bytes + size > maxBytes && _images.isNotEmpty) {
      final oldest = _images.keys.first;
      final evicted = _images.remove(oldest)!;
      _bytes -= _sizeOf(evicted);
      evicted.dispose();
      _evictions++;
    }
    _images[key] = image;
    _bytes += size;
    return image.clone();
  }

  /// Releases cache-owned handles; active widget clones remain valid.
  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _bytes = 0;
  }

  static int _sizeOf(ui.Image image) => image.width * image.height * 4;
}
