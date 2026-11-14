import '../models/app_settings.dart';

class L10n {
  final AppLanguage language;
  const L10n(this.language);

  bool get isHr => language == AppLanguage.hr;

  // Header & Navigation
  String get appTitle => 'AllDown';
  String get quickDownload => isHr ? 'Brzo Preuzimanje' : 'Quick Download';
  String get transfersQueue => isHr ? 'Red Čekanja' : 'Transfers Queue';
  String get mediaLibrary => isHr ? 'Medijska Biblioteka' : 'Media Library';
  String get appSettings => isHr ? 'Postavke Aplikacije' : 'App Settings';

  String get navDown => isHr ? 'Preuzmi' : 'Down';
  String get navQueue => isHr ? 'Red' : 'Queue';
  String get navLibrary => isHr ? 'Biblioteka' : 'Library';
  String get navSettings => isHr ? 'Postavke' : 'Settings';

  String get themeDark => isHr ? 'Tamno' : 'Dark';
  String get themeLight => isHr ? 'Svijetlo' : 'Light';

  // Home Screen
  String get mediaUrlOrStream => isHr ? 'Poveznica medija ili izravni stream' : 'Media URL or Direct Stream Link';
  String get paste => isHr ? 'Zalijepi' : 'Paste';
  String get pasteLinkHint => isHr 
      ? 'Zalijepite poveznicu s YouTubea, TikToka, Instagrama, Reddita...' 
      : 'Paste link from YouTube, Vimeo, TikTok, Bilibili...';
  String get fetchAndAnalyze => isHr ? 'Dohvati i analiziraj medij' : 'Fetch & Analyze Media';
  String get analyzingMedia => isHr ? 'Analiziranje medijskog toka...' : 'Analyzing media stream...';
  String get noMediaDetected => isHr ? 'Nije pronađena poveznica' : 'No media link detected';
  String get noMediaSub => isHr
      ? 'Zalijepite video link iznad za pregled metapodataka, odabir formata i preuzimanje.'
      : 'Paste a YouTube, Shorts, TikTok, or video link above to view metadata, format options, and start downloading.';
  String get pasteFromClipboard => isHr ? 'Zalijepi iz međuspremnika' : 'Paste from Clipboard';
  String get targetFormat => isHr ? 'Željeni Format' : 'Target Format';
  String get advancedConfig => isHr ? 'Napredno' : 'Advanced Config';
  String get videoMp4 => 'Video (MP4)';
  String get audioM4a => 'Audio (M4A)';
  String get audioOpus => 'Audio (Opus)';
  String get customRaw => isHr ? 'Izvorni Tok' : 'Custom Raw';
  String get resolutionAndQuality => isHr ? 'Rezolucija i kvaliteta' : 'Resolution & Stream Quality';
  String startDownload(String quality) => isHr ? 'Pokreni preuzimanje ($quality)' : 'Start Download ($quality)';
  String get addedToQueue => isHr ? 'Dodano u red čekanja' : 'Added to Queue';
  String get tapToViewQueue => isHr ? 'Dodirnite za pregled u Redu' : 'Tap to view in Queue tab';
  String get viewQueue => isHr ? 'Otvori Red' : 'View Queue';
  String get liveStream => isHr ? 'Prijenos uživo' : 'Live Stream';
  String get bestQuality => isHr ? 'Najbolja kvaliteta' : 'Best Quality';
  String get highDefinition => isHr ? 'Visoka rezolucija' : 'High Definition';
  String get standardDef => isHr ? 'Standardna kvaliteta' : 'Standard Definition';
  String get lowData => isHr ? 'Ušteda podataka' : 'Low Data';
  String get pristineAudio => isHr ? 'Kristalno čist zvuk' : 'Pristine Audio';
  String get duration => isHr ? 'Trajanje' : 'Duration';
  String get views => isHr ? 'Pregleda' : 'Views';

