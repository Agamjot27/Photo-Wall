import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../widgets/photo_image.dart';

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({
    required this.photo,
    this.imageProviderFactory = networkPhotoImageProvider,
    super.key,
  });

  final Photo photo;
  final PhotoImageProviderFactory imageProviderFactory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(photo.author),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: PhotoImage(
          photo: photo,
          fullScreen: true,
          imageProviderFactory: imageProviderFactory,
        ),
      ),
    );
  }
}
