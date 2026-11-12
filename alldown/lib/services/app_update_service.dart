import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import 'native_downloader_service.dart';

class AppReleaseInfo {
  final String tagName;
  final String title;
  final String notes;
  final String downloadUrl;
  final String publishedAt;
  final bool isNewer;

  const AppReleaseInfo({
    required this.tagName,
    required this.title,
    required this.notes,
    required this.downloadUrl,
    required this.publishedAt,
    required this.isNewer,
  });
}

class AppUpdateService {
  static const String currentVersion = '1.3.4';
  static const String defaultRepo = 'vugy0212/Alldown';

  /// Queries GitHub Releases API for the latest version
  static Future<AppReleaseInfo?> checkForUpdate({String repo = defaultRepo}) async {
    try {
      final uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
      final response = await http.get(uri, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'AllDown-Mobile-App/$currentVersion',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? 'v1.0.1';
        final title = data['name'] as String? ?? 'AllDown $tagName';
        final body = data['body'] as String? ?? 'New release includes performance improvements and fixes.';
        final publishedAt = data['published_at'] as String? ?? '';

        String apkUrl = data['html_url'] as String? ?? 'https://github.com/$repo/releases';
        final assets = data['assets'] as List?;
        if (assets != null) {
          String? preferredArm64;
          String? preferredUniversal;
          String? fallbackApk;
          for (final a in assets) {
            if (a is Map<String, dynamic>) {
              final name = (a['name'] as String? ?? '').toLowerCase();
              final dl = a['browser_download_url'] as String? ?? '';
              if (name.endsWith('.apk') && dl.isNotEmpty) {
                fallbackApk ??= dl;
                if (name.contains('arm64')) {
                  preferredArm64 = dl;
                } else if (name.contains('universal')) {
                  preferredUniversal = dl;
                }
              }
            }
          }
          apkUrl = preferredArm64 ?? preferredUniversal ?? fallbackApk ?? apkUrl;
        }

        final isNewer = _compareVersions(tagName, currentVersion);

        return AppReleaseInfo(
          tagName: tagName,
          title: title,
          notes: body,
          downloadUrl: apkUrl,
          publishedAt: publishedAt,
          isNewer: isNewer,
        );
      }
    } catch (_) {}

    // Fallback: If repo has no releases published yet, provide current version status
    return const AppReleaseInfo(
      tagName: 'v1.0.0',
      title: 'AllDown v1.0.0 - Initial Release',
      notes: '• Universal engine support for YouTube, Facebook, X (Twitter), TikTok and direct media streams\n• Dynamic quality and format selection (Video MP4 / Audio MP3)\n• Compact accordion drawers and Video Studio\n• Built-in background downloader and ExoPlayer playback',
      downloadUrl: 'https://github.com/vugy0212/Alldown/releases',
      publishedAt: '2026-11-10',
      isNewer: false,
    );
  }

  static bool _compareVersions(String remoteTag, String local) {
    final cleanRemote = remoteTag.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanLocal = local.replaceAll(RegExp(r'[^0-9.]'), '');
    final remoteParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localParts = cleanLocal.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < remoteParts.length && i < localParts.length; i++) {
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }
    return remoteParts.length > localParts.length;
  }

  /// Displays the interactive update bottom sheet
  static void showUpdateModal(BuildContext context, AppReleaseInfo info) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _UpdateModalSheet(info: info);
      },
    );
  }
}

class _UpdateModalSheet extends StatefulWidget {
  final AppReleaseInfo info;

  const _UpdateModalSheet({required this.info});

  @override
  State<_UpdateModalSheet> createState() => _UpdateModalSheetState();
}

class _UpdateModalSheetState extends State<_UpdateModalSheet> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  final NativeDownloaderService _nativeService = NativeDownloaderService();

  Future<void> _startInAppDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.01;
      _statusText = 'Connecting to GitHub...';
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      request.headers['User-Agent'] = 'AllDown-Updater/${AppUpdateService.currentVersion}';

      final response = await client.send(request);
      if (response.statusCode >= 400) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/AllDown_${widget.info.tagName}.apk');
      if (apkFile.existsSync()) {
        apkFile.deleteSync();
      }

      final sink = apkFile.openWrite();
      int receivedBytes = 0;

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && mounted) {
            final prog = (receivedBytes / totalBytes).clamp(0.01, 0.99);
            final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            setState(() {
              _progress = prog;
              _statusText = '$mbReceived MB / $mbTotal MB (${(prog * 100).toInt()}%)';
            });
          }
        },
      ).asFuture();

      await sink.flush();
      await sink.close();
      client.close();

      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _statusText = 'Opening Android Installer...';
      });

      // Launch standard Android package installer
      final launched = await _nativeService.installApk(apkFile.path);
      if (!launched) {
        // Fallback to external launcher if security prevents direct trigger
        final uri = Uri.parse(widget.info.downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusText = 'Download failed. Opening in browser...';
      });
      final uri = Uri.parse(widget.info.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.stroke, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: AppColors.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.info.isNewer ? 'New version available!' : 'AllDown is up to date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current: v${AppUpdateService.currentVersion} • Latest: ${widget.info.tagName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.info.isNewer
                      ? AppColors.tertiary.withValues(alpha: 0.2)
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.info.isNewer ? 'NEW' : 'LATEST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.info.isNewer ? AppColors.tertiary : AppColors.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // In-App Download Progress Banner (Active during download)
          if (_isDownloading) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading APK...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: AppColors.surfaceContainerLowest,
                    color: AppColors.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusText,
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Scrollable Release Notes Box
          Flexible(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.stroke, width: 1),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.info.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.info.notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons (Sticky at bottom, always clickable)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                    side: BorderSide(color: AppColors.stroke),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isDownloading ? null : () => Navigator.pop(context),
                  child: Text(widget.info.isNewer ? 'Later' : 'OK'),
                ),
              ),
              if (widget.info.isNewer) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isDownloading ? null : _startInAppDownloadAndInstall,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _isDownloading ? 'Downloading...' : 'Update to ${widget.info.tagName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