  // Playlist Strings
  String get playlist => isHr ? 'Playlista' : 'Playlist';
  String get youtubePlaylist => isHr ? 'YouTube Playlista' : 'YouTube Playlist';
  String playlistTracksCount(int count) => isHr ? '$count pjesama' : '$count tracks';
  String get audioModeBadge => 'Audio (M4A) • 320 kbps';
  String downloadAllCount(int count) => isHr ? 'Preuzmi svih $count pjesama' : 'Download all $count tracks';
  String get selectTracks => isHr ? 'Odaberi pjesme' : 'Select tracks';
  String get selectTracksTitle => isHr ? 'Odaberi pjesme za preuzimanje' : 'Select tracks to download';
  String get searchTracks => isHr ? 'Pretraži pjesme u playlisti...' : 'Search playlist tracks...';
  String get selectAll => isHr ? 'Označi sve' : 'Select all';
  String get deselectAll => isHr ? 'Odznači sve' : 'Deselect all';
  String selectedTracksSummary(int sel, int total) => isHr ? 'Odabrano: $sel od $total pjesama' : 'Selected: $sel of $total tracks';
  String downloadSelectedCount(int count) => isHr ? 'Preuzmi odabrano ($count)' : 'Download selected ($count)';
  String playlistQueuedMessage(int count) => isHr ? 'Dodano $count pjesama u red čekanja' : 'Added $count tracks to queue';
  String get noTracksSelected => isHr ? 'Nijedna pjesma nije odabrana' : 'No tracks selected';
  String get audioOnlyPlaylistNotice => isHr ? 'Automatski M4A (320 kbps) za vrhunsku kvalitetu zvuka' : 'Default M4A (320 kbps) for crystal-clear audio';

  // Queue Screen
  String get active => isHr ? 'Aktivno' : 'Active';
  String get completed => isHr ? 'Dovršeno' : 'Completed';
  String get paused => isHr ? 'Pauzirano' : 'Paused';
  String get noTasksInCategory => isHr ? 'Nema zadataka u ovoj kategoriji' : 'No tasks in this category';
  String get noTasksSub => isHr 
      ? 'Preuzimanja koja pokrenete prikazat će se ovdje s prikazom brzine i napretka u stvarnom vremenu.'
      : 'Downloads you start will appear here with live speed and progress tracking.';
  String get pauseAll => isHr ? 'Pauziraj sve' : 'Pause All';
  String get resumeAll => isHr ? 'Nastavi sve' : 'Resume All';
  String get clean => isHr ? 'Očisti' : 'Clean';
  String get queuePipeline => isHr ? 'Red Preuzimanja' : 'Queue Pipeline';
  String get highPriority => isHr ? 'Visoki prioritet' : 'High Priority';
  String get autoOrder => isHr ? 'Auto-redoslijed' : 'Auto-Order';
  String concurrencyLimit(int count) => isHr 
      ? 'Maksimalno $count istovremena preuzimanja' 
      : 'Concurrency Limit: Max $count Parallel Tasks Enabled';
  String get speedIdle => isHr ? 'Status: Mirovanje' : 'Status: Idle';
  String get speedActive => isHr ? 'Status: Preuzimanje' : 'Status: Downloading';
  String activeQueued(int a, int q) => isHr ? '$a Aktivno • $q Na čekanju' : '$a Active • $q Queued';
  String get cancelTask => isHr ? 'Otkaži' : 'Cancel';
  String get retryTask => isHr ? 'Ponovi' : 'Retry';
  String get openMediaFile => isHr ? 'Otvori' : 'Open';
  String get downloadFinished => isHr ? 'Dovršeno' : 'Completed';
  String get transfersCleared => isHr ? 'Dovršeni prijenosi su očišćeni' : 'Completed transfers cleared';

