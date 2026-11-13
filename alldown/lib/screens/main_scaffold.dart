import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../providers/download_queue_provider.dart';
import '../providers/quick_download_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header.dart';
import '../widgets/mini_player_bar.dart';
import 'home_screen.dart';
import 'queue_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;
  StreamSubscription<String>? _shareSubscription;

  List<Widget> get _screens => [
    HomeScreen(
      onOpenSettings: () => setState(() => _currentIndex = 3),
    ),
    const QueueScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initSharedUrlListener();
  }

  void _initSharedUrlListener() {
    final nativeService = ref.read(nativeDownloaderServiceProvider);
    
    // Check initial launch intent
    nativeService.getInitialSharedUrl().then((url) {
      if (url != null && url.isNotEmpty) {
        _handleSharedUrl(url);
      }
    });

    // Listen for subsequent shared URLs
    _shareSubscription = nativeService.onUrlShared.listen((url) {
      _handleSharedUrl(url);
    });
  }

  void _handleSharedUrl(String url) {
    setState(() => _currentIndex = 0);
    ref.read(quickDownloadProvider.notifier).setUrl(url);
    ref.read(quickDownloadProvider.notifier).fetchMetadata();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeQueueCount = ref.watch(downloadQueueProvider.notifier).activeCount;
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final l10n = L10n(settings.language);

    final subtitles = [
      l10n.quickDownload,
      l10n.transfersQueue,
      l10n.mediaLibrary,
      l10n.appSettings,
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF3F4F8),
      appBar: CustomHeader(
        subtitle: subtitles[_currentIndex],
        onSettingsTap: () {
          setState(() => _currentIndex = 3);
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceContainerLow.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.98),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.download_rounded,
                      label: l10n.navDown,
                      isSelected: _currentIndex == 0,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.sync_alt_rounded,
                      label: l10n.navQueue,
                      badgeCount: activeQueueCount,
                      isSelected: _currentIndex == 1,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.video_library_rounded,
                      label: l10n.navLibrary,
                      isSelected: _currentIndex == 2,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.settings_rounded,
                      label: l10n.navSettings,
                      isSelected: _currentIndex == 3,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeColor = isDark ? AppColors.primaryFixed : AppColors.primaryAccent;
    final inactiveColor = isDark ? AppColors.onSurfaceVariant : const Color(0xFF64748B);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? AppColors.primaryContainer.withValues(alpha: 0.3)
                            : AppColors.primaryContainer.withValues(alpha: 0.5))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.surfaceContainerLow : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

