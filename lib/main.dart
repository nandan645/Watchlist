import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseUrl = await Settings.supabaseUrl;
  final supabaseKey = await Settings.supabaseKey;
  
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // ignore: library_private_types_in_public_api
  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final StorageService _storageService = StorageService();

  ThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final modeStr = await _storageService.getThemeMode();
    setState(() {
      if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  Future<void> changeTheme(ThemeMode themeMode) async {
    String modeStr = 'device';
    if (themeMode == ThemeMode.light) modeStr = 'light';
    if (themeMode == ThemeMode.dark) modeStr = 'dark';

    await _storageService.setThemeMode(modeStr);
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watchlist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Satoshi',
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Satoshi',
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: const TextScaler.linear(0.9),
          ),
          child: child!,
        );
      },
      home: const StartupScreen(),
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final StorageService _storageService = StorageService();
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final status = await _storageService.isLoggedIn();
    setState(() {
      _isLoggedIn = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      );
    }
    return _isLoggedIn! ? const HomeScreen() : const LoginScreen();
  }
}
