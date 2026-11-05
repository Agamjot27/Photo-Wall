import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/images/decoded_image_loader.dart';
import '../models/photo.dart';
import '../widgets/decoded_photo_image.dart';

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({
    required this.photo,
    required this.loader,
    super.key,
  });

  final Photo photo;
  final DecodedImageLoader loader;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        titleAlignment: AlignmentDirectional.centerStart,
        title: const Text('Photo Wall'),
        prefixes: [
          Tooltip(
            message: 'Back',
            child: SizedBox.square(
              dimension: 48,
              child: FHeaderAction.back(
                semanticsLabel: 'Back to photos',
                onPress: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: DecodedPhotoImage(
                  photo: photo,
                  fullScreen: true,
                  loader: loader.load,
                  requestFactory: loader.request,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Photo by',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            photo.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${photo.width} × ${photo.height}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
