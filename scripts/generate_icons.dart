// ignore_for_file: avoid_print
// Generates flat, brand-accurate app icons for all 3 apps:
// - Solid green (#8CC63F) background
// - Solid white (#FFFFFF) symbol in the center
// Then applies a squircle transparent mask for Windows/macOS
import 'dart:io';
import 'package:image/image.dart' as img;

const int iconSize = 1024;
const int greenR = 0x8C, greenG = 0xC6, greenB = 0x3F;
const int whiteR = 0xFF, whiteG = 0xFF, whiteB = 0xFF;

void main() {
  _generateKioskIcon();
  _generateAdminIcon();
  _generatePatientIcon();

  for (final name in ['kiosk_icon.png', 'admin_icon.png', 'patient_icon.png']) {
    _applySquircleMask('assets/icons/$name', 'assets/icons/transparent_$name');
  }

  print('All icons generated and masked successfully!');
}

img.Image _greenCanvas() {
  final image = img.Image(width: iconSize, height: iconSize, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(greenR, greenG, greenB, 255));
  return image;
}

void _fillRect(img.Image image, int x, int y, int w, int h) {
  for (int py = y; py < y + h; py++) {
    for (int px = x; px < x + w; px++) {
      if (px >= 0 && px < iconSize && py >= 0 && py < iconSize) {
        image.setPixelRgba(px, py, whiteR, whiteG, whiteB, 255);
      }
    }
  }
}

/// KIOSK: Bold medical cross (+)
void _generateKioskIcon() {
  final image = _greenCanvas();
  const center = iconSize ~/ 2;
  const armW = iconSize ~/ 7;
  final armL = (iconSize * 0.55).toInt();

  _fillRect(image, center - armL ~/ 2, center - armW ~/ 2, armL, armW);
  _fillRect(image, center - armW ~/ 2, center - armL ~/ 2, armW, armL);

  File('assets/icons/kiosk_icon.png').writeAsBytesSync(img.encodePng(image));
  print('kiosk_icon.png generated.');
}

/// ADMIN: Bold shield outline + filled triangular bottom
void _generateAdminIcon() {
  final image = _greenCanvas();
  const cx = iconSize ~/ 2;
  final shieldTopY = (iconSize * 0.18).toInt();
  final shieldBotY = (iconSize * 0.82).toInt();
  final shieldW = (iconSize * 0.58).toInt();
  const thick = iconSize ~/ 12;

  for (int py = shieldTopY; py <= shieldBotY; py++) {
    final t = (py - shieldTopY) / (shieldBotY - shieldTopY).toDouble();
    final int halfW = t < 0.55 ? shieldW ~/ 2 : ((1.0 - t) / 0.45 * (shieldW / 2)).toInt();

    for (int px = cx - halfW; px <= cx + halfW; px++) {
      final bool onLeftEdge = px <= cx - halfW + thick;
      final bool onRightEdge = px >= cx + halfW - thick;
      final bool isTop = py <= shieldTopY + thick;
      if (isTop || onLeftEdge || onRightEdge) {
        if (px >= 0 && px < iconSize && py >= 0 && py < iconSize) {
          image.setPixelRgba(px, py, whiteR, whiteG, whiteB, 255);
        }
      }
    }
  }

  final tipStart = (iconSize * 0.60).toInt();
  for (int py = tipStart; py <= shieldBotY; py++) {
    final t = (py - tipStart) / (shieldBotY - tipStart).toDouble();
    final halfW = ((1.0 - t) * (shieldW / 2)).toInt();
    for (int px = cx - halfW; px <= cx + halfW; px++) {
      if (px >= 0 && px < iconSize && py >= 0 && py < iconSize) {
        image.setPixelRgba(px, py, whiteR, whiteG, whiteB, 255);
      }
    }
  }

  _fillRect(image, cx - shieldW ~/ 2, shieldTopY, shieldW, thick);

  File('assets/icons/admin_icon.png').writeAsBytesSync(img.encodePng(image));
  print('admin_icon.png generated.');
}

/// PATIENT: Solid white heart
void _generatePatientIcon() {
  final image = _greenCanvas();
  const cx = iconSize / 2;
  const cy = iconSize / 2 - iconSize * 0.04;
  const r = iconSize * 0.21;

  const lx = cx - r * 0.5;
  const ly = cy - r * 0.18;
  const rx = cx + r * 0.5;
  const ry = cy - r * 0.18;

  for (int py = 0; py < iconSize; py++) {
    for (int px = 0; px < iconSize; px++) {
      final dx1 = px - lx, dy1 = py - ly;
      final dx2 = px - rx, dy2 = py - ry;
      final bool inLeft = dx1 * dx1 + dy1 * dy1 <= r * r;
      final bool inRight = dx2 * dx2 + dy2 * dy2 <= r * r;

      bool inTriangle = false;
      if (py >= cy - r * 0.3 && py <= cy + r * 1.35) {
        final halfW = (1.0 - (py - (cy - r * 0.3)) / (r * 1.65)) * r * 1.08;
        if ((px - cx).abs() <= halfW) inTriangle = true;
      }

      if (inLeft || inRight || inTriangle) {
        image.setPixelRgba(px, py, whiteR, whiteG, whiteB, 255);
      }
    }
  }

  File('assets/icons/patient_icon.png').writeAsBytesSync(img.encodePng(image));
  print('patient_icon.png generated.');
}

void _applySquircleMask(String inputPath, String outputPath) {
  var image = img.decodeImage(File(inputPath).readAsBytesSync());
  if (image == null) return;
  if (!image.hasAlpha) image = image.convert(numChannels: 4);

  final double radius = image.width * 0.225;
  final int w = image.width, h = image.height;

  for (final p in image) {
    final int x = p.x, y = p.y;
    bool inside = true;
    if (x < radius && y < radius) {
      final dx = radius - x, dy = radius - y;
      if (dx * dx + dy * dy > radius * radius) inside = false;
    } else if (x > w - radius && y < radius) {
      final dx = x - (w - radius), dy = radius - y;
      if (dx * dx + dy * dy > radius * radius) inside = false;
    } else if (x < radius && y > h - radius) {
      final dx = radius - x, dy = y - (h - radius);
      if (dx * dx + dy * dy > radius * radius) inside = false;
    } else if (x > w - radius && y > h - radius) {
      final dx = x - (w - radius), dy = y - (h - radius);
      if (dx * dx + dy * dy > radius * radius) inside = false;
    }
    if (!inside) p.a = 0;
  }

  File(outputPath).writeAsBytesSync(img.encodePng(image));
  print('Masked $inputPath → $outputPath');
}
