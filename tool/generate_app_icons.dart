import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

// Run from the project root: dart run tool/generate_app_icons.dart
void main() {
  final source = img.decodeImage(
    File('assets/brand/worktime_icon.png').readAsBytesSync(),
  )!;
  void write(String path, int size) {
    File(path).writeAsBytesSync(
      img.encodePng(
        img.copyResize(
          source,
          width: size,
          height: size,
          interpolation: img.Interpolation.average,
        ),
      ),
    );
  }

  const androidSizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in androidSizes.entries) {
    write(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      entry.value,
    );
  }
  const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final manifest = jsonDecode(File('$ios/Contents.json').readAsStringSync());
  for (final icon in manifest['images']) {
    final size = double.parse((icon['size'] as String).split('x').first);
    final scale = double.parse((icon['scale'] as String).replaceAll('x', ''));
    write('$ios/${icon['filename']}', (size * scale).round());
  }
}
