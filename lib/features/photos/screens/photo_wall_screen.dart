import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../../../app/circle_theme.dart';
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
  final ScrollController _gridController = ScrollController();
  bool _showDiagnostics = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _gridController.addListener(_updateHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _gridController.hasClients) _updateHeader();
    });
  }

  void _updateHeader() {
    final isScrolled = _gridController.offset > 4;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }
  }

  void _scrollToTop() {
    if (!_gridController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _gridController.jumpTo(0);
      return;
    }
    final distance = _gridController.offset;
    final milliseconds = (240 + distance / 10).round().clamp(260, 650);
    unawaited(
      _gridController.animateTo(
        0,
        duration: Duration(milliseconds: milliseconds),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _openPhoto(Photo photo) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    unawaited(
      Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
          reverseTransitionDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  PhotoViewerScreen(photo: photo, loader: widget.loader),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final entrance = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: entrance,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(entrance),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

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
    final headerHeight = MediaQuery.paddingOf(context).top + 56;
    return FScaffold(
      childPad: false,
      child: Stack(
        children: [
          GridView.builder(
            key: const PageStorageKey<String>('photo-grid'),
            controller: _gridController,
            padding: EdgeInsets.fromLTRB(
              14,
              headerHeight + 4,
              14,
              MediaQuery.paddingOf(context).bottom + 88,
            ),
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
                    onTap: () => _openPhoto(photo),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              ),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: AnimatedContainer(
                    key: const ValueKey('gallery-header'),
                    duration: const Duration(milliseconds: 180),
                    height: headerHeight,
                    color: const Color(
                      0xFF1E2B37,
                    ).withValues(alpha: _isScrolled ? 0.28 : 0.90),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: CirclePalette.ink.withValues(
                                      alpha: 0.82,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'Photo Wall',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        color: CirclePalette.lime,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 23,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: CirclePalette.lime,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${widget.photos.length} photos',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: CirclePalette.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showDiagnostics)
            Positioned(
              left: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 84,
              child: CacheDebugOverlay(
                loader: widget.loader,
                onOpenDetails: _openDiagnostics,
              ),
            ),
          Positioned(
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: _GalleryDock(
              showingCache: _showDiagnostics,
              onScrollToTop: _scrollToTop,
              onToggleCache:
                  () => setState(() => _showDiagnostics = !_showDiagnostics),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryDock extends StatelessWidget {
  const _GalleryDock({
    required this.showingCache,
    required this.onScrollToTop,
    required this.onToggleCache,
  });

  final bool showingCache;
  final VoidCallback onScrollToTop;
  final VoidCallback onToggleCache;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CirclePalette.ink.withValues(alpha: 0.91),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: CirclePalette.lime.withValues(alpha: 0.4),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  key: const ValueKey('scroll-to-top-action'),
                  onPressed: onScrollToTop,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: const Text('Top'),
                ),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Colors.white24,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('cache-dock-action'),
                  onPressed: onToggleCache,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        showingCache ? CirclePalette.lime : Colors.white,
                  ),
                  icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                  label: const Text('Cache'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
