import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_queue_provider.dart';
import '../providers/quick_download_provider.dart';
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

  final List<Widget> _screens = const [
    HomeScreen(),
    QueueScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  final List<String> _subtitles = const [
    'Quick Download',
    'Transfers Queue',
    'Media Library',
    'App Settings',
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomHeader(
        subtitle: _subtitles[_currentIndex],
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
              color: AppColors.surfaceContainerLow.withValues(alpha: 0.95),
              border: Border(
                top: BorderSide(color: AppColors.stroke, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
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
                      label: 'Down',
                      isSelected: _currentIndex == 0,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.sync_alt_rounded,
                      label: 'Queue',
                      badgeCount: activeQueueCount,
                      isSelected: _currentIndex == 1,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.video_library_rounded,
                      label: 'Library',
                      isSelected: _currentIndex == 2,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      isSelected: _currentIndex == 3,
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
  }) {
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
                        ? AppColors.primaryContainer.withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? AppColors.primaryFixed : AppColors.onSurfaceVariant,
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
                        border: Border.all(color: AppColors.surfaceContainerLow, width: 2),
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
                color: isSelected ? AppColors.primaryFixed : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

