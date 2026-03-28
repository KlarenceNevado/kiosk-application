import 'dart:io';

bool get isNativeAndroid => Platform.isAndroid;
bool get isNativeIOS => Platform.isIOS;
bool get isNativeSupported => Platform.isAndroid || Platform.isIOS;

Future<void> requestWebPermission() async {}
void showWebNotification(String title, String body) {}
