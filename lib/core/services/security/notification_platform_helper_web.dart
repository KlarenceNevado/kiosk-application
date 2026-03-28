import 'dart:html' as html;

bool get isNativeAndroid => false;
bool get isNativeIOS => false;
bool get isNativeSupported => html.Notification.permission != 'denied';

/// Requests notification permission on Web
Future<void> requestWebPermission() async {
  if (html.Notification.permission == 'default') {
    await html.Notification.requestPermission();
  }
}

/// Shows a browser notification
void showWebNotification(String title, String body) {
  if (html.Notification.permission == 'granted') {
    html.Notification(title, body: body, icon: 'icons/Icon-192.png');
  }
}
