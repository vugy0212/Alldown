import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_options.dart';
import '../providers/quick_download_provider.dart';
import '../theme/app_colors.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late TextEditingController _urlController;
  bool _isQualityExpanded = false;
  bool _isPreProcessingExpanded = false;

  @override
  void initState() {
    super.initState();
    final initialUrl = ref.read(quickDownloadProvider).url;
    _urlController = TextEditingController(text: initialUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onPaste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _urlController.text = text;
      ref.read(quickDownloadProvider.notifier).setUrl(text);
      ref.read(quickDownloadProvider.notifier).fetchMetadata();
    }
  }

  void _onClear() {
    _urlController.clear();
    ref.read(quickDownloadProvider.notifier).clearUrl();
  }

  String _selectedActionLabel(DownloadOptions options) {
    if (options.format == TargetFormat.audioMp3) {
      switch (options.audioQuality) {
        case AudioQuality.kbps320:
          return '320 kbps';
        case AudioQuality.kbps256:
          return '256 kbps';
        case AudioQuality.kbps192:
          return '192 kbps';
        case AudioQuality.kbps128:
          return '128 kbps';
      }
    }
    if (options.format == TargetFormat.customRaw) {
      return 'Custom Raw';
    }
    switch (options.quality) {
      case VideoQuality.res4k:
        return '4K 2160p';
      case VideoQuality.res1080p:
        return '1080p FHD';
      case VideoQuality.res720p:
        return '720p HD';
      case VideoQuality.res480p:
        return '480p SD';
    }
  }

  String _selectedQualityBadge(DownloadOptions options) {
    if (options.format == TargetFormat.audioMp3) {
      switch (options.audioQuality) {
        case AudioQuality.kbps320:
          return '320k HQ';
        case AudioQuality.kbps256:
          return '256k';
        case AudioQuality.kbps192:
          return '192k';
        case AudioQuality.kbps128:
          return '128k';
      }
    }
    switch (options.quality) {
      case VideoQuality.res4k:
        return '4K 2160p';
      case VideoQuality.res1080p:
        return '1080p FHD';
      case VideoQuality.res720p:
        return '720p HD';
      case VideoQuality.res480p:
        return '480p SD';
    }
  }

  String _selectedQualitySubtitle(DownloadOptions options) {
    if (options.format == TargetFormat.audioMp3) {
      switch (options.audioQuality) {
        case AudioQuality.kbps320:
          return 'Master Studio • 320 kbps MP3';
        case AudioQuality.kbps256:
          return 'High Fidelity • 256 kbps MP3';
        case AudioQuality.kbps192:
          return 'Standard • 192 kbps MP3';
        case AudioQuality.kbps128:
          return 'Compact Saver • 128 kbps MP3';
      }
    }
    switch (options.quality) {
      case VideoQuality.res4k:
        return 'Ultra HD • 3840x2160 • 60fps';
      case VideoQuality.res1080p:
        return 'Full HD • 1920x1080 • Recommended';
      case VideoQuality.res720p:
        return 'HD • 1280x720 • Fast Stream';
      case VideoQuality.res480p:
        return 'SD • 854x480 • Mobile Friendly';
    }
  }

  String _preProcessingBadge(DownloadOptions options) {
    int count = 0;
    if (options.createSubfolder) count++;
    if (options.embedSubtitles) count++;
    if (options.saveMetadata) count++;
    return '$count active';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickDownloadProvider);
    final notifier = ref.read(quickDownloadProvider.notifier);

    if (_urlController.text != state.url) {
      _urlController.value = TextEditingValue(
        text: state.url,
        selection: TextSelection.collapsed(offset: state.url.length),
      );
    }

    final media = state.detectedMedia;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // URL Intake Engine Bento Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.stroke, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.link_rounded, size: 18, color: AppColors.secondary),
                          SizedBox(width: 6),
                          Text(
                            'Media URL or Direct Stream Link',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: _onPaste,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.content_paste_rounded, size: 13, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Paste',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // URL Input Box with Search and Clear
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColors.outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            onChanged: notifier.setUrl,
                            onSubmitted: (val) {
                              notifier.setUrl(val);
                              notifier.fetchMetadata();
                            },
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Paste link from YouTube, Vimeo, TikTok, Bilibili...',
                              hintStyle: TextStyle(color: AppColors.outline, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_urlController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            color: AppColors.onSurfaceVariant,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainer,
                              minimumSize: const Size(26, 26),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: _onClear,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CTA Fetch Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryAccent.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: state.isAnalyzing ? null : notifier.fetchMetadata,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (state.isAnalyzing) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ] else ...[
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: AppColors.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                state.analyzeButtonText,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detected Media Preview Card (Loading, Empty, or Real Data)
            if (state.isAnalyzing)
              Container(
                height: 190,
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.primaryAccent,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Fetching Video Metadata...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.url.isNotEmpty ? state.url : 'Connecting to stream...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (media == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.stroke, width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.smart_display_outlined,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No media link detected',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Paste a YouTube, Shorts, TikTok, or video link above to view metadata, format options, and start downloading.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _onPaste,
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('Paste from Clipboard'),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.stroke, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 16:9 Thumbnail with overlays
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              color: AppColors.surfaceContainerHighest,
                              child: Image.network(
                                media.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.movie_rounded, color: AppColors.outline, size: 40),
                                ),
                              ),
                            ),
                          ),
                          // Top Badges
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.high_quality_rounded, size: 13, color: AppColors.secondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        media.badgeText,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.smart_display_rounded, size: 13, color: Colors.white),
                                      const SizedBox(width: 3),
                                      Text(
                                        media.platform,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Bottom badges
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.circle, size: 6, color: AppColors.tertiary),
                                  SizedBox(width: 4),
                                  Text(
                                    'HDR10 / 60 FPS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                media.duration,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Real Title & Metadata
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            media.channel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: AppColors.outline)),
                        const SizedBox(width: 6),
                        Text(
                          media.subscribers,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          media.uploadTime,
                          style: const TextStyle(fontSize: 12, color: AppColors.outline),
                        ),
                        const Text('•', style: TextStyle(color: AppColors.outline)),
                        Text(
                          media.viewCount,
                          style: const TextStyle(fontSize: 12, color: AppColors.outline),
                        ),
                        const Text('•', style: TextStyle(color: AppColors.outline)),
                        Text(
                          media.license,
                          style: const TextStyle(fontSize: 12, color: AppColors.tertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),

            // Segmented Media Mode Switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Target Format',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 14, color: AppColors.secondary),
                    SizedBox(width: 4),
                    Text(
                      'Advanced Config',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Segmented Bar: [Video (MP4)] | [Audio (MP3)] | [Custom Raw]
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildFormatTab(
                    title: 'Video (MP4)',
                    icon: Icons.movie_rounded,
                    selected: state.options.format == TargetFormat.videoMp4,
                    onTap: () => notifier.setFormat(TargetFormat.videoMp4),
                  ),
                  _buildFormatTab(
                    title: 'Audio (MP3)',
                    icon: Icons.headphones_rounded,
                    selected: state.options.format == TargetFormat.audioMp3,
                    onTap: () => notifier.setFormat(TargetFormat.audioMp3),
                  ),
                  _buildFormatTab(
                    title: 'Custom Raw',
                    icon: Icons.terminal_rounded,
                    selected: state.options.format == TargetFormat.customRaw,
                    onTap: () => notifier.setFormat(TargetFormat.customRaw),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Expandable Quality & Stream Options Accordion
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isQualityExpanded ? AppColors.primaryAccent.withValues(alpha: 0.5) : AppColors.stroke,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isQualityExpanded = !_isQualityExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              state.options.format == TargetFormat.audioMp3
                                  ? Icons.headphones_rounded
                                  : Icons.tune_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.options.format == TargetFormat.audioMp3
                                      ? 'Audio Bitrate & Quality'
                                      : 'Resolution & Stream Quality',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedQualitySubtitle(state.options),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedQualityBadge(state.options),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _isQualityExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.outline,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity, height: 0),
                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          const Divider(color: AppColors.stroke, height: 12),
                          if (state.options.format == TargetFormat.audioMp3) ...[
                            _buildQualityCard(
                              title: '320 kbps (High Quality)',
                              subtitle: 'Studio Master • Pristine Audio • ~2.4 MB/min',
                              size: media?.estimateSizeForQuality(VideoQuality.res1080p, true, AudioQuality.kbps320) ?? 'Auto',
                              badge: 'Recommended',
                              tag: '320k',
                              icon: Icons.album_rounded,
                              selected: state.options.audioQuality == AudioQuality.kbps320,
                              onTap: () => notifier.setAudioQuality(AudioQuality.kbps320),
                            ),
                            const SizedBox(height: 8),
                            _buildQualityCard(
                              title: '256 kbps (Standard)',
                              subtitle: 'High Fidelity VBR • ~1.9 MB/min',
                              size: media?.estimateSizeForQuality(VideoQuality.res1080p, true, AudioQuality.kbps256) ?? 'Auto',
                              tag: '256k',
                              icon: Icons.graphic_eq_rounded,
                              selected: state.options.audioQuality == AudioQuality.kbps256,
                              onTap: () => notifier.setAudioQuality(AudioQuality.kbps256),
                            ),
                            const SizedBox(height: 8),
                            _buildQualityCard(
                              title: '192 kbps (Medium)',
                              subtitle: 'Balanced Quality • ~1.4 MB/min',
                              size: media?.estimateSizeForQuality(VideoQuality.res1080p, true, AudioQuality.kbps192) ?? 'Auto',
                              tag: '192k',
                              icon: Icons.audiotrack_rounded,
                              selected: state.options.audioQuality == AudioQuality.kbps192,
                              onTap: () => notifier.setAudioQuality(AudioQuality.kbps192),
                            ),
                            const SizedBox(height: 8),
                            _buildQualityCard(
                              title: '128 kbps (Saver)',
                              subtitle: 'Smallest File Size • Voice/Podcast • ~1.0 MB/min',
                              size: media?.estimateSizeForQuality(VideoQuality.res1080p, true, AudioQuality.kbps128) ?? 'Auto',
                              tag: '128k',
                              icon: Icons.music_note_rounded,
                              selected: state.options.audioQuality == AudioQuality.kbps128,
                              onTap: () => notifier.setAudioQuality(AudioQuality.kbps128),
                            ),
                          ] else if (state.options.format == TargetFormat.videoMp4) ...[
                            _buildQualityCard(
                              title: '4K (2160p)',
                              subtitle: 'VP9 Profile 2 • 3840x2160',
                              size: media?.estimateSizeForQuality(VideoQuality.res4k, false) ?? 'Auto',
                              tag: '60fps',
                              icon: Icons.hd_rounded,
                              selected: state.options.quality == VideoQuality.res4k,
                              onTap: () => notifier.setQuality(VideoQuality.res4k),
                            ),
                            const SizedBox(height: 8),
                            _buildQualityCard(
                              title: '1080p Full HD',
                              subtitle: 'H.264 / AVC • Clean Remux',
                              size: media?.estimateSizeForQuality(VideoQuality.res1080p, false) ?? 'Auto',
                              badge: 'Recommended',
                              icon: Icons.check_rounded,
                              selected: state.options.quality == VideoQuality.res1080p,
                              onTap: () => notifier.setQuality(VideoQuality.res1080p),
                            ),
                            const SizedBox(height: 8),
                            _buildQualityCard(
                              title: '720p HD',
                              subtitle: 'High Speed / Data Saver',
                              size: media?.estimateSizeForQuality(VideoQuality.res720p, false) ?? 'Auto',
                              icon: Icons.video_file_rounded,
                              selected: state.options.quality == VideoQuality.res720p,
                              onTap: () => notifier.setQuality(VideoQuality.res720p),
                            ),
                            const SizedBox(height: 8),
                            _buildQualityCard(
                              title: '480p SD',
                              subtitle: 'Ultra Light • Mobile Friendly',
                              size: media?.estimateSizeForQuality(VideoQuality.res480p, false) ?? 'Auto',
                              icon: Icons.sd_rounded,
                              selected: state.options.quality == VideoQuality.res480p,
                              onTap: () => notifier.setQuality(VideoQuality.res480p),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.terminal_rounded, size: 20, color: AppColors.secondary),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Direct original stream download without transcoding.',
                                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    crossFadeState: _isQualityExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Expandable Pre-Processing & Organization Accordion
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isPreProcessingExpanded ? AppColors.secondary.withValues(alpha: 0.5) : AppColors.stroke,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isPreProcessingExpanded = !_isPreProcessingExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.settings_suggest_rounded,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pre-Processing & Organization',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Subfolders, subtitles & metadata',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _preProcessingBadge(state.options),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _isPreProcessingExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.outline,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity, height: 0),
                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          const Divider(color: AppColors.stroke, height: 12),
                          _buildToggleTile(
                            title: 'Create subfolder with title',
                            subtitle: 'Organizes media by artist and stream name',
                            icon: Icons.create_new_folder_outlined,
                            value: state.options.createSubfolder,
                            onChanged: (_) => notifier.toggleSubfolder(),
                          ),
                          const Divider(color: AppColors.stroke, height: 16),
                          _buildToggleTile(
                            title: 'Embed Subtitles',
                            subtitle: 'Auto-detect CC: hr, sr, bs, en',
                            icon: Icons.subtitles_outlined,
                            value: state.options.embedSubtitles,
                            onChanged: (_) => notifier.toggleEmbedSubtitles(),
                          ),
                          const Divider(color: AppColors.stroke, height: 16),
                          _buildToggleTile(
                            title: 'Save Media Server Metadata',
                            subtitle: 'Generate Plex / Jellyfin compatible .NFO & poster',
                            icon: Icons.art_track_rounded,
                            value: state.options.saveMetadata,
                            onChanged: (_) => notifier.toggleSaveMetadata(),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: _isPreProcessingExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Primary Download Action Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: state.isDownloadAdded
                      ? null
                      : () {
                          final started = notifier.startDownload();
                          if (!started) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please paste a valid video or audio link first!'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Download started! Open Queue tab to view live progress.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state.isDownloadAdded
                            ? Icons.download_done_rounded
                            : Icons.arrow_circle_down_rounded,
                        size: 24,
                        color: AppColors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          state.isDownloadAdded
                              ? 'Added to Transfer Queue'
                              : 'Start Download (${_selectedActionLabel(state.options)})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatTab({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceContainerHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityCard({
    required String title,
    required String subtitle,
    required String size,
    String? tag,
    String? badge,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerHigh : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryAccent : AppColors.stroke,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.25),
                    blurRadius: 16,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? AppColors.onPrimaryContainer : AppColors.outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: selected ? AppColors.primary : AppColors.onSurface,
                        ),
                      ),
                      if (tag != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                      if (badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.thumb_up_rounded, size: 10, color: AppColors.onTertiaryContainer),
                              const SizedBox(width: 3),
                              Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  size,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.secondary : AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : AppColors.surfaceContainerHighest,
                  ),
                  child: selected
                      ? const Center(
                          child: Icon(Icons.check, size: 14, color: AppColors.onPrimary),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
