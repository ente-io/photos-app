import 'dart:async';

import 'package:flutter/material.dart';
import "package:photos/models/typedefs.dart";

class Debouncer {
  final Duration _duration;

  final ValueNotifier<bool> _debounceActiveNotifier = ValueNotifier(false);

  /// If executionIntervalInSeconds is not null, then the debouncer will execute the
  /// current callback it has in run() method repeatedly in the given interval.
  /// This is useful for example when you want to execute a callback every 5 seconds
  final Duration? executionInterval;
  Timer? _debounceTimer;

  Debouncer(this._duration, {this.executionInterval});

  final Stopwatch _stopwatch = Stopwatch();

  void run(FutureVoidCallback fn) {
    bool shouldRunImmediately = false;
    if (executionInterval != null) {
      // ensure the stop watch is running
      _stopwatch.start();
      if (_stopwatch.elapsedMilliseconds > executionInterval!.inMilliseconds) {
        shouldRunImmediately = true;
        _stopwatch.stop();
        _stopwatch.reset();
      }
    }

    if (isActive()) {
      _debounceTimer!.cancel();
    }
    _debounceTimer =
        Timer(shouldRunImmediately ? Duration.zero : _duration, () async {
      _stopwatch.stop();
      _stopwatch.reset();
      await fn();
      _debounceActiveNotifier.value = false;
    });
    _debounceActiveNotifier.value = true;
  }

  void cancelDebounce() {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
  }

  bool isActive() => _debounceTimer != null && _debounceTimer!.isActive;

  ValueNotifier<bool> get debounceActiveNotifier {
    return _debounceActiveNotifier;
  }
}
