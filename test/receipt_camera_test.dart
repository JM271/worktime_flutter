import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:worktime/backup.dart';
import 'package:worktime/bank_details.dart';
import 'package:worktime/expenses.dart';
import 'package:worktime/monthly_report.dart';
import 'package:worktime/receipt_image.dart';

class CancelCamera extends ImagePickerPlatform {
  ImageSource? source;
  ImagePickerOptions? options;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    this.source = source;
    this.options = options;
    return null;
  }
}

void main() {
  test(
    'Camera photos become small grayscale JPEGs and survive backup and Excel',
    () {
      final original = img.Image(width: 1800, height: 2400);
      img.fill(original, color: img.ColorRgb8(240, 220, 200));
      img.fillRect(
        original,
        x1: 100,
        y1: 100,
        x2: 500,
        y2: 900,
        color: img.ColorRgb8(20, 10, 0),
      );
      original.exif.imageIfd.orientation = 6;
      final source = img.encodeJpg(original, quality: 100);
      final jpeg = compressReceipt(source);
      expect(receiptExtension(jpeg), 'jpg');
      expect(receiptDimensions(jpeg), (1600, 1200));
      expect(jpeg.length, lessThanOrEqualTo(receiptTargetBytes));
      expect(jpeg.length, lessThan(source.length));
      final decoded = img.decodeJpg(jpeg)!;
      final pixel = decoded.getPixel(1000, 500);
      expect(pixel.r, pixel.g);
      expect(pixel.g, pixel.b);
      expect(decoded.exif.imageIfd.hasOrientation, isFalse);
      final expense = Expense(
        'Kassenzettel',
        DateTime(2026, 10, 29),
        1290,
        receipt: jpeg,
      );
      final restored = WorktimeBackup.decode(
        WorktimeBackup([], null, const BankDetails(), [expense]).encode(),
      );
      expect(restored.expenses.single.receipt, jpeg);
      final zip = ZipDecoder().decodeBytes(
        monthlyWorkbook([], DateTime(2026, 10), expenses: restored.expenses),
      );
      expect(zip.findFile('xl/media/receipt1.jpg')!.content, jpeg);
      expect(
        utf8.decode(
          zip.findFile('xl/drawings/_rels/receipts.xml.rels')!.content
              as List<int>,
        ),
        contains('receipt1.jpg'),
      );
      expect(
        utf8.decode(zip.findFile('[Content_Types].xml')!.content as List<int>),
        contains('image/jpeg'),
      );
    },
  );

  testWidgets(
    'Attach opens camera and cancelling preserves the existing receipt',
    (tester) async {
      final platform = ImagePickerPlatform.instance;
      final camera = CancelCamera();
      ImagePickerPlatform.instance = camera;
      addTearDown(() => ImagePickerPlatform.instance = platform);
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseEditor(
              expense: Expense(
                'Material',
                DateTime(2026, 10, 29),
                100,
                receipt: png,
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Kassenzettel ersetzen'));
      await tester.tap(find.text('Kassenzettel ersetzen'));
      await tester.pumpAndSettle();
      expect(camera.source, ImageSource.camera);
      expect(camera.options!.maxWidth, 1600);
      expect(camera.options!.maxHeight, 1600);
      expect(camera.options!.requestFullMetadata, isFalse);
      expect(find.text('Beleg entfernen'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
