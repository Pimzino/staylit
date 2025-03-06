import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Keys for shared preferences
const String keyEnableOnStartup = 'enable_on_startup';
const String keyThemeMode = 'theme_mode';

void main() async {
  // Ensure widgets binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load preferences
  final prefs = await SharedPreferences.getInstance();
  final enableOnStartup = prefs.getBool(keyEnableOnStartup) ?? true;

  // Enable wakelock based on preference
  if (enableOnStartup) {
    WakelockPlus.enable();
  }

  // Set up window size for desktop platforms
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(300, 400),
      minimumSize: Size(300, 400),
      maximumSize: Size(300, 400),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'StayLit',
      alwaysOnTop: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // The icon is set through the Windows runner configuration
      // in windows/runner/resources/app_icon.ico

      // Disable window maximization and resizing
      await windowManager.setPreventClose(false);
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
    });
  }

  runApp(const MyApp());
}

// Theme provider to manage theme state
class ThemeProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _initialized = false;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final themeModeIndex = _prefs.getInt(keyThemeMode);
    if (themeModeIndex != null) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }
    _initialized = true;
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  bool get isInitialized => _initialized;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveThemePreference();
    notifyListeners();
  }

  void _saveThemePreference() {
    _prefs.setInt(keyThemeMode, _themeMode.index);
  }
}

// Settings provider to manage app settings
class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _enableOnStartup = true;
  bool _initialized = false;

  SettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _enableOnStartup = _prefs.getBool(keyEnableOnStartup) ?? true;
    _initialized = true;
    notifyListeners();
  }

  bool get enableOnStartup => _enableOnStartup;

  bool get isInitialized => _initialized;

  Future<void> setEnableOnStartup(bool value) async {
    _enableOnStartup = value;
    await _prefs.setBool(keyEnableOnStartup, value);
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();
  final SettingsProvider _settingsProvider = SettingsProvider();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_themeProvider, _settingsProvider]),
      builder: (context, _) {
        return MaterialApp(
          title: 'StayLit',
          themeMode: _themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: StayLitHomePage(
            themeProvider: _themeProvider,
            settingsProvider: _settingsProvider,
          ),
        );
      }
    );
  }
}

class StayLitHomePage extends StatefulWidget {
  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;

  const StayLitHomePage({
    super.key,
    required this.themeProvider,
    required this.settingsProvider,
  });

  @override
  State<StayLitHomePage> createState() => _StayLitHomePageState();
}

class _StayLitHomePageState extends State<StayLitHomePage> {
  bool _isWakelockEnabled = true;
  Timer? _wakelockRefreshTimer;
  final int _wakelockRefreshInterval = 30; // Check wakelock every 30 seconds

  @override
  void initState() {
    super.initState();
    _checkWakelockStatus();
    // Start the periodic wakelock check
    _startWakelockRefreshTimer();
  }

  void _startWakelockRefreshTimer() {
    // Cancel any existing timer
    _wakelockRefreshTimer?.cancel();

    // Create a new timer that periodically checks and refreshes the wakelock
    _wakelockRefreshTimer = Timer.periodic(
      Duration(seconds: _wakelockRefreshInterval),
      (_) => _refreshWakelockIfEnabled()
    );
  }

  Future<void> _refreshWakelockIfEnabled() async {
    // Check current wakelock status
    final isCurrentlyEnabled = await WakelockPlus.enabled;

    // If wakelock should be enabled but isn't, re-enable it
    if (_isWakelockEnabled && !isCurrentlyEnabled) {
      debugPrint('Wakelock was released externally. Re-enabling...');
      await WakelockPlus.enable();
    }
    // If wakelock should be disabled but is enabled, disable it
    else if (!_isWakelockEnabled && isCurrentlyEnabled) {
      debugPrint('Wakelock was enabled externally. Disabling...');
      await WakelockPlus.disable();
    }

    // Update UI if needed
    final newStatus = await WakelockPlus.enabled;
    if (newStatus != _isWakelockEnabled) {
      setState(() {
        _isWakelockEnabled = newStatus;
      });
    }
  }

  @override
  void dispose() {
    // Cancel the refresh timer
    _wakelockRefreshTimer?.cancel();
    // Disable wakelock when app is closed
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _checkWakelockStatus() async {
    final isEnabled = await WakelockPlus.enabled;
    setState(() {
      _isWakelockEnabled = isEnabled;
    });
  }

  void _toggleWakelock() async {
    if (_isWakelockEnabled) {
      await WakelockPlus.disable();
    } else {
      await WakelockPlus.enable();
    }

    await _checkWakelockStatus();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          themeProvider: widget.themeProvider,
          settingsProvider: widget.settingsProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(''),
        centerTitle: true,
        toolbarHeight: 40, // Smaller app bar
        actions: [
          // Theme toggle button
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              size: 18,
            ),
            tooltip: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              widget.themeProvider.toggleTheme();
            },
          ),
          // Settings button
          IconButton(
            icon: const Icon(
              Icons.settings,
              size: 18,
            ),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // App Logo
                SvgPicture.asset(
                  'assets/logo.svg',
                  width: 70,
                  height: 70,
                ),
                const SizedBox(height: 12),

                const Text(
                  'Keep your device awake',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Display app status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.withValues(red: 128, green: 128, blue: 128, alpha: 26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: StatusRow(
                    label: 'StayLit',
                    isActive: _isWakelockEnabled,
                  ),
                ),

                const SizedBox(height: 16),

                // Control button
                ElevatedButton.icon(
                  onPressed: _toggleWakelock,
                  icon: Icon(_isWakelockEnabled ? Icons.lightbulb : Icons.lightbulb_outline, size: 18),
                  label: Text(
                    _isWakelockEnabled ? 'Disable StayLit' : 'Enable StayLit',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'This app prevents your computer from sleeping to keep you appearing "online".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;

  const SettingsPage({
    super.key,
    required this.themeProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(''),
        centerTitle: true,
        toolbarHeight: 40,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Section title
            Text(
              'General Settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            // Enable on startup setting
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.withValues(red: 128, green: 128, blue: 128, alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable on Startup',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Automatically enable StayLit when app starts',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settingsProvider.enableOnStartup,
                    onChanged: (value) {
                      settingsProvider.setEnableOnStartup(value);
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Theme settings section
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            // Theme mode setting
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.withValues(red: 128, green: 128, blue: 128, alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dark Mode',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Toggle between light and dark theme',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // About section
            Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.withValues(red: 128, green: 128, blue: 128, alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/logo.svg',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'StayLit v1.0.0',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A simple app that prevents your device from sleeping to maintain "active" status in communication apps.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusRow extends StatelessWidget {
  final String label;
  final bool isActive;

  const StatusRow({
    super.key,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.cancel,
          color: isActive ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        const Spacer(),
        Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.green : Colors.red,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
