// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool get isNativeAndroid => false;
bool get isNativeIOS => false;
bool get isNativeSupported => web.Notification.permission != 'denied';

/// Requests notification permission on Web
Future<void> requestWebPermission() async {
  if (web.Notification.permission == 'default') {
    await web.Notification.requestPermission().toDart;
  }
}

/// Shows a browser notification
void showWebNotification(String title, String body) {
  if (web.Notification.permission == 'granted') {
    web.Notification(title, web.NotificationOptions(
      body: body,
      icon: 'icons/Icon-192.png',
    ));
  }
}
