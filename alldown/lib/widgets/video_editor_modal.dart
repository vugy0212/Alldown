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
  String _selectedCrop = 'original'; // original, 1:1, 9:16, 16:9, 4:5
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onRangeChanged(RangeValues values) {
    // Minimum 1 second clip
    if (values.end - values.start < 0.8) return;

    setState(() {
      _trimRange = values;
    });

    // Seek preview to the adjusted start point
    _controller?.seekTo(Duration(milliseconds: (values.start * 1000).toInt()));
  }

  Future<void> _exportVideo() async {
    if (_isProcessing) return;

    final startMs = (_trimRange.start * 1000).toInt();
    final endMs = (_trimRange.end * 1000).toInt();
    final isCropped = _selectedCrop != 'original';

    setState(() {
      _isProcessing = true;
      _processingMessage = isCropped ? 'Izrezivanje kadra i obrada videa...' : 'Brzo rezanje videa...';
    });

    try {
      final configuredDir = ref.read(settingsProvider).downloadDirectory;
      final targetFolder = Directory('$configuredDir/Videos');
      if (!targetFolder.existsSync()) {
        targetFolder.createSync(recursive: true);
      }

      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${targetFolder.path}/Trimmed_$timeStamp.mp4';

      bool success = false;
      if (isCropped) {
        success = await VideoEditorService.cropVideo(
          inputPath: widget.item.localPath,
          outputPath: outPath,
          startMs: startMs,
          endMs: endMs,
          cropRatio: _selectedCrop,
        );
      } else {
        success = await VideoEditorService.trimVideo(
          inputPath: widget.item.localPath,
          outputPath: outPath,
          startMs: startMs,
          endMs: endMs,
        );
      }

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
          resolution: isCropped ? '$_selectedCrop Crop' : widget.item.resolution,
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

  @override
  Widget build(BuildContext context) {
    final startFormatted = VideoEditorService.formatMs((_trimRange.start * 1000).toInt());
    final endFormatted = VideoEditorService.formatMs((_trimRange.end * 1000).toInt());
    final clipDurationSec = (_trimRange.end - _trimRange.start).toStringAsFixed(1);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
                  // Video Player Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.black,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isInitialized && _controller != null)
                            AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio > 0.2
                                  ? _controller!.value.aspectRatio
                                  : 16 / 9,
                              child: VideoPlayer(_controller!),
                            )
                          else
                            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

                          // Play / Pause Overlay Button
                          if (_isInitialized && _controller != null)
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _controller!.value.isPlaying
                                          ? _controller!.pause()
                                          : _controller!.play();
                                    });
                                  },
                                ),
                              ),
                            ),

                          // Crop Aspect Ratio Visual Indicator Pill
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.crop_rounded, size: 12, color: AppColors.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedCrop == 'original' ? 'Original Aspect' : 'Crop: $_selectedCrop',
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
                    'Omjer i izrezivanje kadra (Crop)',
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
                  const SizedBox(height: 24),

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
