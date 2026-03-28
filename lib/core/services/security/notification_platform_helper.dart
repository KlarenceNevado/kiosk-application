import 'dart:async';

bool get isNativeAndroid => false;
bool get isNativeIOS => false;
bool get isNativeSupported => false;

Future<void> requestWebPermission() async {}
void showWebNotification(String title, String body, {String? tag}) {}
