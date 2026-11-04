import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../features/photos/screens/photo_wall_screen.dart';
import '../features/photos/widgets/photo_image.dart';

class PhotoWallApp extends StatelessWidget {
  const PhotoWallApp({
    this.themeMode = ThemeMode.system,
    this.imageProviderFactory = networkPhotoImageProvider,
    super.key,
  });

  final ThemeMode themeMode;
  final PhotoImageProviderFactory imageProviderFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Wall',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
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
      home: PhotoWallScreen(imageProviderFactory: imageProviderFactory),
    );
  }
}
