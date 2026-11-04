import 'package:flutter/material.dart';

import '../models/photo.dart';

typedef PhotoImageProviderFactory =
    ImageProvider<Object> Function(Photo photo, {required bool fullScreen});

ImageProvider<Object> networkPhotoImageProvider(
  Photo photo, {
  required bool fullScreen,
}) {
  return NetworkImage(fullScreen ? photo.fullScreenUrl : photo.thumbnailUrl);
}

/// Temporary framework image loading, replaced by the custom pipeline in Phase 4.
class PhotoImage extends StatefulWidget {
  const PhotoImage({
    required this.photo,
    this.fullScreen = false,
    this.imageProviderFactory = networkPhotoImageProvider,
    super.key,
  });

  final Photo photo;
  final bool fullScreen;
  final PhotoImageProviderFactory imageProviderFactory;

  @override
  State<PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<PhotoImage> {
  late ImageProvider<Object> _provider;
  int _generation = 0;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _provider = _createProvider();
  }

  ImageProvider<Object> _createProvider() =>
      widget.imageProviderFactory(widget.photo, fullScreen: widget.fullScreen);

  @override
  void didUpdateWidget(covariant PhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo ||
        oldWidget.fullScreen != widget.fullScreen ||
        oldWidget.imageProviderFactory != widget.imageProviderFactory) {
      _generation++;
      _retrying = false;
      _provider = _createProvider();
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    final generation = _generation;
    setState(() => _retrying = true);
    try {
      await _provider.evict();
    } catch (_) {
      // Keep the existing error control usable if cache eviction itself fails.
      if (mounted && generation == _generation) {
        setState(() => _retrying = false);
      }
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _generation++;
      _retrying = false;
      _provider = _createProvider();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      key: ValueKey((widget.photo.id, widget.fullScreen, _generation)),
      image: _provider,
      fit: widget.fullScreen ? BoxFit.contain : BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: widget.photo.semanticLabel,
      gaplessPlayback: false,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Loading photo',
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: IconButton(
            tooltip: 'Photo failed to load. Retry',
            onPressed: _retrying ? null : _retry,
            icon: const Icon(Icons.refresh),
          ),
        );
      },
    );
  }
}
