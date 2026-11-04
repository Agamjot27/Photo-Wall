import 'package:flutter/material.dart';

class PhotoWallScreen extends StatelessWidget {
  const PhotoWallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Wall')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Your photo collection starts here.'),
          ),
        ),
      ),
    );
  }
}
