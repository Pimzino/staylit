import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:staylit/sleep_prevention.dart';
import 'package:staylit/window_manager_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager and Tray Icon
  final windowManagerUtils = WindowManagerUtils();
  await windowManagerUtils.initWindowManager();

  runApp(
    StayLitApp(windowManagerUtils: windowManagerUtils),
  ); // Pass instance to app
}

class StayLitApp extends StatelessWidget {
  final WindowManagerUtils windowManagerUtils;

  const StayLitApp({super.key, required this.windowManagerUtils});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StayLit',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light, // Default light theme
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark, // Default dark theme
      ),
      themeMode: ThemeMode.system, // Use system theme setting
      home: StayLitHomePage(
        windowManagerUtils: windowManagerUtils,
      ), // Pass instance to home page
      debugShowCheckedModeBanner: false,
    );
  }
}

class StayLitHomePage extends StatefulWidget {
  final WindowManagerUtils windowManagerUtils;

  const StayLitHomePage({super.key, required this.windowManagerUtils});

  @override
  State<StayLitHomePage> createState() => _StayLitHomePageState();
}

class _StayLitHomePageState extends State<StayLitHomePage> {
  bool _isWakelockEnabled = false;
  final SleepPrevention _sleepPrevention = SleepPrevention();
  static const _prefsKey = 'isWakelockEnabled';

  @override
  void initState() {
    super.initState();
    _loadWakelockState();
  }

  Future<void> _loadWakelockState() async {
    final prefs = await SharedPreferences.getInstance();
    // Avoid calling setState if the widget is disposed during the async gap
    if (!mounted) return;
    setState(() {
      _isWakelockEnabled = prefs.getBool(_prefsKey) ?? false;
      _sleepPrevention.toggle(enable: _isWakelockEnabled);
    });
  }

  Future<void> _toggleWakelock() async {
    final prefs = await SharedPreferences.getInstance();
    // Avoid calling setState if the widget is disposed during the async gap
    if (!mounted) return;
    setState(() {
      _isWakelockEnabled = !_isWakelockEnabled;
      prefs.setBool(_prefsKey, _isWakelockEnabled);
      _sleepPrevention.toggle(enable: _isWakelockEnabled);
    });
  }

  @override
  void dispose() {
    widget.windowManagerUtils.dispose();
    if (_isWakelockEnabled) {
      _sleepPrevention.toggle(enable: false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.white : Colors.black87;
    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.grey[50];
    final cardColor = isDarkMode ? Colors.grey[800] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SvgPicture.asset(
                'assets/logo.svg',
                height: 80,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(height: 20),
              Text(
                'StayLit',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Keep your screen awake',
                style: TextStyle(fontSize: 16, color: subTextColor),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isWakelockEnabled ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 18,
                          color: _isWakelockEnabled ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Switch(
                        value: _isWakelockEnabled,
                        onChanged: (value) {
                          _toggleWakelock();
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Removed theme/settings buttons as they weren't defined
            ],
          ),
        ),
      ),
    );
  }
}
