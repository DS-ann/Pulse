import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/sleep_timer_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/glass_container.dart';

class SleepTimerSheet extends ConsumerStatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  ConsumerState<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends ConsumerState<SleepTimerSheet> {
  Duration _selectedDuration = const Duration(minutes: 15);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(sleepTimerProvider);
    final isActive = timerState.isActive;

    return GlassContainer(
      borderRadius: 24,
      blur: 24,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 420,
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sleep Timer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (isActive)
                    Text(
                      'Running',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 1),
            
            Expanded(
              child: Center(
                child: isActive 
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: timerState.totalDuration.inSeconds > 0 
                                    ? (timerState.remaining.inSeconds / timerState.totalDuration.inSeconds).clamp(0.0, 1.0)
                                    : 0.0,
                                strokeWidth: 8,
                                color: Theme.of(context).colorScheme.primary,
                                backgroundColor: AppColors.surface,
                                strokeCap: StrokeCap.round,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bedtime, size: 32, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(height: 12),
                                  Text(
                                    _formatDuration(timerState.remaining),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'SLEEP',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                ref.read(sleepTimerProvider.notifier).togglePause();
                              },
                              icon: Icon(timerState.isPaused ? Icons.play_arrow : Icons.pause, size: 32, color: AppColors.textPrimary),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              onPressed: () {
                                ref.read(sleepTimerProvider.notifier).cancelTimer();
                              },
                              icon: const Icon(Icons.stop, size: 32, color: AppColors.textPrimary),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        textTheme: const CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 22),
                        )
                      ),
                      child: CupertinoTimerPicker(
                        mode: CupertinoTimerPickerMode.hm,
                        initialTimerDuration: _selectedDuration,
                        onTimerDurationChanged: (Duration newDuration) {
                          setState(() {
                            // Enforce constraints: min 1 minute, max 24 hours.
                            if (newDuration.inMinutes < 1) {
                              _selectedDuration = const Duration(minutes: 1);
                            } else if (newDuration.inHours >= 24) {
                              _selectedDuration = const Duration(hours: 24);
                            } else {
                              _selectedDuration = newDuration;
                            }
                          });
                        },
                      ),
                    ),
              ),
            ),
            
            if (!isActive)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ref.read(sleepTimerProvider.notifier).startTimer(_selectedDuration);
                    },
                    child: const Text('Start Timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