  // Library Screen
  String searchDownloaded(int count) => isHr 
      ? 'Pretraži $count preuzetih datoteka...' 
      : 'Search $count downloaded media files...';
  String categoryAll(int count) => isHr ? 'Sve ($count)' : 'All ($count)';
  String categoryVideos(int count) => isHr ? 'Videozapisi ($count)' : 'Videos ($count)';
  String categoryAudio(int count) => isHr ? 'Zvuk ($count)' : 'Audio ($count)';
  String categoryPlaylists(int count) => isHr ? 'Playliste ($count)' : 'Playlists ($count)';
  String categoryFavorites(int count) => isHr ? 'Favoriti ($count)' : 'Favorites ($count)';
  String get playAll => isHr ? 'Pokreni sve' : 'Play All';
  String get selectTracksAction => isHr ? 'Odaberi' : 'Select';
  String get playAsPlaylist => isHr ? 'Pokreni kao playlistu' : 'Play as Playlist';
  String get saveAsPlaylist => isHr ? 'Spremi kao playlistu' : 'Save as Playlist';
  String get newPlaylist => isHr ? 'Nova playlista' : 'New Playlist';
  String get createPlaylist => isHr ? 'Stvori playlistu' : 'Create Playlist';
  String get playlistName => isHr ? 'Naziv playliste' : 'Playlist Name';
  String get enterPlaylistName => isHr ? 'Unesite naziv nove playliste...' : 'Enter playlist name...';
  String get playlistCreated => isHr ? 'Playlista uspješno stvorena' : 'Playlist created successfully';
  String get playlistDeleted => isHr ? 'Playlista obrisana' : 'Playlist deleted';
  String get deletePlaylistConfirm => isHr ? 'Želite li sigurno obrisati ovu playlistu?' : 'Are you sure you want to delete this playlist?';
  String get upNextQueue => isHr ? 'Red izvođenja' : 'Up Next';
  String get nowPlaying => isHr ? 'Trenutno se izvodi' : 'Now Playing';
  String get repeatModeAll => isHr ? 'Ponavljaj sve' : 'Repeat All';
  String get repeatModeOne => isHr ? 'Ponavljaj jednu' : 'Repeat One';
  String get repeatModeOff => isHr ? 'Bez ponavljanja' : 'Repeat Off';
  String get shuffleEnabled => isHr ? 'Slučajni redoslijed uključen' : 'Shuffle On';
  String get shuffleDisabled => isHr ? 'Slučajni redoslijed isključen' : 'Shuffle Off';
  String get noPlaylistsYet => isHr ? 'Nema spremljenih playlista' : 'No saved playlists yet';
  String get noPlaylistsSub => isHr ? 'Odaberite pjesme iz biblioteke i stvorite vlastitu kolekciju za slušanje.' : 'Select audio tracks from your library to create custom listening collections.';
  String selectedCount(int count) => isHr ? 'Odabrano: $count' : 'Selected: $count';
  String get cancelSelection => isHr ? 'Odustani' : 'Cancel';
  String get saveQueueAsPlaylist => isHr ? 'Spremi red u playlistu' : 'Save queue as playlist';
  String get localStorageUsed => isHr ? 'Zauzeće memorije' : 'Local Storage Used';
  String usedFiles(String mb, int files) => isHr 
      ? '$mb iskorišteno ($files datoteka)' 
      : '$mb used ($files files)';
  String get sortNewest => isHr ? 'Najnovije' : 'Newest';
  String get sortOldest => isHr ? 'Najstarije' : 'Oldest';
  String get sortLargest => isHr ? 'Najveće' : 'Largest';
  String get sortTitle => isHr ? 'Naziv A-Z' : 'Title A-Z';
  String get noMediaYet => isHr ? 'Još nema preuzetih datoteka' : 'No downloaded media files yet';
  String get noMediaYetSub => isHr
      ? 'Videozapisi i audio zapisi koje preuzmete pojavit će se ovdje i možete ih reproducirati izravno u aplikaciji.'
      : 'Videos and audio tracks you download will appear here and can be played directly inside AllDown.';
  String get completedJustNow => isHr ? 'Upravo dovršeno' : 'Completed Just Now';
  String get completedToday => isHr ? 'Danas' : 'Today';
  String get tapToPlay => isHr ? 'Dodirnite za reprodukciju' : 'Tap to play';
  String get playAction => isHr ? 'Pokreni' : 'Play';
  String get shareAction => isHr ? 'Podijeli' : 'Share';
  String get deleteAction => isHr ? 'Obriši' : 'Delete';
  String get editMakeGif => isHr ? 'Uredi / Stvori GIF' : 'Edit / Make GIF';

  // Settings Screen
  String get cookiesAndAuth => isHr ? 'Kolačići preglednika i prijava' : 'Browser Cookies & Auth';
  String cookiesActive(int count) => isHr ? 'Kolačići aktivni ($count unosa učitano)' : 'Cookies Active ($count entries loaded)';
  String get noCookiesLoaded => isHr ? 'Nema učitanih kolačića (Javni tokovi)' : 'No cookies loaded (Public streams active)';
  String get cookiesDescription => isHr
      ? 'Zaobiđite dobna ograničenja (18+), privatne kanale za članove i prijave bez ponovnog unosa vjerodajnica.'
      : 'Bypass 18+ age restrictions, private member-only channels, and login walls safely without re-authenticating repeatedly.';
  String get importCookies => isHr ? 'Uvezi Netscape datoteku' : 'Import Netscape File';
  String get clearCookies => isHr ? 'Ukloni kolačiće' : 'Clear Cookies';
  String get cookiesLoadedSuccess => isHr ? 'Kolačići uspješno učitani' : 'Cookies loaded successfully';
  String get cookiesClearedMsg => isHr ? 'Kolačići su uklonjeni' : 'Cookies cleared';

