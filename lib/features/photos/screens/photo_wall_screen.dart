import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../models/photo_catalog.dart';
import '../widgets/photo_image.dart';
import 'photo_viewer_screen.dart';

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
            return Semantics(
              key: ValueKey<String>(photo.id),
              button: true,
              label: 'Open ${photo.semanticLabel.toLowerCase()}',
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder:
                            (context) => PhotoViewerScreen(
                              photo: photo,
                              imageProviderFactory: imageProviderFactory,
                            ),
                      ),
                    );
                  },
                  child: PhotoImage(
                    photo: photo,
                    imageProviderFactory: imageProviderFactory,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
