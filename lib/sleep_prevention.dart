import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A class that provides methods to prevent the device from sleeping.
class SleepPrevention {
  static final SleepPrevention _instance = SleepPrevention._internal();
  bool _isEnabled = false;
  Timer? _refreshTimer;
  final int _refreshIntervalSeconds = 30; // Refresh every 30 seconds
  Process? _caffeinateProcess; // Store reference to the MacOS caffeinate process

  /// Factory constructor that returns the singleton instance
  factory SleepPrevention() {
    return _instance;
  }

  SleepPrevention._internal();

  /// Returns whether sleep prevention is currently enabled
  bool get isEnabled => _isEnabled;

  /// Enables sleep prevention
  Future<bool> enable() async {
    if (_isEnabled) return true; // Already enabled

    final result = await _setPlatformSleepPrevention(true);
    if (result) {
      _isEnabled = true;
      _startRefreshTimer();
    }
    return result;
  }

  /// Disables sleep prevention
  Future<bool> disable() async {
    if (!_isEnabled) return true; // Already disabled

    final result = await _setPlatformSleepPrevention(false);
    if (result) {
      _isEnabled = false;
      _cancelRefreshTimer();
    }
    return result;
  }

  /// Toggle sleep prevention state
  Future<bool> toggle({required bool enable}) async {
    return enable ? this.enable() : disable();
  }

  // Private method to start a refresh timer
  void _startRefreshTimer() {
    _cancelRefreshTimer();
    _refreshTimer = Timer.periodic(
      Duration(seconds: _refreshIntervalSeconds),
      (_) => _refreshSleepPrevention(),
    );
  }

  // Private method to cancel the refresh timer
  void _cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // Private method to refresh the sleep prevention state
  Future<void> _refreshSleepPrevention() async {
    if (_isEnabled) {
      await _setPlatformSleepPrevention(true);
      debugPrint('Sleep prevention refreshed');
    }
  }

  // Private method to set platform-specific sleep prevention
  Future<bool> _setPlatformSleepPrevention(bool enable) async {
    try {
      if (Platform.isWindows) {
        return _setWindowsSleepPrevention(enable);
      } else if (Platform.isMacOS) {
        return await _setMacOSSleepPrevention(enable);
      } else {
        debugPrint('Sleep prevention not supported on this platform');
        return false;
      }
    } catch (e) {
      debugPrint('Error setting sleep prevention: $e');
      return false;
    }
  }

  // Windows implementation using Win32 API
  bool _setWindowsSleepPrevention(bool enable) {
    if (Platform.isWindows) {
      try {
        // Load kernel32.dll
        final kernel32 = DynamicLibrary.open('kernel32.dll');

        // Define SetThreadExecutionState function
        // ES_CONTINUOUS = 0x80000000
        // ES_SYSTEM_REQUIRED = 0x00000001
        // ES_DISPLAY_REQUIRED = 0x00000002

        final setThreadExecutionState = kernel32.lookupFunction<
          Uint32 Function(Uint32),
          int Function(int)
        >('SetThreadExecutionState');

        final int esContinuous = 0x80000000;
        final int esSystemRequired = 0x00000001;
        final int esDisplayRequired = 0x00000002;

        if (enable) {
          // Set system and display required flags along with continuous flag
          setThreadExecutionState(esContinuous | esSystemRequired | esDisplayRequired);
          debugPrint('Windows sleep prevention enabled');
        } else {
          // Set only continuous flag (allows system to sleep)
          setThreadExecutionState(esContinuous);
          debugPrint('Windows sleep prevention disabled');
        }

        return true;
      } catch (e) {
        debugPrint('Error setting Windows sleep prevention: $e');
        return false;
      }
    }
    return false;
  }

  // MacOS implementation using the caffeinate command
  Future<bool> _setMacOSSleepPrevention(bool enable) async {
    if (Platform.isMacOS) {
      try {
        if (enable) {
          // First, kill any existing caffeinate processes
          await _killCaffeinateProcess();

          // Use caffeinate command to prevent sleep
          // -d prevents display sleep
          // -i prevents idle sleep
          // -s prevents system sleep
          _caffeinateProcess = await Process.start('caffeinate', ['-d', '-i', '-s']);
          _caffeinateProcess!.exitCode.then((exitCode) {
            debugPrint('Caffeinate process exited with code $exitCode');
            // If process exited unexpectedly and we still want sleep prevention
            if (_isEnabled && exitCode != 0) {
              debugPrint('Restarting caffeinate process...');
              _setMacOSSleepPrevention(true);
            }
          });

          debugPrint('MacOS sleep prevention enabled using caffeinate');
          return true;
        } else {
          // Disable by killing caffeinate process
          return await _killCaffeinateProcess();
        }
      } catch (e) {
        debugPrint('Error setting MacOS sleep prevention: $e');
        return false;
      }
    }
    return false;
  }

  // Helper method to kill the caffeinate process
  Future<bool> _killCaffeinateProcess() async {
    try {
      // Kill our specific caffeinate process if it exists
      if (_caffeinateProcess != null) {
        _caffeinateProcess!.kill();
        _caffeinateProcess = null;
      }

      // Also try to kill any other caffeinate processes that might be running
      await Process.run('pkill', ['-x', 'caffeinate']);
      debugPrint('MacOS sleep prevention disabled');
      return true;
    } catch (e) {
      debugPrint('Error killing caffeinate process: $e');
      return false;
    }
  }
}