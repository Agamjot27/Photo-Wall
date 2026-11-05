import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:path_provider/path_provider.dart';

import '../core/images/disk_image_cache.dart';
import '../core/images/decoded_image_loader.dart';
import '../core/images/image_bytes_repository.dart';
import '../core/images/memory_image_cache.dart';
import '../core/images/memory_pressure_observer.dart';
import '../features/photos/screens/photo_wall_screen.dart';

class PhotoWallApp extends StatefulWidget {
  const PhotoWallApp({
    this.themeMode = ThemeMode.system,
    this.loader,
    super.key,
  });

  final ThemeMode themeMode;
  final DecodedImageLoader? loader;

  @override
  State<PhotoWallApp> createState() => _PhotoWallAppState();
}

class _PhotoWallAppState extends State<PhotoWallApp> {
  late final DecodedImageLoader _loader =
      widget.loader ??
      DecodedImageLoader(
        repository: _openRepository(),
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
            child: MemoryPressureObserver(
              onPressure: _loader.handleMemoryPressure,
              onBackground:
                  () => unawaited(
                    _loader.repository.then<void>(
                      (repository) => repository.cache.flushAccesses(),
                      onError: (Object _, StackTrace __) {},
                    ),
                  ),
              child: child!,
            ),
          ),
      home: PhotoWallScreen(loader: _loader),
    );
  }

  @override
  void dispose() {
    _loader.memoryCache.clear();
    unawaited(
      _loader.repository.then<void>((repository) async {
        try {
          await repository.cache.flushAccesses();
        } finally {
          repository.dispose();
        }
      }, onError: (Object _, StackTrace __) {}),
    );
    super.dispose();
  }
}
