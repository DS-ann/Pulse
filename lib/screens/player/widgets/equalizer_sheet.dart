import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_container.dart';

class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  // 10-band equalizer frequencies for libmpv
  final List<double> _frequencies = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  final double _minDecibels = -15.0;
  final double _maxDecibels = 15.0;

  // Exact dB maps requested by the user, avoiding the previous percentage formulas
  final Map<String, List<double>> _presets = {
    // ── Standard ──
    'Flat':     [0.0, 0.0, 0.0, 0.0,  0.0,  0.0, 0.0, 0.0, 0.0, 0.0],
    'Perfect':  [3.0, 4.0, 2.0, 0.0, -1.0, -1.0, 0.0, 1.0, 3.0, 4.0],
    'V-Shape':  [4.0, 5.0, 3.0, 0.0, -2.0, -3.0, -1.0, 2.0, 4.0, 5.0],

    // ── Genre-Based ──
    'Acoustic':    [2.0, 2.0, 1.0, 1.0, 0.0, 1.0, 2.0, 3.0, 2.0, 1.0],
    'Classical':   [2.0, 2.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.0, 3.0],
    'Dance':       [5.0, 6.0, 3.0, 0.0, -1.0, -1.0, 1.0, 3.0, 4.0, 4.0],
    'Electronic':  [4.0, 5.0, 2.0, 0.0, -1.0,  0.0, 2.0, 3.0, 4.0, 5.0],
    'Hip-Hop':     [5.0, 6.0, 4.0, 1.0,  0.0,  0.0, 1.0, 2.0, 3.0, 3.0],
    'Jazz':        [2.0, 3.0, 2.0, 1.0,  0.0,  0.0, 1.0, 2.0, 2.0, 1.0],
    'Latin':       [3.0, 4.0, 2.0, 0.0,  1.0,  2.0, 2.0, 2.0, 3.0, 3.0],
    'Pop':         [2.0, 3.0, 1.0, 0.0,  1.0,  2.0, 3.0, 2.0, 2.0, 1.0],
    'R&B':         [3.0, 4.0, 2.0, 1.0,  0.0,  1.0, 2.0, 2.0, 2.0, 1.0],
    'Rock':        [4.0, 4.0, 2.0, -1.0, 0.0,  2.0, 3.0, 4.0, 3.0, 2.0],

    // ── Audio-Enhancement ──
    'Bass Booster':    [7.0,  8.0,  6.0,  3.0, 1.0, 0.0,  0.0,  0.0,  0.0,  0.0],
    'Bass Reducer':    [-6.0, -5.0, -3.0, -1.0, 0.0, 0.0,  0.0,  0.0,  0.0,  0.0],
    'Treble Booster':  [0.0,  0.0,  0.0,  0.0, 0.0, 0.0,  2.0,  4.0,  6.0,  7.0],
    'Treble Reducer':  [0.0,  0.0,  0.0,  0.0, 0.0, 0.0, -2.0, -4.0, -6.0, -6.0],
    'Vocal Booster':   [-2.0, -1.0,  0.0,  1.0, 3.0, 4.0,  4.0,  3.0,  1.0,  0.0],
    'Piano':           [2.0,  2.0,  1.0,  0.0, 1.0, 2.0,  2.0,  3.0,  3.0,  2.0],
    'Small Speakers':  [-3.0, -2.0,  1.0,  2.0, 1.0, 2.0,  4.0,  4.0,  2.0,  1.0],
  };

  final Map<String, double> _preAmps = {
    'Flat':     0.0,
    'Perfect':  -4.0,
    'V-Shape':  -4.5,
    'Acoustic':      -2.0,
    'Classical':     -2.5,
    'Dance':         -5.0,
    'Electronic':    -4.5,
    'Hip-Hop':       -5.0,
    'Jazz':          -2.5,
    'Latin':         -3.0,
    'Pop':           -2.0,
    'R&B':           -3.0,
    'Rock':          -3.5,
    'Bass Booster':  -7.0,
    'Bass Reducer':   0.0,
    'Treble Booster':-4.5,
    'Treble Reducer': 0.0,
    'Vocal Booster': -3.5,
    'Piano':         -2.5,
    'Small Speakers':-3.0,
  };

  String _formatFrequency(double hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k';
    }
    return '${hz.round()}';
  }

  void _applyPreset(String presetName) {
    if (presetName == 'Custom') return;
    final values = _presets[presetName]!;
    final preAmp = _preAmps[presetName] ?? 0.0;
    // Use the atomic method: one state update → one disk write → one Firestore write
    ref.read(settingsProvider.notifier).setEqualizerPresetWithValues(presetName, values, preAmp);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isEnabled = settings.equalizerEnabled;
    final activePreset = settings.equalizerPreset;
    final gains = settings.equalizerGains;
    final preAmp = settings.equalizerPreAmp;

    return GlassContainer(
      borderRadius: 24,
      blur: 24,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 520,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Equalizer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Switch(
                  value: isEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setEqualizerEnabled(value);
                  },
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.glassBorder, height: 1),

          // ── Presets ──
          Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !isEnabled,
              child: SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  children: [
                    'Custom',
                    ..._presets.keys,
                  ].map((preset) {
                    final isActive = activePreset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(preset, style: TextStyle(fontSize: 12, color: isActive ? Theme.of(context).colorScheme.primary : AppColors.textSecondary)),
                        backgroundColor: isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : AppColors.surface,
                        side: BorderSide(color: isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) : Colors.transparent),
                        onPressed: () => _applyPreset(preset),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.glassBorder, height: 1),

          // ── Bands ──
          Expanded(
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: !isEnabled,
                child: Center(
                  child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 24.0),
                    itemCount: _frequencies.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Pre-Amp Slider
                        return _buildPreAmpSlider(preAmp);
                      }
                      return _buildBandSlider(index - 1, gains[index - 1]);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPreAmpSlider(double currentGain) {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        children: [
          // DB Label
          Text(
            '${currentGain > 0 ? '+' : ''}${currentGain.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.redAccent,
                  inactiveTrackColor: AppColors.surface,
                  thumbColor: Colors.redAccent,
                ),
                child: Slider(
                  value: currentGain.clamp(-15.0, 15.0),
                  min: -15.0,
                  max: 15.0,
                  onChanged: (value) {
                    final settings = ref.read(settingsProvider.notifier);
                    if (ref.read(settingsProvider).equalizerPreset != 'Custom') {
                      settings.setEqualizerPreset('Custom');
                    }
                    settings.setEqualizerPreAmp(value, syncToFirestore: false);
                  },
                  onChangeEnd: (value) {
                    ref.read(settingsProvider.notifier).setEqualizerPreAmp(value, syncToFirestore: true);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Frequency Label
          const Text(
            'PRE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildBandSlider(int index, double currentGain) {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        children: [
          // DB Label
          Text(
            '${currentGain > 0 ? '+' : ''}${currentGain.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: AppColors.surface,
                  thumbColor: Theme.of(context).colorScheme.primary,
                ),
                child: Slider(
                  value: currentGain.clamp(_minDecibels, _maxDecibels),
                  min: _minDecibels,
                  max: _maxDecibels,
                  onChanged: (value) {
                    final settings = ref.read(settingsProvider.notifier);
                    if (ref.read(settingsProvider).equalizerPreset != 'Custom') {
                      settings.setEqualizerPreset('Custom');
                    }
                    
                    final newGains = List<double>.from(ref.read(settingsProvider).equalizerGains);
                    newGains[index] = value;
                    settings.setEqualizerGains(newGains, syncToFirestore: false);
                  },
                  onChangeEnd: (value) {
                    final newGains = List<double>.from(ref.read(settingsProvider).equalizerGains);
                    newGains[index] = value;
                    ref.read(settingsProvider.notifier).setEqualizerGains(newGains, syncToFirestore: true);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Frequency Label
          Text(
            _formatFrequency(_frequencies[index]),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
