import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../models/photo.dart';
import '../widgets/decoded_photo_image.dart';
import '../widgets/photo_image.dart';

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({
    required this.photo,
    this.imageProviderFactory = networkPhotoImageProvider,
    this.decodedLoader,
    this.decodedRequestFactory,
    super.key,
  });

  final Photo photo;
  final PhotoImageProviderFactory imageProviderFactory;
  final DecodedPhotoLoader? decodedLoader;
  final DecodedPhotoRequestFactory? decodedRequestFactory;

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
        child:
            decodedLoader == null
                ? PhotoImage(
                  photo: photo,
                  fullScreen: true,
                  imageProviderFactory: imageProviderFactory,
                )
                : DecodedPhotoImage(
                  photo: photo,
                  fullScreen: true,
                  loader: decodedLoader!,
                  requestFactory: decodedRequestFactory,
                ),
      ),
    );
  }
}
