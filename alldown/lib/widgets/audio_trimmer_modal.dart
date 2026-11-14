import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../l10n/l10n.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/native_downloader_service.dart';
import '../theme/app_colors.dart';

class AudioTrimmerModal extends ConsumerStatefulWidget {
  final MediaItem item;

  const AudioTrimmerModal({super.key, required this.item});

  static void show(BuildContext context, MediaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioTrimmerModal(item: item),
    );
  }

  @override
  ConsumerState<AudioTrimmerModal> createState() => _AudioTrimmerModalState();
}

class _AudioTrimmerModalState extends ConsumerState<AudioTrimmerModal> {
  VideoPlayerController? _previewCtrl;
  bool _isInit = false;
  double _totalDurationMs = 1000.0;
  double _startMs = 0.0;
  double _endMs = 1000.0;
  bool _isPlaying = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = File(widget.item.localPath);
    if (!file.existsSync()) return;

    final ctrl = VideoPlayerController.file(file);
    _previewCtrl = ctrl;
    await ctrl.initialize();

    if (mounted) {
      final total = ctrl.value.duration.inMilliseconds.toDouble();
      setState(() {
        _totalDurationMs = total > 0 ? total : 1000.0;
        _startMs = 0.0;
        _endMs = (_totalDurationMs > 30000) ? 30000.0 : _totalDurationMs; // Default 30s clip
        _isInit = true;
      });
      ctrl.addListener(_onTick);
    }
  }

  void _onTick() {
    final ctrl = _previewCtrl;
    if (ctrl == null || !mounted || !ctrl.value.isInitialized) return;
    final pos = ctrl.value.position.inMilliseconds.toDouble();
    if (pos >= _endMs) {
      ctrl.pause();
      ctrl.seekTo(Duration(milliseconds: _startMs.toInt()));
      setState(() => _isPlaying = false);
    } else {
      if (_isPlaying != ctrl.value.isPlaying) {
        setState(() => _isPlaying = ctrl.value.isPlaying);
      }
    }
  }

  Future<void> _togglePreview() async {
    final ctrl = _previewCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      setState(() => _isPlaying = false);
    } else {
      await ctrl.seekTo(Duration(milliseconds: _startMs.toInt()));
      await ctrl.play();
      setState(() => _isPlaying = true);
    }
  }

  String _formatMs(double ms) {
    final d = Duration(milliseconds: ms.toInt());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final tenths = ((d.inMilliseconds % 1000) ~/ 100).toString();
    return '$m:$s.$tenths';
  }

  Future<void> _saveClip() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final inputPath = widget.item.localPath;
      final ext = widget.item.format.toLowerCase();
      final dir = File(inputPath).parent.path;
      final safeTitle = widget.item.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final outputPath = '$dir/${safeTitle}_clip_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final success = await NativeDownloaderService().extractAndTrimAudio(
        inputPath: inputPath,
        outputPath: outputPath,
        startMs: _startMs.toInt(),
        endMs: _endMs.toInt(),
      );

      if (success && File(outputPath).existsSync()) {
        final f = File(outputPath);
        final sizeBytes = f.lengthSync();
        final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
        final clipDurationSec = ((_endMs - _startMs) / 1000).toInt();
        final durStr = '${(clipDurationSec ~/ 60).toString().padLeft(2, '0')}:${(clipDurationSec % 60).toString().padLeft(2, '0')}';

        final newItem = MediaItem(
          id: 'clip_${DateTime.now().millisecondsSinceEpoch}',
          title: '${widget.item.title} (Clip)',
          channel: widget.item.channel,
          duration: durStr,
          thumbnailUrl: widget.item.thumbnailUrl,
          localPath: outputPath,
          format: widget.item.format,
          resolution: widget.item.resolution,
          sizeFormatted: '$sizeMb MB',
          completedDateFormatted: 'Completed Just Now',
          isAudio: true,
          platform: widget.item.platform,
        );

        ref.read(mediaLibraryProvider.notifier).addItem(newItem);
        NativeDownloaderService().scanMediaFile(path: outputPath);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio clip saved to Library!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save audio clip')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving clip: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _previewCtrl?.removeListener(_onTick);
    _previewCtrl?.pause();
    _previewCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final l10n = L10n(settings.language);

    final clipDuration = Duration(milliseconds: (_endMs - _startMs).toInt());
    final clipDurSec = clipDuration.inSeconds;
    final clipFormatted = '${(clipDurSec ~/ 60).toString().padLeft(2, '0')}:${(clipDurSec % 60).toString().padLeft(2, '0')}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.stroke : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.content_cut_rounded, color: AppColors.secondary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.isHr ? 'Izreži Audio Isječak' : 'Trim Audio Segment',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (!_isInit)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
              )
            else ...[
              // Snippet Duration Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${l10n.isHr ? 'Duljina isječka' : 'Clip Duration'}: $clipFormatted (${_formatMs(_startMs)} - ${_formatMs(_endMs)})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Dual-Handle Range Slider
              RangeSlider(
                values: RangeValues(_startMs, _endMs),
                min: 0.0,
                max: _totalDurationMs,
                activeColor: AppColors.secondary,
                inactiveColor: isDark ? AppColors.stroke : const Color(0xFFCBD5E1),
                onChanged: (vals) {
                  if (vals.end - vals.start >= 1000) {
                    // Min 1 second clip
                    setState(() {
                      _startMs = vals.start;
                      _endMs = vals.end;
                    });
                  }
                },
              ),

              // Start / End Timestamps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatMs(_startMs), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    Text(_formatMs(_endMs), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Transport Preview Button
              Center(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppColors.surfaceContainerHighest : const Color(0xFFE2E8F0),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(_isPlaying ? 'Pause Preview' : 'Play Selected Clip'),
                  onPressed: _togglePreview,
                ),
              ),
              const SizedBox(height: 24),

              // Save Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving ? 'Extracting & Saving...' : (l10n.isHr ? 'Spremi Isječak u Biblioteku' : 'Save Clip to Library'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isSaving ? null : _saveClip,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
