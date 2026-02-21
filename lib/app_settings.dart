import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _darkMode = false;

  bool get darkMode => _darkMode;

  void setDarkMode(bool value) {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
  }
}

final AppSettings appSettings = AppSettings();
