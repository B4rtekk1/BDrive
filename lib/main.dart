import 'package:flutter/material.dart';
import 'package:serverapp/pages/home_page.dart';
import 'package:serverapp/pages/files_explorer.dart';
import 'package:serverapp/pages/settings_page.dart';
import 'package:serverapp/models/destination.dart';
import 'package:serverapp/services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serverapp/pages/login_page.dart';
import 'package:serverapp/pages/register_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    throw Exception('Error loading .env file: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final ApiService _apiService = ApiService();
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      await _apiService.init();
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
        });
      }
    }
  }

  void _onLoginSuccess() {
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  Future<void> _onLogout() async {
    await _apiService.logout();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: _isLoggedIn
          ? MyHomePage(
              title: "File Manager",
              apiService: _apiService,
              onLogout: _onLogout,
            )
          : LoginPage(apiService: _apiService, onLoginSuccess: _onLoginSuccess),
      routes: {
        '/login': (context) => LoginPage(
              apiService: _apiService,
              onLoginSuccess: _onLoginSuccess,
            ),
        '/register': (context) => RegisterPage(
              apiService: _apiService,
              onRegisterSuccess: () => Navigator.pushNamed(context, '/login'),
            ),
        '/home': (context) => MyHomePage(
              title: "File Manager",
              apiService: _apiService,
              onLogout: _onLogout,
            ),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final ApiService apiService;
  final VoidCallback onLogout;

  const MyHomePage({
    super.key,
    required this.title,
    required this.apiService,
    required this.onLogout,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color appBarColor = allDestinations[_selectedIndex].color;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(apiService: widget.apiService),
          FilesExplorerPage(apiService: widget.apiService),
          SettingsPage(apiService: widget.apiService),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting,
        items: allDestinations.map((Destination destination) {
          return BottomNavigationBarItem(
            icon: Icon(destination.icon),
            activeIcon: Icon(destination.selectedIcon),
            label: destination.title,
            backgroundColor: destination.color,
          );
        }).toList(),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}