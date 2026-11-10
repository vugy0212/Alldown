import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/video_editor_service.dart';
import '../theme/app_colors.dart';

class VideoEditorModal extends ConsumerStatefulWidget {
  final MediaItem item;

  const VideoEditorModal({super.key, required this.item});

  static Future<void> show(BuildContext context, MediaItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoEditorModal(item: item),
    );
  }

  @override
  ConsumerState<VideoEditorModal> createState() => _VideoEditorModalState();
}

class _VideoEditorModalState extends ConsumerState<VideoEditorModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  double _totalDurationSec = 1.0;
  RangeValues _trimRange = const RangeValues(0.0, 1.0);

  // Crop & Manual Zoom / Pan
  String _selectedCrop = 'original'; // original, 1:1, 9:16, 16:9, 4:5
  double _zoom = 1.0; // 1.0x to 3.0x
  double _panX = 0.0; // -1.0 to 1.0
  double _panY = 0.0; // -1.0 to 1.0

  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = File(widget.item.localPath);
    if (!file.existsSync()) return;

    final ctrl = VideoPlayerController.file(file);
    _controller = ctrl;
    try {
      await ctrl.initialize();
      ctrl.addListener(_onPlayerTick);
      final durSec = ctrl.value.duration.inMilliseconds / 1000.0;
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _totalDurationSec = durSec > 0.5 ? durSec : 10.0;
          _trimRange = RangeValues(0.0, _totalDurationSec);
        });
      }
    } catch (_) {}
  }

  void _onPlayerTick() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;

    final posMs = _controller!.value.position.inMilliseconds;
    final startMs = (_trimRange.start * 1000).toInt();
    final endMs = (_trimRange.end * 1000).toInt();

    // Loop trimmed section: if position reaches or exceeds endMs, jump back to startMs
    if (_controller!.value.isPlaying && posMs >= endMs) {
      _controller!.seekTo(Duration(milliseconds: startMs));
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {});
    } else {
      final posMs = _controller!.value.position.inMilliseconds;
      final startMs = (_trimRange.start * 1000).toInt();
      final endMs = (_trimRange.end * 1000).toInt();

      // If outside trimmed range, start cleanly from trimmed start
      if (posMs < startMs || posMs >= endMs) {
        _controller!.seekTo(Duration(milliseconds: startMs)).then((_) {
          _controller!.play();
          setState(() {});
        });
      } else {
        _controller!.play();
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerTick);
    _controller?.dispose();
    super.dispose();
  }

  void _onRangeChanged(RangeValues values) {
    // Minimum 0.5s clip
    if (values.end - values.start < 0.5) return;

    setState(() {
      _trimRange = values;
    });

    // Pause and seek preview immediately to the chosen start point
    _controller?.pause();
    _controller?.seekTo(Duration(milliseconds: (values.start * 1000).toInt()));
  }

  void _resetZoomAndPan() {
    setState(() {
      _zoom = 1.0;
      _panX = 0.0;
      _panY = 0.0;
    });
  }

  Future<void> _exportVideo() async {
    if (_isProcessing) return;

    _controller?.pause();
    final startMs = (_trimRange.start * 1000).toInt();
    final endMs = (_trimRange.end * 1000).toInt();
    final isCustomFraming = _selectedCrop != 'original' || _zoom > 1.05 || _panX.abs() > 0.05 || _panY.abs() > 0.05;

    setState(() {
      _isProcessing = true;
      _processingMessage = isCustomFraming ? 'Izrezivanje kadra i obrada videa...' : 'Precizno rezanje videa...';
    });

    try {
      final configuredDir = ref.read(settingsProvider).downloadDirectory;
      final targetFolder = Directory('$configuredDir/Videos');
      if (!targetFolder.existsSync()) {
        targetFolder.createSync(recursive: true);
      }

      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${targetFolder.path}/Trimmed_$timeStamp.mp4';

      final success = await VideoEditorService.cropVideo(
        inputPath: widget.item.localPath,
        outputPath: outPath,
        startMs: startMs,
        endMs: endMs,
        cropRatio: _selectedCrop,
        zoom: _zoom,
        panX: _panX,
        panY: _panY,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success && File(outPath).existsSync()) {
        final fileSize = File(outPath).lengthSync();
        final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        final durSeconds = ((endMs - startMs) / 1000).round();
        final durStr = '${(durSeconds ~/ 60).toString().padLeft(2, '0')}:${(durSeconds % 60).toString().padLeft(2, '0')}';

        // Add to library
        final newItem = MediaItem(
          id: 'trim_$timeStamp',
          title: '${widget.item.title} (Trimmed)',
          channel: widget.item.channel,
          format: 'MP4',
          resolution: isCustomFraming ? '$_selectedCrop (${_zoom.toStringAsFixed(1)}x)' : widget.item.resolution,
          sizeFormatted: '$sizeMb MB',
          completedDateFormatted: 'Danas',
          duration: durStr,
          thumbnailUrl: widget.item.thumbnailUrl,
          localPath: outPath,
          isAudio: false,
          isVertical: _selectedCrop == '9:16',
          platform: widget.item.platform,
        );

        ref.read(mediaLibraryProvider.notifier).addItem(newItem);

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video uspješno izrezan i spremljen: ${newItem.title}'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Greška prilikom izrezivanja videa.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  Future<void> _exportGif() async {
    if (_isProcessing) return;

    _controller?.pause();
    final startMs = (_trimRange.start * 1000).toInt();
    final endMs = (_trimRange.end * 1000).toInt();

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Izrada optimiziranog animiranog GIF-a...';
    });

    try {
      final configuredDir = ref.read(settingsProvider).downloadDirectory;
      final targetFolder = Directory('$configuredDir/GIFs');
      if (!targetFolder.existsSync()) {
        targetFolder.createSync(recursive: true);
      }

      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${targetFolder.path}/Clip_$timeStamp.gif';

      final success = await VideoEditorService.createGif(
        inputPath: widget.item.localPath,
        outputPath: outPath,
        startMs: startMs,
        endMs: endMs,
        cropRatio: _selectedCrop,
        zoom: _zoom,
        panX: _panX,
        panY: _panY,
        fps: 10,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success && File(outPath).existsSync()) {
        final fileSize = File(outPath).lengthSync();
        final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        final durSeconds = ((endMs - startMs) / 1000).round();
        final durStr = '${(durSeconds ~/ 60).toString().padLeft(2, '0')}:${(durSeconds % 60).toString().padLeft(2, '0')}';

        // Add to library
        final newItem = MediaItem(
          id: 'gif_$timeStamp',
          title: '${widget.item.title} (GIF)',
          channel: widget.item.channel,
          format: 'GIF',
          resolution: 'Animated GIF',
          sizeFormatted: '$sizeMb MB',
          completedDateFormatted: 'Danas',
          duration: durStr,
          thumbnailUrl: widget.item.thumbnailUrl,
          localPath: outPath,
          isAudio: false,
          isVertical: _selectedCrop == '9:16',
          platform: widget.item.platform,
        );

        ref.read(mediaLibraryProvider.notifier).addItem(newItem);

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Animirani GIF uspješno kreiran: ${newItem.title}'),
            backgroundColor: AppColors.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Greška prilikom izrade GIF-a.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  double _getPreviewAspectRatio() {
    switch (_selectedCrop) {
      case '1:1':
        return 1.0;
      case '9:16':
        return 9.0 / 16.0;
      case '16:9':
        return 16.0 / 9.0;
      case '4:5':
        return 4.0 / 5.0;
      case 'original':
      default:
        if (_controller != null && _controller!.value.isInitialized) {
          final r = _controller!.value.aspectRatio;
          return r > 0.2 ? r : (16.0 / 9.0);
        }
        return 16.0 / 9.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFormatted = VideoEditorService.formatMs((_trimRange.start * 1000).toInt());
    final endFormatted = VideoEditorService.formatMs((_trimRange.end * 1000).toInt());
    final clipDurationSec = (_trimRange.end - _trimRange.start).toStringAsFixed(1);
    final isPlaying = _controller?.value.isPlaying ?? false;
    final previewAspect = _getPreviewAspectRatio();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Drag Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.content_cut_rounded, size: 16, color: AppColors.onPrimaryContainer),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Video Studio • Trim, Crop & GIF',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.onSurfaceVariant,
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.stroke, height: 1),

          // Scrollable Editor Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Player Preview with live Crop & Zoom framing
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 230,
                      color: Colors.black,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isInitialized && _controller != null)
                            // Live Crop Aspect Ratio Box
                            AspectRatio(
                              aspectRatio: previewAspect,
                              child: ClipRect(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Live visual translation based on panX and panY
                                    final maxOffsetX = constraints.maxWidth * (_zoom - 1.0) / 2;
                                    final maxOffsetY = constraints.maxHeight * (_zoom - 1.0) / 2;
                                    final dx = -_panX * maxOffsetX;
                                    final dy = _panY * maxOffsetY;

                                    return Transform.translate(
                                      offset: Offset(dx, dy),
                                      child: Transform.scale(
                                        scale: _zoom,
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: _controller!.value.size.width > 0
                                                ? _controller!.value.size.width
                                                : 1920,
                                            height: _controller!.value.size.height > 0
                                                ? _controller!.value.size.height
                                                : 1080,
                                            child: VideoPlayer(_controller!),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

                          // Play / Pause Overlay Button
                          if (_isInitialized && _controller != null)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: _togglePlayPause,
                                ),
                              ),
                            ),

                          // Crop Aspect Ratio & Zoom Visual Indicator Pill
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.crop_rounded, size: 12, color: AppColors.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_selectedCrop == 'original' ? 'Original' : _selectedCrop} • ${_zoom.toStringAsFixed(1)}x',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Playback Trim Loop indicator pill
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${clipDurationSec}s Isječak',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Trim Range Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vremenski isječak (Trim)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$startFormatted - $endFormatted (${clipDurationSec}s)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RangeSlider(
                    values: _trimRange,
                    min: 0.0,
                    max: _totalDurationSec,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.surfaceContainerHighest,
                    onChanged: _isProcessing ? null : _onRangeChanged,
                  ),
                  const SizedBox(height: 14),

                  // 2. Crop Aspect Ratio Section
                  const Text(
                    'Omjer kadra (Aspect Ratio)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCropChip('original', 'Original', Icons.aspect_ratio_rounded),
                        const SizedBox(width: 8),
                        _buildCropChip('1:1', '1:1 Kvadrat', Icons.crop_square_rounded),
                        const SizedBox(width: 8),
                        _buildCropChip('9:16', '9:16 Reels/TikTok', Icons.stay_current_portrait_rounded),
                        const SizedBox(width: 8),
                        _buildCropChip('16:9', '16:9 Široki', Icons.stay_current_landscape_rounded),
                        const SizedBox(width: 8),
                        _buildCropChip('4:5', '4:5 Portret', Icons.crop_portrait_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Manual Crop & Zoom Section (Zoom In / Zoom Out + Pan)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                const Text(
                                  'Ručno podešavanje kadra (Zoom & Pan)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            if (_zoom > 1.05 || _panX.abs() > 0.05 || _panY.abs() > 0.05)
                              InkWell(
                                onTap: _resetZoomAndPan,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Reset',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Zoom Slider
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                              color: AppColors.onSurfaceVariant,
                              onPressed: _zoom > 1.0
                                  ? () => setState(() => _zoom = (_zoom - 0.2).clamp(1.0, 3.0))
                                  : null,
                            ),
                            Expanded(
                              child: Slider(
                                value: _zoom,
                                min: 1.0,
                                max: 3.0,
                                divisions: 20,
                                activeColor: AppColors.secondary,
                                inactiveColor: AppColors.surfaceContainerHighest,
                                label: '${_zoom.toStringAsFixed(1)}x',
                                onChanged: _isProcessing
                                    ? null
                                    : (val) {
                                        setState(() => _zoom = val);
                                      },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                              color: AppColors.onSurfaceVariant,
                              onPressed: _zoom < 3.0
                                  ? () => setState(() => _zoom = (_zoom + 0.2).clamp(1.0, 3.0))
                                  : null,
                            ),
                            Container(
                              width: 44,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_zoom.toStringAsFixed(1)}x',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Pan Controls (Visible when zoomed or cropped)
                        if (_zoom > 1.05 || _selectedCrop != 'original') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.open_with_rounded, size: 14, color: AppColors.onSurfaceVariant),
                              const SizedBox(width: 6),
                              const Text(
                                'Pozicija kadra (Horizontalno / Vertikalno)',
                                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('X:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                              Expanded(
                                child: Slider(
                                  value: _panX,
                                  min: -1.0,
                                  max: 1.0,
                                  divisions: 20,
                                  activeColor: AppColors.primary,
                                  inactiveColor: AppColors.surfaceContainerHighest,
                                  onChanged: _isProcessing
                                      ? null
                                      : (val) {
                                          setState(() => _panX = val);
                                        },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Y:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                              Expanded(
                                child: Slider(
                                  value: _panY,
                                  min: -1.0,
                                  max: 1.0,
                                  divisions: 20,
                                  activeColor: AppColors.primary,
                                  inactiveColor: AppColors.surfaceContainerHighest,
                                  onChanged: _isProcessing
                                      ? null
                                      : (val) {
                                          setState(() => _panY = val);
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Processing State Overlay
                  if (_isProcessing) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _processingMessage,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons (Save Video vs Make GIF)
                  Row(
                    children: [
                      // Save Trimmed/Cropped Video
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryAccent.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isProcessing ? null : _exportVideo,
                            icon: const Icon(Icons.content_cut_rounded, size: 18, color: AppColors.onPrimaryContainer),
                            label: const Text(
                              'Spremi Video',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Create Animated GIF
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.secondary, width: 1.5),
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isProcessing ? null : _exportGif,
                            icon: const Icon(Icons.gif_rounded, size: 22, color: AppColors.secondary),
                            label: const Text(
                              'Izradi GIF',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropChip(String value, String label, IconData icon) {
    final selected = _selectedCrop == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? AppColors.onPrimaryContainer : AppColors.outline,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceContainerLow,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
      ),
      side: BorderSide(
        color: selected ? AppColors.primaryAccent : AppColors.stroke,
        width: selected ? 1.5 : 1,
      ),
      onSelected: _isProcessing
          ? null
          : (val) {
              if (val) {
                setState(() => _selectedCrop = value);
              }
            },
    );
  }
}
