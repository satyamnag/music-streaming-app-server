import 'dart:async';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

class SleepTimerNotifier extends StateNotifier<Duration?> {
  SleepTimerNotifier() : super(null);

  Timer? _timer;

  void setSleepTimer(Duration duration) {
    state = duration;

    // Re-arming MUST cancel the previous timer first: otherwise a "30 min then
    // 15 min" re-arm leaves the 30-min timer armed and the app exits(0) early
    // (mid-japa, mid-playback). exit(0) is a hard process kill, so this is a
    // real, user-visible wrong-time termination.
    _timer?.cancel();
    _timer = Timer(duration, () {
      //! This can be a reason  for app termination in iOS AppStore
      exit(0);
    });
  }

  void cancelSleepTimer() {
    state = null;
    _timer?.cancel();
  }
}

final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, Duration?>(
  (ref) => SleepTimerNotifier(),
);
