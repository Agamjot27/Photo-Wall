import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/images/decoded_image_loader.dart';
import '../models/photo.dart';
import '../models/photo_catalog.dart';
import '../widgets/cache_debug_overlay.dart';
import '../widgets/decoded_photo_image.dart';
import 'cache_diagnostics_screen.dart';
import 'photo_viewer_screen.dart';

class PhotoWallScreen extends StatefulWidget {
  const PhotoWallScreen({
    required this.loader,
    this.photos = photoCatalog,
    super.key,
  });

  final DecodedImageLoader loader;
  final List<Photo> photos;

  @override
  State<PhotoWallScreen> createState() => _PhotoWallScreenState();
}

class _PhotoWallScreenState extends State<PhotoWallScreen> {
  bool _showDiagnostics = false;

  void _openDiagnostics() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (context) => CacheDiagnosticsScreen(
                loader: widget.loader,
                repository: widget.loader.repository,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const Text('Photo Wall'),
        suffixes: [
          FHeaderAction(
            icon: const Icon(FIcons.activity),
            semanticsLabel:
                _showDiagnostics
                    ? 'Hide cache diagnostics'
                    : 'Show cache diagnostics',
            onPress: () => setState(() => _showDiagnostics = !_showDiagnostics),
          ),
          Text(
            '${widget.photos.length} photos',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            GridView.builder(
              key: const PageStorageKey<String>('photo-grid'),
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return Semantics(
                  key: ValueKey<String>(photo.id),
                  button: true,
                  label: 'Open ${photo.semanticLabel.toLowerCase()}',
                  child: Material(
                    color: context.theme.colors.muted,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap:
                          () => unawaited(
                            Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder:
                                    (context) => PhotoViewerScreen(
                                      photo: photo,
                                      loader: widget.loader,
                                    ),
                              ),
                            ),
                          ),
                      child: DecodedPhotoImage(
                        photo: photo,
                        loader: widget.loader.load,
                        requestFactory: widget.loader.request,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_showDiagnostics)
              Positioned(
                left: 12,
                bottom: 12,
                child: CacheDebugOverlay(
                  loader: widget.loader,
                  onOpenDetails: _openDiagnostics,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
