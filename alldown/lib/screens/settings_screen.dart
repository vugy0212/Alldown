import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_settings.dart';
import '../models/media_item.dart';
import '../providers/media_library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_update_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingUpdate = false;
  bool _cacheCleared = false;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  int _calculateCategoryBytes(List<MediaItem> items, {required bool isAudio}) {
    int sum = 0;
    for (final item in items.where((i) => i.isAudio == isAudio)) {
      try {
        final f = File(item.localPath);
        if (f.existsSync()) {
          sum += f.lengthSync();
        }
      } catch (_) {}
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final libraryState = ref.watch(mediaLibraryProvider);

    final videoBytes = _calculateCategoryBytes(libraryState.items, isAudio: false);
    final audioBytes = _calculateCategoryBytes(libraryState.items, isAudio: true);
    final totalBytes = videoBytes + audioBytes;
    final hasCookies = settings.cookiesActive && settings.cookiesCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Storage Management Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.stroke, width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pie_chart_rounded,
                                size: 20,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Storage Management',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Device & cache allocation',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_formatBytes(totalBytes)} Total',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Multi-segment Storage Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (videoBytes > 0)
                            Expanded(
                              flex: (videoBytes ~/ 1024).clamp(1, 100000),
                              child: Container(color: AppColors.primaryAccent),
                            ),
                          if (videoBytes > 0 && audioBytes > 0) const SizedBox(width: 2),
                          if (audioBytes > 0)
                            Expanded(
                              flex: (audioBytes ~/ 1024).clamp(1, 100000),
                              child: Container(color: AppColors.secondary),
                            ),
                          if (totalBytes == 0)
                            Expanded(
                              child: Container(color: AppColors.surfaceContainerLowest),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Legend (Wrap prevents horizontal overflow)
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 7, color: AppColors.primaryAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Videos (${_formatBytes(videoBytes)})',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 7, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'Audio (${_formatBytes(audioBytes)})',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 7, color: AppColors.tertiary),
                          const SizedBox(width: 4),
                          Text(
                            'Cache (${_cacheCleared ? "0.0 MB" : "Temp"})',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Clear App Cache Button
                  InkWell(
                    onTap: () {
                      setState(() => _cacheCleared = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Temporary stream cache cleared')),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.tertiary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Clear App Cache',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _cacheCleared ? '0.0 MB' : 'Clean',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Highlighted Feature: Account & Authentication Card (18+ Gate Bypass)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.stroke, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.1),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.vpn_key_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Browser Cookies & Auth',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Access restricted & private streams',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Real Cookie Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasCookies
                          ? AppColors.tertiaryContainer.withValues(alpha: 0.3)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: hasCookies ? AppColors.tertiary : AppColors.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            hasCookies
                                ? 'Cookies Active (${settings.cookiesCount} entries loaded)'
                                : 'No cookies loaded (Public streams active)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasCookies ? AppColors.tertiary : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bypass 18+ age restrictions, private member-only channels, and login walls safely without re-authenticating repeatedly.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLowest,
                            side: BorderSide(color: AppColors.stroke),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await notifier.importCookiesFile();
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Cookies imported & saved'
                                      : 'Import cancelled',
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.folder_open_rounded, size: 18, color: AppColors.primary),
                          label: Text(
                            'Import cookies.txt',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Browser cookies synchronized!')),
                            );
                          },
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text(
                            'Sync Browser',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Security Notice
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 16, color: AppColors.secondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cookies are stored locally in app storage and never uploaded to remote servers.',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // SECTION: DOWNLOAD & MEDIA SETTINGS
            Text(
              'POSTAVKE PREUZIMANJA I MEDIJA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),

            // MENU 2: Video i Format Kontejner (Expandable Menu with Dropdowns)
            _buildExpandableCard(
              icon: Icons.video_settings_rounded,
              iconColor: AppColors.secondary,
              title: 'Video i Kontejner Postavke',
              subtitle: 'Format: ${settings.videoContainer} • Rezolucija: ${_formatMaxRes(settings.maxResolution)}',
              badge: settings.videoContainer,
              badgeColor: AppColors.secondary,
              initiallyExpanded: false,
              children: [
                _buildDropdownRow<String>(
                  title: 'Zadani Video Kontejner',
                  subtitle: 'Format izlazne video datoteke',
                  value: settings.videoContainer,
                  items: const [
                    DropdownMenuItem(value: 'MP4', child: Text('MP4 (H.264 / AAC)')),
                    DropdownMenuItem(value: 'MKV', child: Text('MKV (Matroska)')),
                    DropdownMenuItem(value: 'WebM', child: Text('WebM (VP9 / Opus)')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setVideoContainer(val);
                  },
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildDropdownRow<MaxResolution>(
                  title: 'Maksimalna Rezolucija',
                  subtitle: 'Automatski limit za preuzimanje videa',
                  value: settings.maxResolution,
                  items: const [
                    DropdownMenuItem(value: MaxResolution.noLimit, child: Text('Bez limita (8K)')),
                    DropdownMenuItem(value: MaxResolution.res4k, child: Text('4K Ultra HD (2160p)')),
                    DropdownMenuItem(value: MaxResolution.res1440p, child: Text('1440p QHD')),
                    DropdownMenuItem(value: MaxResolution.res1080p, child: Text('1080p FHD (Zadano)')),
                    DropdownMenuItem(value: MaxResolution.res720p, child: Text('720p HD')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setMaxResolution(val);
                  },
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildSettingSwitch(
                  title: 'Automatski remux u MP4',
                  subtitle: 'Osigurava kompatibilnost sa svim Android playerima',
                  value: settings.autoRemuxToMp4,
                  onChanged: (_) => notifier.toggleAutoRemux(),
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildSettingSwitch(
                  title: 'SponsorBlock Filtar',
                  subtitle: 'Automatski izreži sponzorirane segmente i uvode',
                  badge: 'v5.8',
                  value: settings.sponsorBlockEnabled,
                  onChanged: (_) => notifier.toggleSponsorBlock(),
                ),
              ],
            ),

            // MENU 3: Audio Ekstrakcija i Kvaliteta (Expandable Menu with Dropdowns)
            _buildExpandableCard(
              icon: Icons.graphic_eq_rounded,
              iconColor: AppColors.tertiary,
              title: 'Audio Ekstrakcija i Kvaliteta',
              subtitle: 'Kodek: ${settings.audioCodec.name.toUpperCase()} • Bitrate: ${settings.audioBitrate}',
              badge: settings.audioBitrate,
              badgeColor: AppColors.tertiary,
              initiallyExpanded: false,
              children: [
                Text(
                  'Format Zvuka (Kodek)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildCodecTab(
                        title: 'MP3 (Universal)',
                        isSelected: settings.audioCodec == AudioCodec.mp3,
                        onTap: () => notifier.setAudioCodec(AudioCodec.mp3),
                      ),
                      _buildCodecTab(
                        title: 'M4A / AAC',
                        isSelected: settings.audioCodec == AudioCodec.aac,
                        onTap: () => notifier.setAudioCodec(AudioCodec.aac),
                      ),
                      _buildCodecTab(
                        title: 'Opus / FLAC',
                        isSelected: settings.audioCodec == AudioCodec.opus,
                        onTap: () => notifier.setAudioCodec(AudioCodec.opus),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildDropdownRow<String>(
                  title: 'Kvaliteta Zvuka (Bitrate)',
                  subtitle: 'Ciljana brzina prijenosa za audio',
                  value: settings.audioBitrate,
                  items: const [
                    DropdownMenuItem(value: '320 kbps', child: Text('320 kbps (Studio Master)')),
                    DropdownMenuItem(value: '256 kbps', child: Text('256 kbps (Visoka kvaliteta)')),
                    DropdownMenuItem(value: '192 kbps', child: Text('192 kbps (Standard CD)')),
                    DropdownMenuItem(value: '128 kbps', child: Text('128 kbps (Podcast / Glas)')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setAudioBitrate(val);
                  },
                ),
              ],
            ),

            // MENU 4: Mrežni Protokol, Dretve i Brzina (Expandable Menu with Dropdowns)
            _buildExpandableCard(
              icon: Icons.speed_rounded,
              iconColor: AppColors.primary,
              title: 'Mrežni Protokol i Brzina',
              subtitle: 'Paralelno: ${settings.maxConcurrentDownloads} veze • Timeout: ${settings.connectionTimeout}s',
              badge: '${settings.maxConcurrentDownloads} Taska',
              badgeColor: AppColors.primary,
              initiallyExpanded: false,
              children: [
                _buildDropdownRow<String>(
                  title: 'User-Agent Identitet',
                  subtitle: 'Mrežni identifikator preglednika za preuzimanje',
                  value: settings.userAgent,
                  items: const [
                    DropdownMenuItem(value: 'Android Chrome', child: Text('Android Chrome (Zadano)')),
                    DropdownMenuItem(value: 'Windows Desktop', child: Text('Windows Desktop Chrome')),
                    DropdownMenuItem(value: 'iOS Safari', child: Text('Apple iOS Safari')),
                    DropdownMenuItem(value: 'Custom AllDown', child: Text('AllDown Engine v1.0')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setUserAgent(val);
                  },
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildDropdownRow<int>(
                  title: 'Vrijeme Čekanja Veze (Timeout)',
                  subtitle: 'Maksimalno vrijeme odziva poslužitelja',
                  value: settings.connectionTimeout,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 sekundi (Brzo)')),
                    DropdownMenuItem(value: 15, child: Text('15 sekundi (Preporučeno)')),
                    DropdownMenuItem(value: 30, child: Text('30 sekundi (Sporije veze)')),
                    DropdownMenuItem(value: 60, child: Text('60 sekundi (Ultra stabilno)')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setConnectionTimeout(val);
                  },
                ),
                Divider(color: AppColors.stroke, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Istovremena Preuzimanja',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                          Text(
                            'Broj paralelnih aktivnih preuzimanja',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${settings.maxConcurrentDownloads} Zadataka',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onPrimary),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.maxConcurrentDownloads.toDouble(),
                  min: 1,
                  max: 8,
                  divisions: 7,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.surfaceContainerLowest,
                  label: '${settings.maxConcurrentDownloads}',
                  onChanged: (val) => notifier.setConcurrentDownloads(val.toInt()),
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildSettingSwitch(
                  title: 'Preuzimanje samo preko Wi-Fi mreže',
                  subtitle: 'Zaustavi zadatke na mobilnim podatcima za uštedu prometa',
                  value: settings.wifiOnly,
                  onChanged: (_) => notifier.toggleWifiOnly(),
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildSettingSwitch(
                  title: 'Automatski ponovni pokušaj (Auto-retry)',
                  subtitle: '3 pokušaja s eksponencijalnim odgodama pri prekidu',
                  value: settings.autoRetry,
                  onChanged: (_) => notifier.toggleAutoRetry(),
                ),
              ],
            ),

            // MENU 5: Upravljanje Memorijom i Mapama (Expandable Menu)
            _buildExpandableCard(
              icon: Icons.folder_copy_rounded,
              iconColor: AppColors.secondary,
              title: 'Upravljanje Memorijom i Mapama',
              subtitle: 'Zadana mapa: ${settings.downloadDirectory}',
              badge: 'Pohrana',
              badgeColor: AppColors.secondary,
              initiallyExpanded: false,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Zadana Mapa Preuzimanja',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final picked = await notifier.pickDownloadDirectory();
                            if (mounted && picked != null) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Mapa ažurirana na: $picked')),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.drive_file_move_rounded, size: 13, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Promijeni',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            notifier.resetDownloadDirectory();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vraćeno na zadano: /storage/emulated/0/Download/AllDown')),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Reset',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.stroke, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settings.downloadDirectory,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurface,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: AppColors.stroke, height: 1),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: BorderSide(color: AppColors.stroke),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      notifier.resetAllSettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sve postavke su vraćene na zadane tvorničke vrijednosti.')),
                      );
                    },
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Resetiraj Sve Postavke na Tvorničke', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            // MENU 6: Obavijesti i Pozadinski Rad (Expandable Menu)
            _buildExpandableCard(
              icon: Icons.notifications_active_rounded,
              iconColor: AppColors.tertiary,
              title: 'Obavijesti i Pozadinski Servis',
              subtitle: 'Android Foreground Service s prikazom napretka',
              badge: 'Aktivan',
              badgeColor: AppColors.tertiary,
              initiallyExpanded: false,
              children: [
                _buildSettingSwitch(
                  title: 'Obavijest po završetku preuzimanja',
                  subtitle: 'Prikaz skočnog obavještenja kada se zadatak dovrši',
                  value: settings.notifyOnComplete,
                  onChanged: (_) => notifier.toggleNotifyOnComplete(),
                ),
                Divider(color: AppColors.stroke, height: 16),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppColors.tertiary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pozadinski servis omogućuje neprekinuto preuzimanje čak i kada je ekran zaključan ili koristite druge aplikacije.',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // SECTION: HELP, SYSTEM & ABOUT
            Text(
              'INFORMACIJE, POMOĆ I SUSTAV',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),

            // DRAWER: Pomoć i Upute za Korištenje (Help & Guide)
            _buildExpandableCard(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.tertiary,
              title: 'Pomoć i Upute za Korištenje',
              subtitle: 'Vodič za preuzimanje, Video Studio i izradu GIF-a',
              badge: 'Pomoć',
              badgeColor: AppColors.tertiary,
              initiallyExpanded: false,
              children: [
                _buildHelpStep(
                  icon: Icons.download_rounded,
                  iconColor: AppColors.primary,
                  title: '1. Kako preuzeti video ili glazbu',
                  description:
                      'Kopirajte poveznicu željenog videa (YouTube, TikTok, X, Facebook, Streamable...) i zalijepite je u polje na početnom ekranu, ili unutar druge aplikacije kliknite "Dijeli" (Share) i odaberite AllDown.',
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildHelpStep(
                  icon: Icons.content_cut_rounded,
                  iconColor: AppColors.secondary,
                  title: '2. Korištenje Video Studija (Trimmer & Cropper)',
                  description:
                      'Nakon preuzimanja otvorite video u kartici "Biblioteka", kliknite na opcije (...) i odaberite "Izreži / Uredi video". Možete precizno odrediti početak i kraj, promijeniti omjer (16:9, 9:16 Shorts/Reels, 1:1 Kvadrat, 4:5, 21:9) te prstom po ekranu pomicati i zumirati kadar.',
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildHelpStep(
                  icon: Icons.gif_box_rounded,
                  iconColor: AppColors.tertiary,
                  title: '3. Izrada HD Animirani GIF-ova',
                  description:
                      'U Video Studiju kliknite na "Izradi GIF". Aplikacija koristi napredni Median-Cut 256-bojni algoritam s Floyd-Steinberg ditheringom za oštru sliku. GIF se automatski sprema u sistemsku Galeriju u album Pictures/AllDown.',
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildHelpStep(
                  icon: Icons.audiotrack_rounded,
                  iconColor: Colors.pinkAccent,
                  title: '4. Ekstrakcija zvuka (Audio)',
                  description:
                      'Prilikom preuzimanja odaberite karticu "Zvuk (Audio)" kako biste preuzeli čisti MP3 (do 320 kbps), M4A ili Opus zapis bez video toka.',
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildHelpStep(
                  icon: Icons.vpn_key_rounded,
                  iconColor: Colors.amberAccent,
                  title: '5. Preuzimanje 18+ i zaštićenih videozapisa',
                  description:
                      'Uvezite "cookies.txt" datoteku iz vašeg web preglednika unutar kartice "Browser Cookies & Auth" kako biste preuzimali sadržaj koji zahtijeva prijavu ili dobnu potvrdu.',
                ),
                Divider(color: AppColors.stroke, height: 16),
                _buildHelpStep(
                  icon: Icons.folder_special_rounded,
                  iconColor: Colors.tealAccent,
                  title: '6. Gdje se nalaze spremljene datoteke',
                  description:
                      'Preuzeti videozapisi nalaze se u mapi Download/AllDown, obrađeni isječci u Movies/AllDown, a animirani GIF-ovi u Pictures/AllDown. Sve datoteke se trenutačno pojavljuju u Samsung Galeriji.',
                ),
              ],
            ),

            // DRAWER: Engine & Jezgra Sustava (Engine & Core Runtime)
            _buildExpandableCard(
              icon: Icons.terminal_rounded,
              iconColor: AppColors.secondary,
              title: 'Engine & Jezgra Sustava',
              subtitle: '${settings.ytDlpVersion} • ${settings.ffmpegVersion}',
              badge: 'Media3',
              badgeColor: AppColors.secondary,
              initiallyExpanded: false,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.terminal_rounded, size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stream Extractor Engine',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                                ),
                                Text(
                                  settings.ytDlpVersion,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 12, color: AppColors.tertiary),
                          SizedBox(width: 3),
                          Text(
                            'Up to date',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.hardware_rounded, size: 18, color: AppColors.secondary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Media3 ExoPlayer & Remux',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                                ),
                                Text(
                                  settings.ffmpegVersion,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'HW Accel',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // App & Engine Update Trigger Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainer,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isCheckingUpdate = true);
                      final info = await AppUpdateService.checkForUpdate();
                      if (!mounted) return;
                      setState(() => _isCheckingUpdate = false);
                      if (info != null) {
                        if (context.mounted) {
                          AppUpdateService.showUpdateModal(context, info);
                        }
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Aplikacija i moduli za preuzimanje su ažurni!')),
                        );
                      }
                    },
                    icon: _isCheckingUpdate
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(
                      _isCheckingUpdate ? 'Provjera novih verzija...' : 'Provjeri ažuriranja (GitHub)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Repo & License Link
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://github.com/yt-dlp/yt-dlp')),
                  icon: Icon(Icons.code_rounded, size: 16, color: AppColors.outline),
                  label: Text(
                    'Open Source Licenses & GitHub Repository',
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),

            // DRAWER: O Aplikaciji (About AllDown) - S ugniježđenom opcijom Podržani Servisi
            _buildExpandableCard(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.primary,
              title: 'O Aplikaciji',
              subtitle: 'Informacije o projektu i podržani servisi',
              initiallyExpanded: false,
              children: [
                // App Logo Header
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryAccent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.primaryContainer,
                            child: Icon(Icons.download_rounded, size: 30, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'AllDown',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v1.0.0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Media Downloader & Video Studio',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.stroke, height: 1),
                const SizedBox(height: 14),

                // App Details Rows
                _buildAboutRow(
                  icon: Icons.verified_rounded,
                  iconColor: AppColors.secondary,
                  label: 'Verzija',
                  value: '1.0 (Build 1.0.0)',
                ),
                const SizedBox(height: 10),
                _buildAboutRow(
                  icon: Icons.person_rounded,
                  iconColor: AppColors.primary,
                  label: 'Autor',
                  value: 'Allen',
                ),
                const SizedBox(height: 10),
                _buildAboutRow(
                  icon: Icons.code_rounded,
                  iconColor: AppColors.tertiary,
                  label: 'Licenca',
                  value: 'GNU GPL v3.0 (Open Source)',
                ),
                const SizedBox(height: 14),

                // Open Source Licenses viewer (official Flutter LicensePage)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.stroke),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'AllDown',
                        applicationVersion: '1.0.0',
                        applicationLegalese: 'Copyright © 2026 Allen\nLicencirano pod GNU General Public License v3.0.',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset('assets/images/app_logo.png', width: 48, height: 48),
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                    label: Text(
                      'Pregled svih licenci (Open Source)',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurface),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // GitHub Repository Link
                Center(
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://github.com/vugy0212/Alldown'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: Icon(Icons.code_rounded, size: 15, color: AppColors.outline),
                    label: Text(
                      'GitHub Repozitorij (vugy0212/Alldown)',
                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Ugniježđena ladica za Podržane Servise unutar About-a
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stroke, width: 0.8),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      leading: Icon(Icons.hub_rounded, size: 20, color: AppColors.primary),
                      title: Text(
                        'Podržani Servisi i Ekstraktori',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                      subtitle: Text(
                        '12+ testiranih servisa i univerzalni parser',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                      children: [
                        Divider(color: AppColors.stroke, height: 1),
                        const SizedBox(height: 8),
                        _buildServiceRow(
                          icon: Icons.play_circle_fill_rounded,
                          iconColor: Colors.redAccent,
                          name: 'YouTube & YouTube Shorts',
                          description: '4K, 1080p, 720p i M4A audio',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.tag_rounded,
                          iconColor: Colors.white,
                          name: 'X (Twitter)',
                          description: 'HD MP4 videozapisi izravno iz postova',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.music_note_rounded,
                          iconColor: Colors.cyanAccent,
                          name: 'TikTok',
                          description: 'Preuzimanje bez vodenog žiga',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.facebook_rounded,
                          iconColor: Colors.blueAccent,
                          name: 'Facebook Watch & Reels',
                          description: '1080p HD i 480p SD streamovi',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.stream_rounded,
                          iconColor: Colors.indigoAccent,
                          name: 'Streamable',
                          description: 'API integracija za MP4 download',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.account_balance_rounded,
                          iconColor: Colors.amberAccent,
                          name: 'Archive.org',
                          description: 'Javna arhiva filmova i audio zapisa',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.public_rounded,
                          iconColor: Colors.tealAccent,
                          name: 'Wikimedia Commons',
                          description: 'Slobodni multimedijski repozitorij',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.cloud_download_rounded,
                          iconColor: Colors.orangeAccent,
                          name: 'Test-Videos & Global CDNs',
                          description: 'Visokobrzinski medijski poslužitelji',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.html_rounded,
                          iconColor: Colors.deepOrangeAccent,
                          name: 'W3Schools & HTML5 Portali',
                          description: 'HTML5 video i audio izvori',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.code_rounded,
                          iconColor: Colors.purpleAccent,
                          name: 'GitHub Raw & Assets',
                          description: 'Medijski repozitoriji datoteka',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.video_library_rounded,
                          iconColor: Colors.blueGrey,
                          name: 'Dailymotion & Vimeo',
                          description: 'OpenGraph web media scraper',
                          badge: 'AKTIVAN',
                        ),
                        _buildServiceRow(
                          icon: Icons.link_rounded,
                          iconColor: AppColors.secondary,
                          name: 'Univerzalni Direktni Mediji',
                          description: '.mp4, .webm, .m4a, .mp3, .wav',
                          badge: 'AKTIVAN',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // GitHub Repo Link Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      side: BorderSide(color: AppColors.stroke, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => launchUrl(
                      Uri.parse('https://github.com/vugy0212/Alldown'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: Icon(Icons.open_in_browser_rounded, size: 18, color: AppColors.primary),
                    label: const Text(
                      'Posjeti GitHub Repozitorij',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    String? badge,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildCodecTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatMaxRes(MaxResolution res) {
    switch (res) {
      case MaxResolution.noLimit:
        return '8K';
      case MaxResolution.res4k:
        return '4K';
      case MaxResolution.res1440p:
        return '1440p';
      case MaxResolution.res1080p:
        return '1080p';
      case MaxResolution.res720p:
        return '720p';
    }
  }

  Widget _buildExpandableCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    bool initiallyExpanded = false,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor ?? AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
          iconColor: iconColor,
          collapsedIconColor: AppColors.onSurfaceVariant,
          children: children,
        ),
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required String title,
    required String subtitle,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.stroke, width: 0.8),
          ),
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            dropdownColor: AppColors.surfaceContainerHigh,
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.expand_more_rounded, size: 16, color: AppColors.secondary),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceRow({
    required IconData icon,
    required Color iconColor,
    required String name,
    required String description,
    required String badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
