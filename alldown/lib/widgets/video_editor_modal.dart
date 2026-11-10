import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
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
  double _panX = 0.0; // -1.0 to 1.0 (0.0 is center)
  double _panY = 0.0; // -1.0 to 1.0 (0.0 is center)

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
    if (values.end - values.start < 0.5) return;

    setState(() {
      _trimRange = values;
    });

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
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetFolder = Directory('${appDocDir.path}/AllDown/Videos');
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

        // Copy to public gallery folder (Movies/AllDown) once so Samsung Gallery displays it without duplication
        String savedPath = outPath;
        try {
          final moviesDir = Directory('/storage/emulated/0/Movies/AllDown');
          if (!moviesDir.existsSync()) moviesDir.createSync(recursive: true);
          final pubFile = File('${moviesDir.path}/Trimmed_$timeStamp.mp4');
          File(outPath).copySync(pubFile.path);
          savedPath = pubFile.path;
          VideoEditorService.scanMediaFile(path: savedPath, mimeType: 'video/mp4');
        } catch (_) {}

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
          localPath: savedPath,
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
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetFolder = Directory('${appDocDir.path}/AllDown/GIFs');
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

        // Copy to public gallery folder (Pictures/AllDown) once so Samsung Gallery displays it without duplication
        String savedPath = outPath;
        try {
          final picturesDir = Directory('/storage/emulated/0/Pictures/AllDown');
          if (!picturesDir.existsSync()) picturesDir.createSync(recursive: true);
          final pubFile = File('${picturesDir.path}/Clip_$timeStamp.gif');
          File(outPath).copySync(pubFile.path);
          savedPath = pubFile.path;
          VideoEditorService.scanMediaFile(path: savedPath, mimeType: 'image/gif');
        } catch (_) {}

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
          localPath: savedPath,
          isAudio: false,
          isVertical: _selectedCrop == '9:16',
          platform: widget.item.platform,
        );

        ref.read(mediaLibraryProvider.notifier).addItem(newItem);

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Animirani GIF spremljen u Galeriju i Biblioteku: ${newItem.title}'),
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

  @override
  Widget build(BuildContext context) {
    final startFormatted = VideoEditorService.formatMs((_trimRange.start * 1000).toInt());
    final endFormatted = VideoEditorService.formatMs((_trimRange.end * 1000).toInt());
    final clipDurationSec = (_trimRange.end - _trimRange.start).toStringAsFixed(1);
    final isPlaying = _controller?.value.isPlaying ?? false;
    final previewAspect = _getPreviewAspectRatio();
    final bottomNavPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Drag Handle & Title
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
                      child: Icon(Icons.content_cut_rounded, size: 16, color: AppColors.onPrimaryContainer),
                    ),
                    const SizedBox(width: 8),
                    Text(
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
          Divider(color: AppColors.stroke, height: 1),

          // Scrollable Editor Controls
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Player Preview Box with live Aspect Ratio & Interactive Gesture Pan
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
                                    final boxW = constraints.maxWidth;
                                    final boxH = constraints.maxHeight;

                                    final videoW = _controller!.value.size.width > 0 ? _controller!.value.size.width : 16.0;
                                    final videoH = _controller!.value.size.height > 0 ? _controller!.value.size.height : 9.0;
                                    final videoAspect = videoW / videoH;

                                    // 1. Base dimensions to cover the box according to aspect ratios
                                    final double baseW;
                                    final double baseH;
                                    if (videoAspect > previewAspect) {
                                      baseH = boxH;
                                      baseW = boxH * videoAspect;
                                    } else {
                                      baseW = boxW;
                                      baseH = boxW / videoAspect;
                                    }

                                    // 2. Rendered dimensions with zoom
                                    final renderedW = baseW * _zoom;
                                    final renderedH = baseH * _zoom;

                                    final maxDx = math.max(0.0, (renderedW - boxW) / 2);
                                    final maxDy = math.max(0.0, (renderedH - boxH) / 2);

                                    final pixelX = -_panX * maxDx;
                                    final pixelY = _panY * maxDy;

                                    return GestureDetector(
                                      onPanUpdate: _isProcessing
                                          ? null
                                          : (details) {
                                              if (maxDx <= 0 && maxDy <= 0) return;
                                              setState(() {
                                                if (maxDx > 0) {
                                                  _panX = (_panX - (details.delta.dx / maxDx)).clamp(-1.0, 1.0);
                                                }
                                                if (maxDy > 0) {
                                                  _panY = (_panY + (details.delta.dy / maxDy)).clamp(-1.0, 1.0);
                                                }
                                              });
                                            },
                                      child: Center(
                                        child: Transform.translate(
                                          offset: Offset(pixelX, pixelY),
                                          child: Transform.scale(
                                            scale: _zoom,
                                            child: SizedBox(
                                              width: baseW,
                                              height: baseH,
                                              child: FittedBox(
                                                fit: BoxFit.cover,
                                                child: SizedBox(
                                                  width: videoW,
                                                  height: videoH,
                                                  child: VideoPlayer(_controller!),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            Center(child: CircularProgressIndicator(color: AppColors.primary)),

                          // Play / Pause Overlay Button
                          if (_isInitialized && _controller != null)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
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
                                  Icon(Icons.crop_rounded, size: 12, color: AppColors.secondary),
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

                          // Interactive Gesture Hint Overlay
                          if (_zoom > 1.05 || _selectedCrop != 'original')
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app_rounded, size: 12, color: AppColors.onSurfaceVariant),
                                    SizedBox(width: 4),
                                    Text(
                                      'Povucite prstom za pomak kadra',
                                      style: TextStyle(fontSize: 10, color: Colors.white70),
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
                      Expanded(
                        child: Text(
                          'Vremenski isječak (Trim)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$startFormatted - $endFormatted (${clipDurationSec}s)',
                          style: TextStyle(
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
                  Text(
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

                  // 3. Manual Crop & Zoom Section (Zoom In / Zoom Out + Pan Controls)
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
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.secondary),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Ručno podešavanje kadra',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
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
                                  child: Text(
                                    'Resetiraj',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Zoom Slider Row
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
                            SizedBox(
                              width: 42,
                              child: Text(
                                '${_zoom.toStringAsFixed(1)}x',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Pan Controls: Horizontal & Vertical Sliders with zero overflow risk
                        if (_zoom > 1.05 || _selectedCrop != 'original') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.open_with_rounded, size: 14, color: AppColors.onSurfaceVariant),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Pozicija kadra (povucite prstom po videu ili klizačima):',
                                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text('X:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                              ),
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
                                      : (val) => setState(() => _panX = val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 20,
                                child: Text('Y:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                              ),
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
                                      : (val) => setState(() => _panY = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _processingMessage,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          // FIXED BOTTOM ACTION BAR - Never overlaps with system navigation buttons
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomNavPadding),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border(top: BorderSide(color: AppColors.stroke, width: 1)),
            ),
            child: Row(
              children: [
                // Save Video Button
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
                      icon: Icon(Icons.content_cut_rounded, size: 18, color: AppColors.onPrimaryContainer),
                      label: Text(
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

                // Make GIF Button
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
                      icon: Icon(Icons.gif_rounded, size: 22, color: AppColors.secondary),
                      label: Text(
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