  String get sectionDownloadMedia => isHr ? 'POSTAVKE PREUZIMANJA I MEDIJA' : 'DOWNLOAD & MEDIA SETTINGS';
  String get videoContainerSettings => isHr ? 'Postavke videa i spremnika' : 'Video & Container Settings';
  String videoSettingsSummary(String fmt, String res) => isHr 
      ? 'Format: $fmt • Maks. rezolucija: $res' 
      : 'Format: $fmt • Max Resolution: $res';
  String get defaultVideoContainer => isHr ? 'Zadani video spremnik (format)' : 'Default Video Container';
  String get defaultVideoContainerSub => isHr ? 'Preporučeni format za pohranu videa' : 'Preferred media container for downloads';
  String get defaultMaxRes => isHr ? 'Zadana / Maksimalna rezolucija' : 'Default / Max Video Resolution';
  String get defaultMaxResSub => isHr ? 'Najveća dopuštena razlučivost toka' : 'Maximum stream resolution cap';
  String get autoRemuxMp4 => isHr ? 'Automatski spremi kao MP4' : 'Auto-remux to MP4';
  String get autoRemuxMp4Sub => isHr ? 'Pretvori HLS / fragmentirane tokove u standardni MP4' : 'Convert segmented / HLS streams into unified MP4';

  String get audioExtractionAndQuality => isHr ? 'Kvaliteta i ekstrakcija zvuka' : 'Audio Extraction & Quality';
  String audioSettingsSummary(String codec, String bitrate) => isHr 
      ? 'Kodek: $codec • Bitrate: $bitrate' 
      : 'Codec: $codec • Bitrate: $bitrate';
  String get audioFormatCodec => isHr ? 'Format zvuka (Kodek)' : 'Audio Format (Codec)';
  String get audioCodecM4aLabel => isHr ? 'M4A / AAC (Standard & Izvrsna kvaliteta)' : 'M4A / AAC (Standard & Best Quality)';
  String get audioCodecOpusLabel => isHr ? 'Opus (Visoka učinkovitost)' : 'Opus (High Efficiency)';
  String get audioQualityBitrate => isHr ? 'Kvaliteta zvuka (Bitrate)' : 'Audio Quality (Bitrate)';
  String get audioQualityBitrateSub => isHr ? 'Ciljani bitrate za izdvojeni zvuk' : 'Target bitrate for extracted audio';

  String get storageDirectoryManagement => isHr ? 'Upravljanje pohranom i mapama' : 'Storage & Directory Management';
  String storageSummary(String size, String path) => isHr ? 'Pohrana: $size' : 'Storage: $size';
  String get downloadLocation => isHr ? 'Lokacija za preuzimanje' : 'Download Location';
  String get downloadLocationSub => isHr ? 'Glavna mapa za spremanje datoteka' : 'Primary device destination for saved files';
  String get changeDirectory => isHr ? 'Promijeni mapu' : 'Change';
  String get organizeByPlatform => isHr ? 'Organiziraj po platformama' : 'Organize by Platform';
  String get organizeByPlatformSub => isHr 
      ? 'Spremi u podmape (npr. YouTube, TikTok, Instagram, Reddit)' 
      : 'Sort into subfolders (e.g. YouTube, TikTok, Instagram, Reddit)';
  String get maxConcurrentDownloads => isHr ? 'Maksimalno istovremenih preuzimanja' : 'Max Concurrent Downloads';
  String get maxConcurrentDownloadsSub => isHr ? 'Broj paralelnih preuzimanja (1 - 5)' : 'Limit parallel streams (1 - 5)';
  String get wifiOnly => isHr ? 'Preuzimanje samo preko Wi-Fi mreže' : 'Wi-Fi Only Downloads';
  String get wifiOnlySub => isHr ? 'Spriječi potrošnju mobilnih podataka' : 'Pause queue while on mobile carrier data';
  String get autoRetry => isHr ? 'Automatski ponovni pokušaj' : 'Auto-Retry on Network Failure';
  String get autoRetrySub => isHr ? 'Automatski nastavi prekinuta preuzimanja' : 'Resume dropped connections automatically';

