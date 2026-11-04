import 'package:flutter/material.dart';

import '../features/photos/screens/photo_wall_screen.dart';

class PhotoWallApp extends StatelessWidget {
  const PhotoWallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Wall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315C52)),
        useMaterial3: true,
      ),
      home: const PhotoWallScreen(),
    );
  }
}
