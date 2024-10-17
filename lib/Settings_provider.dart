import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _darkMode = false;
  bool _notifications = true;

  bool get darkMode => _darkMode;
  bool get notifications => _notifications;

  void toggleDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
  }

  void toggleNotifications(bool value) {
    _notifications = value;
    notifyListeners();
  }
}
