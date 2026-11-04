import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:path_provider/path_provider.dart';

import '../core/images/disk_image_cache.dart';
import '../core/images/decoded_image_loader.dart';
import '../core/images/image_bytes_repository.dart';
import '../core/images/memory_image_cache.dart';
import '../features/photos/models/photo.dart';
import '../features/photos/screens/photo_wall_screen.dart';
import '../features/photos/widgets/photo_image.dart';

class PhotoWallApp extends StatefulWidget {
  const PhotoWallApp({
    this.themeMode = ThemeMode.system,
    this.imageProviderFactory,
    super.key,
  });

  final ThemeMode themeMode;
  final PhotoImageProviderFactory? imageProviderFactory;

  @override
  State<PhotoWallApp> createState() => _PhotoWallAppState();
}

class _PhotoWallAppState extends State<PhotoWallApp> {
  late final Future<ImageBytesRepository> _repository = _openRepository();
  late final DecodedImageLoader _decodedLoader = DecodedImageLoader(
    repository: _repository,
    memoryCache: MemoryImageCache(),
  );

  Future<ImageBytesRepository> _openRepository() async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}photo_wall_images',
    );
    final cache = DiskImageCache(directory);
    await cache.initialize();
    return ImageBytesRepository(cache);
  }

  ImageProvider<Object> _imageProvider(
    Photo photo, {
    required bool fullScreen,
  }) {
    return DiskCachedImageProvider(
      url: fullScreen ? photo.fullScreenUrl : photo.thumbnailUrl,
      repository: _repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Wall',
      debugShowCheckedModeBanner: false,
      themeMode: widget.themeMode,
      theme: FThemes.zinc.light.toApproximateMaterialTheme(),
      darkTheme: FThemes.zinc.dark.toApproximateMaterialTheme(),
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      builder:
          (context, child) => FTheme(
            data:
                Theme.of(context).brightness == Brightness.dark
                    ? FThemes.zinc.dark
                    : FThemes.zinc.light,
            child: child!,
          ),
      home: PhotoWallScreen(
        imageProviderFactory: widget.imageProviderFactory ?? _imageProvider,
        decodedLoader:
            widget.imageProviderFactory == null ? _decodedLoader.load : null,
        decodedRequestFactory:
            widget.imageProviderFactory == null ? _decodedLoader.request : null,
      ),
    );
  }
}
