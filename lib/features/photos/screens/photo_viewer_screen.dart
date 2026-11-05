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
        title: Text(photo.author, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        child: DecodedPhotoImage(
          photo: photo,
          fullScreen: true,
          loader: loader.load,
          requestFactory: loader.request,
        ),
      ),
    );
  }
}
