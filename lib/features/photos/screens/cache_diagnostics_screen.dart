import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/images/decoded_image_loader.dart';
import '../../../core/images/image_bytes_repository.dart';
import '../../../core/images/native_image_bridge.dart';

class CacheDiagnosticsScreen extends StatefulWidget {
  const CacheDiagnosticsScreen({
    required this.loader,
    required this.repository,
    super.key,
  });

  final DecodedImageLoader loader;
  final Future<ImageBytesRepository> repository;

  @override
  State<CacheDiagnosticsScreen> createState() => _CacheDiagnosticsScreenState();
}

class _CacheDiagnosticsScreenState extends State<CacheDiagnosticsScreen> {
  Timer? _timer;
  Timer? _nativeTimer;
  final NativeImageBridge _nativeBridge = NativeImageBridge();
  NativeMemoryInfo? _nativeInfo;
  bool _nativeInfoUnavailable = false;
  bool _readingNativeInfo = false;
  bool _clearing = false;
  String? _clearError;

  Future<void> _refreshNativeInfo() async {
    if (_readingNativeInfo) return;
    _readingNativeInfo = true;
    try {
      final info = await _nativeBridge.getMemoryInfo();
      if (mounted) {
        setState(() {
          _nativeInfo = info;
          _nativeInfoUnavailable = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nativeInfoUnavailable = true);
    } finally {
      _readingNativeInfo = false;
    }
  }

  Future<void> _clearCaches() async {
    if (_clearing) return;
    setState(() {
      _clearing = true;
      _clearError = null;
    });
    try {
      await widget.loader.clearCaches();
    } catch (_) {
      if (mounted) {
        setState(() => _clearError = 'Could not clear the caches. Try again.');
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
    if (Platform.isAndroid) {
      unawaited(_refreshNativeInfo());
      _nativeTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_refreshNativeInfo()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nativeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = widget.loader.memoryCache;
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('Cache diagnostics'),
        titleAlignment: AlignmentDirectional.centerStart,
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
      child: FutureBuilder<ImageBytesRepository>(
        future: widget.repository,
        builder: (context, snapshot) {
          final repository = snapshot.data;
          if (repository == null) {
            if (snapshot.hasError) {
              return const Center(child: Text('Cache diagnostics unavailable'));
            }
            return const Center(child: FProgress.circularIcon());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Live cache activity', style: context.theme.typography.lg),
              const SizedBox(height: 8),
              Text(
                'Image bytes held by this app. Active photos and temporary '
                'decode buffers are outside these cache limits.',
                style: context.theme.typography.sm,
              ),
              const SizedBox(height: 16),
              _Metric(
                'Decoded memory cache',
                '${memory.sizeBytes} B / ${memory.maxBytes} B',
              ),
              _Metric(
                'Disk cache',
                '${repository.cache.sizeBytes} B / ${repository.cache.maxBytes} B',
              ),
              _Metric('Memory evictions', '${memory.evictionCount}'),
              _Metric('Ongoing downloads', '${repository.activeDownloads}'),
              _Metric('Ongoing decodes', '${widget.loader.activeDecodes}'),
              _Metric(
                'Queued image jobs',
                '${widget.loader.scheduler.queuedCount}',
              ),
              if (Platform.isAndroid) ...[
                const Divider(height: 32),
                Text('Android memory', style: context.theme.typography.lg),
                if (_nativeInfo != null) ...[
                  _Metric('Available', '${_nativeInfo!.availMemBytes} B'),
                  _Metric('Total', '${_nativeInfo!.totalMemBytes} B'),
                  _Metric(
                    'Low-memory threshold',
                    '${_nativeInfo!.thresholdBytes} B',
                  ),
                  _Metric('Low memory', _nativeInfo!.lowMemory ? 'Yes' : 'No'),
                ] else if (_nativeInfoUnavailable)
                  const Text('Android memory information unavailable'),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _clearing ? null : _clearCaches,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(_clearing ? 'Clearing caches…' : 'Clear caches'),
              ),
              const SizedBox(height: 8),
              Text(
                'Clears decoded thumbnails and downloaded image files. Visible '
                'photos stay open; images load again when needed.',
                style: context.theme.typography.sm,
              ),
              if (_clearError != null) ...[
                const SizedBox(height: 8),
                Text(_clearError!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: context.theme.typography.sm),
        ],
      ),
    );
  }
}
