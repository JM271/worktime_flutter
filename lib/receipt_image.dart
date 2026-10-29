import 'dart:typed_data';

import 'package:image/image.dart' as img;

const receiptTargetBytes = 250 * 1024;

String receiptExtension(Uint8List bytes) =>
    bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8 ? 'jpg' : 'png';

/// Both new JPEG receipts and previously stored PNG receipts remain supported.
(int, int) receiptDimensions(Uint8List bytes) {
  final img.Decoder decoder = receiptExtension(bytes) == 'jpg'
      ? img.JpegDecoder()
      : img.PngDecoder();
  final info = decoder.startDecode(bytes);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width > 2400 ||
      info.height > 2400) {
    throw const FormatException('Ungültiges Belegbild.');
  }
  return (info.width, info.height);
}

/// Run through compute so image processing does not block the editor on mobile.
Uint8List compressReceipt(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Bild konnte nicht gelesen werden.');
  }
  var image = img.bakeOrientation(decoded);
  final landscape = image.width > image.height;
  if ((landscape ? image.width : image.height) > 1600) {
    image = img.copyResize(
      image,
      width: landscape ? 1600 : null,
      height: landscape ? null : 1600,
      interpolation: img.Interpolation.average,
    );
  }
  // A fresh image discards camera metadata; equal RGB channels remove colour.
  final gray = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 3,
  );
  for (final pixel in image) {
    final luminance = (pixel.r * .299 + pixel.g * .587 + pixel.b * .114)
        .round();
    gray.setPixelRgb(pixel.x, pixel.y, luminance, luminance, luminance);
  }
  image = gray;
  while (true) {
    Uint8List? jpeg;
    for (final quality in [75, 65, 55]) {
      jpeg = img.encodeJpg(image, quality: quality);
      if (jpeg.length <= receiptTargetBytes) return jpeg;
    }
    final longest = image.width > image.height ? image.width : image.height;
    // Retain at least 1000px for text readability, even for unusually noisy photos.
    if (longest <= 1000) return jpeg!;
    final next = (longest * .85).round().clamp(1000, 1600);
    image = img.copyResize(
      image,
      width: image.width > image.height ? next : null,
      height: image.width > image.height ? null : next,
      interpolation: img.Interpolation.average,
    );
  }
}
