import 'package:flutter_test/flutter_test.dart';
import 'package:alldown/models/download_task.dart';
import 'package:alldown/models/download_options.dart';
import 'package:alldown/models/media_item.dart';
import 'package:alldown/models/app_settings.dart';
import 'package:alldown/l10n/l10n.dart';
import 'package:alldown/theme/app_colors.dart';

void main() {
  group('AllDown Models & Business Logic Tests', () {
    test('DownloadTask creation and copyWith', () {
      const task = DownloadTask(
        id: 'test_1',
        title: 'Cyberpunk Lo-Fi Session',
        url: 'https://youtube.com/watch?v=123',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        duration: '18:42',
        format: '1080p MP4',
        resolution: '1080p',
        sizeFormatted: '420 MB',
        progress: 0.5,
        speed: '14.8 MB/s',
        status: DownloadStatus.active,
      );

      expect(task.title, 'Cyberpunk Lo-Fi Session');
      expect(task.progress, 0.5);
      expect(task.status, DownloadStatus.active);

      final updated = task.copyWith(progress: 1.0, status: DownloadStatus.completed);
      expect(updated.progress, 1.0);
      expect(updated.status, DownloadStatus.completed);
    });

    test('DownloadOptions defaults and copyWith', () {
      const options = DownloadOptions();
      expect(options.format, TargetFormat.videoMp4);
      expect(options.quality, VideoQuality.res1080p);
      expect(options.createSubfolder, isTrue);
      expect(options.embedSubtitles, isTrue);
      expect(options.saveMetadata, isTrue);
      expect(options.subtitleLanguages, contains('hr'));
      expect(options.subtitleLanguages, contains('en'));

      final modified = options.copyWith(format: TargetFormat.audioMp3);
      expect(modified.format, TargetFormat.audioMp3);
    });

    test('MediaItem JSON serialization and deserialization', () {
      const item = MediaItem(
        id: 'lib_1',
        title: 'Modern Architecture',
        channel: 'Android Devs',
        duration: '24:15',
        thumbnailUrl: 'https://example.com/item.jpg',
        localPath: '/storage/emulated/0/Download/AllDown/Videos/test.mp4',
        format: 'MP4',
        resolution: '1080p FHD',
        sizeFormatted: '285 MB',
        completedDateFormatted: 'Completed Today, 10:14 AM',
        isFavorite: true,
      );

      final json = item.toJson();
      final restored = MediaItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.isFavorite, isTrue);
      expect(restored.format, 'MP4');
    });

    test('AppSettings defaults and configuration', () {
      const settings = AppSettings();
      expect(settings.downloadDirectory, '/storage/emulated/0/Download/AllDown');
      expect(settings.cookiesActive, isFalse);
      expect(settings.cookiesCount, 0);
      expect(settings.maxConcurrentDownloads, 3);
      expect(settings.wifiOnly, isTrue);
      expect(settings.autoRemuxToMp4, isTrue);
      expect(settings.audioCodec, AudioCodec.aac);
      expect(settings.maxResolution, MaxResolution.res1080p);
      expect(settings.organizeByPlatform, isFalse);

      final fromEmptyJson = AppSettings.fromJson({});
      expect(fromEmptyJson.cookiesActive, isFalse);
      expect(fromEmptyJson.cookiesCount, 0);
      expect(fromEmptyJson.maxResolution, MaxResolution.res1080p);

      final legacyResJson = AppSettings.fromJson({'maxResolution': 'noLimit', 'organizeByPlatform': true});
      expect(legacyResJson.maxResolution, MaxResolution.res4k);
      expect(legacyResJson.organizeByPlatform, isTrue);

      final safNormalized = AppSettings.normalizeDirectoryPath(
        'content://com.android.externalstorage.documents/tree/primary%3ADownload%2FAllDown',
      );
      expect(safNormalized, '/storage/emulated/0/Download/AllDown');
      expect(settings.resolvedUserAgent, contains('Mozilla/5.0'));
      expect(settings.language, AppLanguage.hr);

      final englishSettings = settings.copyWith(language: AppLanguage.en);
      expect(englishSettings.language, AppLanguage.en);

      final englishJson = englishSettings.toJson();
      expect(englishJson['language'], 'en');
      final restoredEnglish = AppSettings.fromJson(englishJson);
      expect(restoredEnglish.language, AppLanguage.en);
    });

    test('AppColors brand guidelines compliance', () {
      expect(AppColors.background, isNotNull);
      expect(AppColors.primaryAccent.toARGB32(), 0xFF6366F1); // Electric Indigo
      expect(AppColors.secondary.toARGB32(), 0xFF4CD7F6);     // Tactical Cyan
      expect(AppColors.tertiary.toARGB32(), 0xFF4EDEA3);      // Cyber Emerald
    });

    test('L10n translations cover Croatian and English', () {
      const hr = L10n(AppLanguage.hr);
      const en = L10n(AppLanguage.en);

      expect(hr.quickDownload, 'Brzo Preuzimanje');
      expect(en.quickDownload, 'Quick Download');

      expect(hr.navDown, 'Preuzmi');
      expect(en.navDown, 'Down');
      expect(hr.navQueue, 'Red');
      expect(en.navQueue, 'Queue');
      expect(hr.navLibrary, 'Biblioteka');
      expect(en.navLibrary, 'Library');
      expect(hr.navSettings, 'Postavke');
      expect(en.navSettings, 'Settings');

      expect(hr.themeDark, 'Tamno');
      expect(en.themeDark, 'Dark');
      expect(hr.themeLight, 'Svijetlo');
      expect(en.themeLight, 'Light');

      expect(hr.active, 'Aktivno');
      expect(en.active, 'Active');

      expect(hr.sortNewest, 'Najnovije');
      expect(en.sortNewest, 'Newest');

      expect(hr.aboutAllDown, 'O aplikaciji AllDown');
      expect(en.aboutAllDown, 'About AllDown');
    });
  });
}
