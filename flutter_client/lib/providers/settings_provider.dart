import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _darkMode = false;
  bool _playIncomingAudio = true;
  String _avatarSeed = '';

  bool get darkMode => _darkMode;
  bool get playIncomingAudio => _playIncomingAudio;
  String get avatarSeed => _avatarSeed;

  // Constructor - Load settings when provider is initialized
  SettingsProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load with defaults if not found
    _darkMode = prefs.getBool('darkMode') ?? false;
    _playIncomingAudio = prefs.getBool('playIncomingAudio') ?? true;
    _avatarSeed = prefs.getString('avatarSeed') ?? '';
    
    notifyListeners();
  }

  // Toggle dark mode
  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    
    _darkMode = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  // Toggle play incoming audio
  Future<void> setPlayIncomingAudio(bool value) async {
    if (_playIncomingAudio == value) return;
    
    _playIncomingAudio = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('playIncomingAudio', value);
  }

  // Update avatar seed
  Future<void> setAvatarSeed(String value) async {
    if (_avatarSeed == value) return;
    
    _avatarSeed = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatarSeed', value);
  }
}
