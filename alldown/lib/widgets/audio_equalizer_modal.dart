import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../providers/settings_provider.dart';
import '../services/native_downloader_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_colors.dart';

class AudioEqualizerModal extends ConsumerStatefulWidget {
  const AudioEqualizerModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AudioEqualizerModal(),
    );
  }

  @override
  ConsumerState<AudioEqualizerModal> createState() => _AudioEqualizerModalState();
}

class _AudioEqualizerModalState extends ConsumerState<AudioEqualizerModal> {
  final NativeDownloaderService _native = NativeDownloaderService();
  bool _isLoading = true;
  bool _eqEnabled = false;
  int _numBands = 5;
  List<int> _frequencies = [60, 230, 910, 3600, 14000];
  List<int> _bandLevels = [0, 0, 0, 0, 0];
  int _minLevel = -1500;
  int _maxLevel = 1500;
  List<String> _presets = [];
  int _currentPreset = -1;

  bool _bassEnabled = false;
  int _bassStrength = 0; // 0 - 1000

  bool _loudnessEnabled = false;
  int _loudnessGain = 0; // 0 - 3000 mB

  @override
  void initState() {
    super.initState();
    _loadParams();
  }

  Future<void> _loadParams() async {
    final params = await _native.getEqualizerParams();
    if (params != null && mounted) {
      setState(() {
        _eqEnabled = params['enabled'] as bool? ?? false;
        _numBands = (params['numBands'] as num?)?.toInt() ?? 5;
        _minLevel = (params['minLevel'] as num?)?.toInt() ?? -1500;
        _maxLevel = (params['maxLevel'] as num?)?.toInt() ?? 1500;

        final freqs = (params['bandFrequencies'] as List?)?.map((e) => (e as num).toInt()).toList();
        if (freqs != null && freqs.isNotEmpty) {
          _frequencies = freqs;
        }

        final levels = (params['bandLevels'] as List?)?.map((e) => (e as num).toInt()).toList();
        if (levels != null && levels.isNotEmpty) {
          _bandLevels = levels;
        }

        final pr = (params['presets'] as List?)?.map((e) => e.toString()).toList();
        if (pr != null) {
          _presets = pr;
        }

        _currentPreset = (params['currentPreset'] as num?)?.toInt() ?? -1;
        _bassEnabled = params['bassBoostEnabled'] as bool? ?? false;
        _bassStrength = (params['bassBoostStrength'] as num?)?.toInt() ?? 0;
        _loudnessEnabled = params['loudnessEnabled'] as bool? ?? false;
        _loudnessGain = (params['loudnessGain'] as num?)?.toInt() ?? 0;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFreq(int hz) {
    if (hz >= 1000) {
      final khz = hz / 1000;
      return '${khz.toStringAsFixed(khz.truncateToDouble() == khz ? 0 : 1)}k';
    }
    return '$hz';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final l10n = L10n(settings.language);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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

                    // Header with Equalizer Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.equalizer_rounded, color: AppColors.primaryAccent, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isHr ? 'Grafički Ekvilajzer' : 'Graphic Equalizer',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  l10n.isHr ? '$_numBands frekvencijskih pojaseva & pojačalo' : '$_numBands Frequency Bands & FX',
                                  style: TextStyle(fontSize: 11, color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _eqEnabled,
                          activeThumbColor: AppColors.primaryAccent,
                          onChanged: (val) async {
                            HapticService.selection();
                            setState(() => _eqEnabled = val);
                            await _native.setEqualizerEnabled(val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Presets Horizontal Bar
                    if (_presets.isNotEmpty) ...[
                      Text(
                        l10n.isHr ? 'Predlošci (Presets)' : 'Presets',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _presets.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final isSelected = _currentPreset == idx;
                            return ChoiceChip(
                              label: Text(_presets[idx], style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedColor: AppColors.primaryAccent.withValues(alpha: 0.25),
                              onSelected: _eqEnabled
                                  ? (selected) async {
                                      if (selected) {
                                        HapticService.light();
                                        setState(() => _currentPreset = idx);
                                        await _native.useEqualizerPreset(idx);
                                        _loadParams();
                                      }
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 5-Band Vertical Sliders Deck
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainer : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(_bandLevels.length, (idx) {
                              final level = _bandLevels[idx];
                              final db = (level / 100.0).toStringAsFixed(1);
                              final freqLabel = idx < _frequencies.length ? _formatFreq(_frequencies[idx]) : '';

                              return Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${db.startsWith('-') ? '' : '+'}$db',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _eqEnabled ? AppColors.secondary : AppColors.outline,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 140,
                                      child: RotatedBox(
                                        quarterTurns: -1,
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 4,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                            activeTrackColor: AppColors.primaryAccent,
                                            inactiveTrackColor: isDark ? AppColors.stroke : const Color(0xFFCBD5E1),
                                            thumbColor: AppColors.primaryAccent,
                                          ),
                                          child: Slider(
                                            value: level.toDouble().clamp(_minLevel.toDouble(), _maxLevel.toDouble()),
                                            min: _minLevel.toDouble(),
                                            max: _maxLevel.toDouble(),
                                            onChangeStart: _eqEnabled ? (_) => HapticService.selection() : null,
                                            onChangeEnd: _eqEnabled ? (_) => HapticService.selection() : null,
                                            onChanged: _eqEnabled
                                                ? (val) {
                                                    setState(() {
                                                      _bandLevels[idx] = val.toInt();
                                                      _currentPreset = -1;
                                                    });
                                                    _native.setEqualizerBandLevel(idx, val.toInt());
                                                  }
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      freqLabel,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bass Boost Deck
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainer : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.speaker_group_rounded, size: 18, color: AppColors.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.isHr ? 'Bass Boost' : 'Bass Boost',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(_bassStrength / 10).toInt()}%',
                                    style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _bassEnabled,
                                activeThumbColor: AppColors.secondary,
                                onChanged: (val) async {
                                  HapticService.selection();
                                  setState(() => _bassEnabled = val);
                                  await _native.setBassBoost(val, _bassStrength);
                                },
                              ),
                            ],
                          ),
                          Slider(
                            value: _bassStrength.toDouble().clamp(0.0, 1000.0),
                            min: 0,
                            max: 1000,
                            activeColor: AppColors.secondary,
                            onChangeStart: _bassEnabled ? (_) => HapticService.selection() : null,
                            onChangeEnd: _bassEnabled ? (_) => HapticService.selection() : null,
                            onChanged: _bassEnabled
                                ? (val) {
                                    setState(() => _bassStrength = val.toInt());
                                    _native.setBassBoost(true, val.toInt());
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Loudness Enhancer Deck (Volume Boost up to +30dB / +150%)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainer : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.stroke : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.volume_up_rounded, size: 18, color: AppColors.tertiary),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.isHr ? 'Pojačalo glasnoće (Volume Booster)' : 'Volume / Loudness Booster',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+${(_loudnessGain / 100).toStringAsFixed(1)} dB',
                                    style: TextStyle(fontSize: 11, color: AppColors.tertiary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _loudnessEnabled,
                                activeThumbColor: AppColors.tertiary,
                                onChanged: (val) async {
                                  HapticService.selection();
                                  setState(() => _loudnessEnabled = val);
                                  await _native.setLoudness(val, _loudnessGain);
                                },
                              ),
                            ],
                          ),
                          Slider(
                            value: _loudnessGain.toDouble().clamp(0.0, 3000.0),
                            min: 0,
                            max: 3000,
                            activeColor: AppColors.tertiary,
                            onChangeStart: _loudnessEnabled ? (_) => HapticService.selection() : null,
                            onChangeEnd: _loudnessEnabled ? (_) => HapticService.selection() : null,
                            onChanged: _loudnessEnabled
                                ? (val) {
                                    setState(() => _loudnessGain = val.toInt());
                                    _native.setLoudness(true, val.toInt());
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
