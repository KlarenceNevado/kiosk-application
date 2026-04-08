// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  List<String> icons = ['kiosk_icon.png', 'admin_icon.png', 'patient_icon.png'];
  for (String iconName in icons) {
    File file = File('assets/icons/$iconName');
    if (!file.existsSync()) {
      print('Not found: $iconName');
      continue;
    }

    var image = img.decodeImage(file.readAsBytesSync());
    if (image == null) continue;

    // Convert to ensure we have an alpha channel natively
    if (!image.hasAlpha) {
      image = image.convert(numChannels: 4);
    }

    double radius = image.width * 0.225;
    int width = image.width;
    int height = image.height;

    for (var p in image) {
      int x = p.x;
      int y = p.y;
      bool inside = true;
      if (x < radius && y < radius) {
        double dx = radius - x;
        double dy = radius - y;
        if (dx * dx + dy * dy > radius * radius) inside = false;
      } else if (x > width - radius && y < radius) {
        double dx = x - (width - radius);
        double dy = radius - y;
        if (dx * dx + dy * dy > radius * radius) inside = false;
      } else if (x < radius && y > height - radius) {
        double dx = radius - x;
        double dy = y - (height - radius);
        if (dx * dx + dy * dy > radius * radius) inside = false;
      } else if (x > width - radius && y > height - radius) {
        double dx = x - (width - radius);
        double dy = y - (height - radius);
        if (dx * dx + dy * dy > radius * radius) inside = false;
      }

      if (!inside) {
        p.a = 0;
      }
    }

    File('assets/icons/transparent_$iconName')
        .writeAsBytesSync(img.encodePng(image));
    print('Masked $iconName to transparent_$iconName');
  }
}
