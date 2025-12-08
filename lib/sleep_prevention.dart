import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// FFI structure for Windows MOUSEINPUT (used by SendInput)
final class MOUSEINPUT extends Struct {
  @Int32()
  external int dx; // X movement (relative pixels when MOUSEEVENTF_MOVE)
  @Int32()
  external int dy; // Y movement (relative pixels when MOUSEEVENTF_MOVE)
  @Uint32()
  external int mouseData; // Wheel movement (0 for movement)
  @Uint32()
  external int dwFlags; // MOUSEEVENTF flags
  @Uint32()
  external int time; // Timestamp (0 = system provides)
  @IntPtr()
  external int dwExtraInfo; // Extra info (0)
}

/// FFI structure for Windows INPUT (mouse variant for SendInput)
final class INPUT extends Struct {
  @Uint32()
  external int type; // INPUT_MOUSE = 0
  external MOUSEINPUT mi; // Mouse input data
}

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
      _simulateActivity(); // Simulate mouse/keyboard activity for Teams
      debugPrint('Sleep prevention refreshed + activity simulated');
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

  // Simulate user activity to prevent apps like Teams from showing "Away"
  void _simulateActivity() {
    if (Platform.isWindows) {
      _simulateWindowsMouseMove();
    } else if (Platform.isMacOS) {
      _simulateMacOSMouseMove();
    }
  }

  // Windows implementation: Inject mouse movement events using SendInput
  // Note: SendInput injects actual input events into the input stream,
  // which is detected by Teams (unlike SetCursorPos which only moves cursor position)
  void _simulateWindowsMouseMove() {
    if (!Platform.isWindows) return;

    // Constants for SendInput
    const int inputMouse = 0; // INPUT_MOUSE
    const int mouseeventfMove = 0x0001; // MOUSEEVENTF_MOVE (relative movement)

    try {
      final user32 = DynamicLibrary.open('user32.dll');

      // Get SendInput function
      final sendInput = user32.lookupFunction<
          Uint32 Function(Uint32 cInputs, Pointer<INPUT> pInputs, Int32 cbSize),
          int Function(int cInputs, Pointer<INPUT> pInputs, int cbSize)>('SendInput');

      // Allocate INPUT structure
      final input = calloc<INPUT>();

      try {
        // Configure for relative mouse movement (1 pixel right)
        input.ref.type = inputMouse;
        input.ref.mi.dx = 1; // Move 1 pixel right
        input.ref.mi.dy = 0;
        input.ref.mi.mouseData = 0;
        input.ref.mi.dwFlags = mouseeventfMove; // Relative movement
        input.ref.mi.time = 0; // System provides timestamp
        input.ref.mi.dwExtraInfo = 0;

        // Send mouse move right (injects into input stream)
        final result1 = sendInput(1, input, sizeOf<INPUT>());

        // Move back left (1 pixel)
        input.ref.mi.dx = -1;
        final result2 = sendInput(1, input, sizeOf<INPUT>());

        debugPrint('Windows mouse activity simulated via SendInput (results: $result1, $result2)');
      } finally {
        // Free allocated memory
        calloc.free(input);
      }
    } catch (e) {
      debugPrint('Error simulating Windows mouse movement: $e');
    }
  }

  // macOS implementation: Simulate activity using osascript
  Future<void> _simulateMacOSMouseMove() async {
    if (!Platform.isMacOS) return;

    try {
      // Use AppleScript to simulate F13 key press (harmless, no visible effect)
      // F13 is key code 105 - it doesn't do anything in most apps
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to key code 105',
      ]);
      debugPrint('macOS activity simulated (F13 key)');
    } catch (e) {
      debugPrint('Error simulating macOS activity: $e');
    }
  }
}