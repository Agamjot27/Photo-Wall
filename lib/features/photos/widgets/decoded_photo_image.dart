import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/images/decoded_image_loader.dart';
import '../models/photo.dart';

typedef DecodedPhotoLoader =
    Future<ui.Image> Function(Photo photo, {required bool fullScreen});
typedef DecodedPhotoRequestFactory =
    ImageLoadRequest Function(Photo photo, {required bool fullScreen});

class DecodedPhotoImage extends StatefulWidget {
  const DecodedPhotoImage({
    required this.photo,
    required this.loader,
    this.requestFactory,
    this.fullScreen = false,
    super.key,
  });

  final Photo photo;
  final DecodedPhotoLoader loader;
  final DecodedPhotoRequestFactory? requestFactory;
  final bool fullScreen;

  @override
  State<DecodedPhotoImage> createState() => _DecodedPhotoImageState();
}

class _DecodedPhotoImageState extends State<DecodedPhotoImage> {
  ui.Image? _image;
  bool _failed = false;
  int _generation = 0;
  ImageLoadRequest? _activeRequest;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = _generation;
    try {
      final request = widget.requestFactory?.call(
        widget.photo,
        fullScreen: widget.fullScreen,
      );
      _activeRequest = request;
      final image =
          await (request?.future ??
              widget.loader(widget.photo, fullScreen: widget.fullScreen));
      if (identical(_activeRequest, request)) _activeRequest = null;
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    }
  }

  void _releaseAfterFrame(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  void didUpdateWidget(covariant DecodedPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo ||
        oldWidget.fullScreen != widget.fullScreen ||
        oldWidget.loader != widget.loader ||
        oldWidget.requestFactory != widget.requestFactory) {
      _generation++;
      _activeRequest?.cancel();
      _activeRequest = null;
      _releaseAfterFrame(_image);
      _image = null;
      _failed = false;
      unawaited(_load());
    }
  }

  void _retry() {
    _generation++;
    _activeRequest?.cancel();
    _activeRequest = null;
    _releaseAfterFrame(_image);
    setState(() {
      _image = null;
      _failed = false;
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _activeRequest?.cancel();
    _releaseAfterFrame(_image);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Tooltip(
          message: 'Photo failed to load. Retry',
          child: SizedBox.square(
            dimension: 48,
            child: FButton.icon(
              onPress: _retry,
              child: const Icon(FIcons.rotateCw),
            ),
          ),
        ),
      );
    }
    final image = _image;
    if (image == null) {
      return Center(
        child: FProgress.circularIcon(
          key: const ValueKey('photo-loading'),
          style: IconThemeData(
            size: 20,
            color: context.theme.colors.mutedForeground,
          ),
          semanticsLabel: 'Loading photo',
        ),
      );
    }
    return Semantics(
      image: true,
      label: widget.photo.semanticLabel,
      child: RawImage(
        image: image,
        fit: widget.fullScreen ? BoxFit.contain : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}
