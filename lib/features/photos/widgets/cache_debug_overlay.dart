import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/images/decoded_image_loader.dart';
import '../../../core/images/image_bytes_repository.dart';

class CacheDebugOverlay extends StatefulWidget {
  const CacheDebugOverlay({
    required this.loader,
    required this.onOpenDetails,
    super.key,
  });

  final DecodedImageLoader loader;
  final VoidCallback onOpenDetails;

  @override
  State<CacheDebugOverlay> createState() => _CacheDebugOverlayState();
}

class _CacheDebugOverlayState extends State<CacheDebugOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = widget.loader.memoryCache;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return Material(
      key: const ValueKey('cache-debug-panel'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: FutureBuilder<ImageBytesRepository>(
            future: widget.loader.repository,
            builder: (context, snapshot) {
              final repository = snapshot.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cache activity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Memory ${memory.sizeBytes} / ${memory.maxBytes} B',
                    style: textStyle,
                  ),
                  Text(
                    repository == null
                        ? 'Disk loading…'
                        : 'Disk ${repository.cache.sizeBytes} / '
                            '${repository.cache.maxBytes} B',
                    style: textStyle,
                  ),
                  Text('Evictions ${memory.evictionCount}', style: textStyle),
                  Text(
                    'Downloads ${repository?.activeDownloads ?? 0}  '
                    'Decodes ${widget.loader.activeDecodes}',
                    style: textStyle,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onOpenDetails,
                      child: const Text('Details / clear'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
