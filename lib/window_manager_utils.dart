import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

/// A class that provides methods to control window behavior.
class WindowManagerUtils implements WindowListener, TrayListener {
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

  Future<void> initWindowManager() async {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(300, 450), // Slightly larger for better spacing
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false, // Keep in taskbar when visible
      titleBarStyle: TitleBarStyle.hidden, // Revert back to hidden
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // Prevent closing initially, handle via tray
      await windowManager.setPreventClose(true);
    });

    windowManager.addListener(this);
    await initTray(); // Initialize the tray icon
  }

  Future<void> initTray() async {
    // Get the directory where the executable is located
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // Build absolute path to the icon (Flutter assets are in data/flutter_assets/assets/)
    final iconPath = '$exeDir/data/flutter_assets/assets/logo.ico';

    debugPrint('Tray icon path: $iconPath');
    debugPrint('Icon exists: ${File(iconPath).existsSync()}');

    await trayManager.setIcon(iconPath);
    await setTrayMenu();
    trayManager.addListener(this);
  }

  Future<void> setTrayMenu() async {
    List<MenuItem> items = [
      MenuItem(key: 'show_window', label: 'Show App'),
      MenuItem.separator(),
      MenuItem(key: 'quit_app', label: 'Quit StayLit'),
    ];
    await trayManager.setContextMenu(Menu(items: items));
    await trayManager.setToolTip('StayLit - Click to Show/Hide');
  }

  @override
  void onWindowClose() async {
    // Keep hiding the window to the tray on close
    await windowManager.hide();
  }

  @override
  void onWindowFocus() {
    // setState(() {}); // Might be needed if UI depends on focus
  }

  @override
  void onWindowBlur() {
    // setState(() {});
  }

  // ... other WindowListener methods (onWindowMaximize, etc.) - keep empty if not needed
  @override
  void onWindowMaximize() {}
  @override
  void onWindowUnmaximize() {}
  @override
  void onWindowMinimize() {}
  @override
  void onWindowRestore() {}
  @override
  void onWindowResize() {}
  @override
  void onWindowMove() {}
  @override
  void onWindowEnterFullScreen() {}
  @override
  void onWindowLeaveFullScreen() {}

  // Add missing overrides from WindowListener
  @override
  void onWindowMoved() {}
  @override
  void onWindowResized() {} // Added missing override
  @override
  void onWindowDocked() {}
  @override
  void onWindowUndocked() {}
  @override
  void onWindowEvent(String eventName) {
    // Optional: Handle specific platform events if needed
    // print('[WindowManager] onWindowEvent: $eventName');
  }

  // --- TrayListener Methods ---

  @override
  void onTrayIconMouseDown() async {
    // Show/hide window on left-click
    bool isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    // Show context menu on right-click
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
        windowManager.focus();
        break;
      case 'quit_app':
        // Cleanly exit the application
        trayManager.destroy(); // Remove tray icon
        windowManager.destroy(); // Close the window and exit app
        break;
    }
  }

  // Required override, even if empty
  @override
  void onTrayIconRightMouseUp() {}

  // Add missing override from TrayListener
  @override
  void onTrayIconMouseUp() {}

  /// Cleanly quits the application by destroying the tray and window.
  Future<void> quitApplication() async {
    try {
      await trayManager.destroy();
    } catch (e) {
      debugPrint('Error destroying tray icon: $e');
    }
    try {
      await windowManager.destroy();
    } catch (e) {
      debugPrint('Error destroying window: $e');
    }
  }

  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }
}
