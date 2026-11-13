import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

class CustomHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String subtitle;
  final VoidCallback? onSettingsTap;

  const CustomHeader({
    super.key,
    required this.subtitle,
    this.onSettingsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final l10n = L10n(settings.language);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface.withValues(alpha: 0.95) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Official App Logo
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryAccent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.primaryContainer,
                        child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title: AllDown only
                Text(
                  'AllDown',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    letterSpacing: 0.4,
                  ),
                ),

                const Spacer(),

                // Language Switch (HR / EN)
                GestureDetector(
                  onTap: () => ref.read(settingsProvider.notifier).toggleLanguage(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerHigh : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          settings.language == AppLanguage.hr ? '🇭🇷' : '🇬🇧',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          settings.language == AppLanguage.hr ? 'HR' : 'EN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Theme Switch (Dark / Light) in top right corner
                GestureDetector(
                  onTap: () => ref.read(settingsProvider.notifier).toggleTheme(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerHigh : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          size: 15,
                          color: isDark ? AppColors.secondary : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isDark ? l10n.themeDark : l10n.themeLight,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          height: 20,
                          width: 32,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Switch(
                              value: isDark,
                              onChanged: (val) {
                                ref.read(settingsProvider.notifier).setDarkMode(val);
                              },
                              activeThumbColor: AppColors.secondary,
                              activeTrackColor: AppColors.primaryContainer.withValues(alpha: 0.4),
                              inactiveThumbColor: const Color(0xFFF59E0B),
                              inactiveTrackColor: AppColors.surfaceContainerLowest,
                              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
        ),
      ),
    );
  }
}
