import 'package:flutter/material.dart';

class MobileNavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void goToInbox() {
    setIndex(2); // Inbox is at index 2
  }

  void goToAnnouncements() {
    setIndex(3); // Announcements is now at index 3
  }

  void goToDashboard() {
    setIndex(0);
  }
}
