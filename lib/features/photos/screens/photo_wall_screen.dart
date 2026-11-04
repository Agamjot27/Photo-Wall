import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

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
    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const Text('Photo Wall'),
        suffixes: [
          Text(
            '${photos.length} photos',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GridView.builder(
          key: const PageStorageKey<String>('photo-grid'),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return Semantics(
              key: ValueKey<String>(photo.id),
              button: true,
              label: 'Open ${photo.semanticLabel.toLowerCase()}',
              child: Material(
                color: context.theme.colors.muted,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
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
