import 'dart:io';

bool get isNativeAndroid => Platform.isAndroid;
bool get isNativeIOS => Platform.isIOS;
bool get isNativeWindows => Platform.isWindows;
bool get isNativeSupported =>
    Platform.isAndroid || Platform.isIOS || Platform.isWindows;

Future<void> requestWebPermission() async {}
void showWebNotification(String title, String body, {String? tag}) {}