  String get notificationsAndBackground => isHr ? 'Obavijesti i rad u pozadini' : 'Notifications & Background Service';
  String get notificationsSummary => isHr ? 'Aktivna Android pozadinska usluga' : 'Android Foreground Service with active notifications';
  String get completionNotifications => isHr ? 'Obavijesti o dovršetku' : 'Completion Notifications';
  String get completionNotificationsSub => isHr ? 'Prikaži obavijest kada preuzimanje završi' : 'Show notification when downloads finish';

  String get sectionInfoHelp => isHr ? 'INFORMACIJE, POMOĆ I SUSTAV' : 'INFORMATION, HELP & SYSTEM';
  String get helpAndUserGuide => isHr ? 'Korisnički vodič i pomoć' : 'Help & User Guide';
  String get helpSummary => isHr ? 'Potpuni vodič za preuzimanja, Video Studio i formate' : 'Complete guide for downloads, Video Studio & tips';
  String get aboutAllDown => isHr ? 'O aplikaciji AllDown' : 'About AllDown';
  String get aboutSummary => isHr ? 'Pojedinosti o projektu, podržane usluge i licenca' : 'Project details, license and supported extractors';
  String get checkForUpdates => isHr ? 'Provjeri ažuriranja' : 'Check for Updates';
  String get checkingUpdates => isHr ? 'Provjera novih verzija...' : 'Checking for updates...';
  String get appUpToDate => isHr ? 'Aplikacija je ažurna!' : 'AllDown is up to date!';
  String get updateAvailable => isHr ? 'Dostupno ažuriranje' : 'Update Available';
  String get clearAppCache => isHr ? 'Isprazni privremenu memoriju' : 'Clear App Cache';
  String get clearAppCacheSub => isHr ? 'Ukloni privremene HLS segmente i sličice' : 'Purge temporary segmented chunks & image cache';
  String get cacheClearedMsg => isHr ? 'Privremena memorija je uspješno očišćena' : 'App cache cleared successfully';
  String get resetSettings => isHr ? 'Vrati sve postavke na zadano' : 'Reset All Settings to Defaults';
  String get resetSettingsSub => isHr ? 'Vraća konfiguraciju na tvorničke postavke' : 'Reverts configuration to initial factory state';
  String get settingsResetMsg => isHr ? 'Sve postavke su vraćene na zadano' : 'All settings reset to defaults';

  // Video Studio / GIF
  String get videoPlayer => isHr ? 'Video reproduktor' : 'Video Player';
  String get trimVideo => isHr ? 'Obreži video' : 'Trim Video';
  String get cropAspect => isHr ? 'Izreži kadar' : 'Crop Aspect';
  String get generateGif => isHr ? 'Stvori HD GIF' : 'Generate HD GIF';
  String get exportVideo => isHr ? 'Izvezi video' : 'Export Video';
  String get processingVideo => isHr ? 'Obrada u tijeku...' : 'Processing video...';

  // Pro Audio Player Studio & Smart Playlists
  String get playNextInQueue => isHr ? 'Sviraj sljedeće u redu' : 'Play Next in Queue';
  String get addToQueueEnd => isHr ? 'Dodaj na kraj reda' : 'Add to Queue End';
  String get trimAudio => isHr ? 'Obreži audio isječak' : 'Trim Audio Segment';
  String get audioEqualizer => isHr ? 'Ekvilajzer & Zvuk' : 'Equalizer & Audio FX';
  String get playbackSpeed => isHr ? 'Brzina reprodukcije' : 'Playback Speed';
  String get sleepTimer => isHr ? 'Mjerač spavanja' : 'Sleep Timer';
  String get abLoop => isHr ? 'A-B Ponavljanje' : 'A-B Loop';
  String get smartPlaylists => isHr ? 'Pametne playliste' : 'Smart Playlists';
  String get smartMostPlayed => isHr ? 'Najčešće slušano' : 'Most Played';
  String get smartRecentlyAdded => isHr ? 'Nedavno preuzeto' : 'Recently Added';
  String get smartFavorites => isHr ? 'Omiljene pjesme' : 'Favorite Audio';
  String get customPlaylists => isHr ? 'Vaše playliste' : 'Your Playlists';
}

