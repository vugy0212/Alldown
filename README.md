<div align="center">

<img src="assets/app_logo.png" alt="AllDown Logo" width="140" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0,0,0,0.5);" />

# AllDown
### Modern Media Downloader & Video Studio for Android

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?logo=android&logoColor=white)](https://android.com)
[![Version](https://img.shields.io/badge/Version-1.0.0-6366F1?style=flat)](https://github.com/vugy0212/Alldown)
[![Author](https://img.shields.io/badge/Author-Allen-10B981?style=flat)](https://github.com/vugy0212/Alldown)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

*AllDown is a next-generation, high-performance multimedia downloading and video editing studio for Android, built with Flutter, Riverpod, Media3 ExoPlayer, and native hardware-accelerated processing.*

---

[Ključne Značajke](#-ključne-značajke--key-features) • [Podržani Servisi](#-podržani-servisi--supported-platforms) • [Video Studio & GIF](#-video-studio--hd-gif-generator) • [Instalacija](#-instalacija--getting-started) • [O Aplikaciji](#-o-aplikaciji--about)

</div>

---

## 🌟 Ključne Značajke / Key Features

- ⚡ **Multi-threaded High-Speed Engine:** Paralelno preuzimanje videozapisa i zvuka s automatskim prepoznavanjem najviše dostupne kvalitete (4K, 1440p, 1080p, 720p).
- 🎬 **Ugrađeni Video Studio (Video Editor):**
  - **Precizni Video Trimmer:** Izrezivanje isječaka u milisekundu s dvostrukim vremenskim klizačem i trenutnim ponavljanjem (loop preview).
  - **Interaktivni Frame Cropper:** Podešavanje omjera kadra (`16:9`, `9:16` Reels/Shorts, `1:1` Kvadrat, `4:5` Portret, `21:9` Cinematic).
  - **Dodirno zumiranje i pomicanje (Touch Pan & Zoom):** Glatko pozicioniranje kadra povlačenjem prsta po videu u stvarnom vremenu.
- 🎞️ **Izrada HD Animirani GIF-ova:**
  - Napredni **Median-Cut** algoritam za kvantizaciju palete s **Floyd-Steinberg** difuzijom pogreške.
  - Vrhunski 256-bojni GIF-ovi visoke rezolucije bez crnog ekrana ili artefakata.
- 📱 **Sinkronizacija s Galerijom (Samsung & Android 14+):**
  - Automatsko indeksiranje u sistemske albume (`Movies/AllDown` za video i `Pictures/AllDown` za GIF-ove) bez dupliciranja datoteka.
- 🛡️ **Bypass 18+ Ograničenja (Browser Cookies):**
  - Uvoz Netscape `cookies.txt` formata za pristup privatnim, dobnim ili članarinom zaštićenim videozapisima.
- 🎧 **Audio Studio:**
  - Ekstrakcija zvuka u MP3 (320 kbps Studio Master), M4A / AAC, te Opus i FLAC formate.
- 🎛️ **Interaktivni Harmonika Izbornici (Expandable Settings):**
  - Modularne postavke s padajućim izbornicima za formate, korisničke agente (User-Agent), mrežne dretve i limite brzine.
- 🚫 **SponsorBlock Filtar (v5.8):**
  - Automatsko preskakanje sponzoriranih dijelova, uvoda i odjava u videozapisima.

---

## 🌐 Podržani Servisi / Supported Platforms

Aplikacija uključuje univerzalni sustav prepoznavanja i namjenske ekstrakcijske module za više od 12 servisa:

| Servis / Platforma | Podržani Formati | Status Modula |
|:-------------------|:-----------------|:-------------:|
| **YouTube & Shorts** | 4K, 1440p, 1080p, 720p, 360p, M4A Audio | ✅ **Aktivan** |
| **X (Twitter)** | HD MP4 videozapisi izravno iz postova | ✅ **Aktivan** |
| **TikTok** | No-Watermark MP4 u izvornoj rezoluciji | ✅ **Aktivan** |
| **Facebook Watch & Reels** | 1080p Full HD i 480p SD streamovi | ✅ **Aktivan** |
| **Streamable** | Izravna API integracija za 720p/1080p MP4 | ✅ **Aktivan** |
| **Archive.org** | Otvoreni filmovi, audiozapisi i arhivski streamovi | ✅ **Aktivan** |
| **Wikimedia Commons** | Javna multimedijska domena (WebM / MP4) | ✅ **Aktivan** |
| **Test-Videos CDN** | Visokobrzinski globalni H.264 / AAC poslužitelji | ✅ **Aktivan** |
| **W3Schools & HTML5 Portali** | HTML5 `<video>` i `<source>` web streamovi | ✅ **Aktivan** |
| **GitHub Raw & Assets** | Repozitoriji s izravnim medijskim datotekama | ✅ **Aktivan** |
| **Dailymotion & Vimeo** | OpenGraph `og:video` i web media scraper | ✅ **Aktivan** |
| **Univerzalni Direktni Mediji** | Bilo koji izravni `.mp4`, `.webm`, `.m4a`, `.mp3`, `.wav` | ✅ **Aktivan** |

---

## ✂️ Video Studio & HD GIF Generator

AllDown dolazi s profesionalnim ugrađenim studijem za obradu medija bez potrebe za vanjskim aplikacijama:

```
┌────────────────────────────────────────────────────────┐
│                  ALLDOWN VIDEO STUDIO                  │
├────────────────────────────────────────────────────────┤
│  [ Trim Slider ]  ──[==================]──  00:15 / 00:30│
│                                                        │
│  [ Omjeri Kadra ]                                      │
│  (•) Izvorni    ( ) 16:9    ( ) 9:16    ( ) 1:1    ... │
│                                                        │
│  [ Zumiranje & Pozicija ]                              │
│  (-) ──────────[ 1.4x ]────────── (+)                  │
│  Pozicija X: [-1.0 ... 0.0 ... +1.0]                   │
│  Pozicija Y: [-1.0 ... 0.0 ... +1.0]                   │
│  (Podržano povlačenje prstom izravno po video kadru)  │
│                                                        │
│  [ SPREMI VIDEO (MP4) ]         [ IZRADI GIF (HD) ]    │
└────────────────────────────────────────────────────────┘
```

### Prednosti izrade GIF-a:
1. **Pravi 256-bojni prikaz:** Korištenje napredne Median-Cut palete eliminira crne sjene i pruža bistru, oštru sliku.
2. **Floyd-Steinberg Dithering:** Uklanja prijelaze boja (color banding) i pruža prirodne gradijente.
3. **Ugrađeni GIF Preglednik:** Native Flutter dekodiranje omogućuje trenutnu reprodukciju GIF-a unutar aplikacije i MediaStore galerije.

---

## 📱 Tehnološki Stog / Tech Stack

- **Framework:** [Flutter](https://flutter.dev) (Dart 3.x)
- **State Management:** [Riverpod](https://riverpod.dev) 2.x
- **Audio/Video Engine:** Google Media3 ExoPlayer, VideoPlayer & FFmpeg Android ARM64
- **Dizajn Sustav:** Dark Mode inspiriran Material You / Stitch dizajnom (`#131319`, `#6366F1`, `#06B6D4`, `#10B981`)
- **Pozadinske Usluge:** Android Foreground Service s dinamičkim ažuriranjem napretka u traci obavijesti
- **Pohrana:** Android Scoped Storage s automatskim `MediaScannerConnection` protokolom

---

## 🚀 Instalacija / Getting Started

### Preduvjeti
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.22 ili noviji)
- Android SDK (API level 26+ / Android 8.0 Oreo ili noviji)
- Java 17 / OpenJDK

### 1. Kloniranje repozitorija
```bash
git clone https://github.com/vugy0212/Alldown.git
cd Alldown/alldown
```

### 2. Instalacija ovisnosti
```bash
flutter pub get
```

### 3. Pokretanje testova
```bash
flutter test test/multi_service_test.dart
```

### 4. Izrada i instalacija paketa na uređaj
```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

---

## 👤 O Aplikaciji / About

- **Naziv projekta:** AllDown
- **Verzija:** 1.0 (v1.0.0 Stable)
- **Autor:** **Allen**
- **Službeni repozitorij:** [https://github.com/vugy0212/Alldown](https://github.com/vugy0212/Alldown)

---

## 📄 Licenca / License

Ovaj projekt je otvorenog koda i licenciran pod [GNU General Public License v3.0 (GPLv3)](LICENSE).
Svi korišteni moduli i biblioteke poštuju svoja izvorna licencna prava.
