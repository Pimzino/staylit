import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// A class that provides methods to control window behavior.
class WindowManagerUtils {
  static final WindowManagerUtils _instance = WindowManagerUtils._internal();
  bool _isAlwaysOnTop = false;
  bool _isInitialized = false;

  /// Factory constructor that returns the singleton instance
  factory WindowManagerUtils() {
    return _instance;
  }

  WindowManagerUtils._internal();

  /// Returns whether always-on-top is currently enabled
  bool get isAlwaysOnTop => _isAlwaysOnTop;

  /// Initialize the WindowManager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize WindowManager
      await windowManager.ensureInitialized();
      _isInitialized = true;
      debugPrint('WindowManager initialized');
    } catch (e) {
      debugPrint('Error initializing WindowManager: $e');
    }
  }

  /// Enables always-on-top window mode
  Future<bool> enableAlwaysOnTop() async {
    if (_isAlwaysOnTop) return true; // Already enabled

    if (!_isInitialized) {
      await initialize();
    }

    try {
      await windowManager.setAlwaysOnTop(true);
      _isAlwaysOnTop = true;
      debugPrint('Always-on-top enabled');
      return true;
    } catch (e) {
      debugPrint('Error enabling always-on-top: $e');
      return false;
    }
  }

  /// Disables always-on-top window mode
  Future<bool> disableAlwaysOnTop() async {
    if (!_isAlwaysOnTop) return true; // Already disabled

    if (!_isInitialized) {
      await initialize();
    }

    try {
      await windowManager.setAlwaysOnTop(false);
      _isAlwaysOnTop = false;
      debugPrint('Always-on-top disabled');
      return true;
    } catch (e) {
      debugPrint('Error disabling always-on-top: $e');
      return false;
    }
  }

  /// Toggle always-on-top window mode
  Future<bool> toggleAlwaysOnTop({required bool enable}) async {
    return enable ? enableAlwaysOnTop() : disableAlwaysOnTop();
  }
}