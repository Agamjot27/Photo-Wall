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
class PhotoImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Image(
      image: imageProviderFactory(photo, fullScreen: fullScreen),
      fit: fullScreen ? BoxFit.contain : BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: photo.semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      },
    );
  }
}
