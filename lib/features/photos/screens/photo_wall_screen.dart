import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../models/photo_catalog.dart';
import '../widgets/photo_image.dart';

class PhotoWallScreen extends StatelessWidget {
  const PhotoWallScreen({
    this.photos = photoCatalog,
    this.imageProviderFactory = networkPhotoImageProvider,
    super.key,
  });

  final List<Photo> photos;
  final PhotoImageProviderFactory imageProviderFactory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Wall')),
      body: SafeArea(
        child: GridView.builder(
          key: const PageStorageKey<String>('photo-grid'),
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return ColoredBox(
              key: ValueKey<String>(photo.id),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: PhotoImage(
                photo: photo,
                imageProviderFactory: imageProviderFactory,
              ),
            );
          },
        ),
      ),
    );
  }
}
