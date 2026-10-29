import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'expenses.dart';
import 'receipt_image.dart' show receiptExtension;

/// Add native DrawingML pictures; the excel package does not embed images.
Uint8List embedReceipts(List<int> workbook, List<Expense> receipts) {
  if (receipts.isEmpty) return Uint8List.fromList(workbook);
  final archive = ZipDecoder().decodeBytes(workbook);
  String read(String path) =>
      utf8.decode(archive.findFile(path)!.content as List<int>);
  void write(String path, String value) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  const relationshipNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const packageNs =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  const drawingNs = 'http://schemas.openxmlformats.org/drawingml/2006';
  final book = XmlDocument.parse(read('xl/workbook.xml'));
  final id = book
      .findAllElements('sheet')
      .firstWhere((e) => e.getAttribute('name') == 'Belege')
      .getAttribute('id', namespace: relationshipNs)!;
  final rels = XmlDocument.parse(read('xl/_rels/workbook.xml.rels'));
  final target = rels
      .findAllElements('Relationship')
      .firstWhere((e) => e.getAttribute('Id') == id)
      .getAttribute('Target')!;
  final sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  final sheet = XmlDocument.parse(read(sheetPath));
  sheet.rootElement.children.add(
    XmlElement(XmlName('drawing'), [
      XmlAttribute(XmlName('xmlns:r'), relationshipNs),
      XmlAttribute(XmlName('r:id'), 'receiptDrawing'),
    ]),
  );
  write(sheetPath, sheet.toXmlString());
  final filename = sheetPath.split('/').last;
  write(
    'xl/worksheets/_rels/$filename.rels',
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="$packageNs"><Relationship Id="receiptDrawing" Type="$relationshipNs/drawing" Target="../drawings/receipts.xml"/></Relationships>',
  );
  final anchors = StringBuffer();
  final imageRels = StringBuffer();
  for (var i = 0; i < receipts.length; i++) {
    final bytes = receipts[i].receipt!;
    final (width, height) = receiptDimensions(bytes);
    final scale = math.min(600 / width, 700 / height);
    final cx = (width * scale * 9525).round();
    final cy = (height * scale * 9525).round();
    final extension = receiptExtension(bytes);
    archive.addFile(
      ArchiveFile('xl/media/receipt${i + 1}.$extension', bytes.length, bytes),
    );
    imageRels.write(
      '<Relationship Id="rId${i + 1}" Type="$relationshipNs/image" Target="../media/receipt${i + 1}.$extension"/>',
    );
    anchors.write(
      '''<xdr:oneCellAnchor><xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>${i * 40 + 3}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="$cx" cy="$cy"/><xdr:pic><xdr:nvPicPr><xdr:cNvPr id="${i + 1}" name="Beleg ${i + 1}"/><xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr><xdr:blipFill><a:blip r:embed="rId${i + 1}"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill><xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:oneCellAnchor>''',
    );
  }
  write(
    'xl/drawings/receipts.xml',
    '<?xml version="1.0" encoding="UTF-8"?><xdr:wsDr xmlns:xdr="$drawingNs/spreadsheetDrawing" xmlns:a="$drawingNs/main" xmlns:r="$relationshipNs">$anchors</xdr:wsDr>',
  );
  write(
    'xl/drawings/_rels/receipts.xml.rels',
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="$packageNs">$imageRels</Relationships>',
  );
  final types = XmlDocument.parse(read('[Content_Types].xml'));
  for (final (extension, mime) in [
    ('png', 'image/png'),
    ('jpg', 'image/jpeg'),
  ]) {
    if (!types
        .findAllElements('Default')
        .any((e) => e.getAttribute('Extension') == extension)) {
      types.rootElement.children.add(
        XmlElement(XmlName('Default'), [
          XmlAttribute(XmlName('Extension'), extension),
          XmlAttribute(XmlName('ContentType'), mime),
        ]),
      );
    }
  }
  types.rootElement.children.add(
    XmlElement(XmlName('Override'), [
      XmlAttribute(XmlName('PartName'), '/xl/drawings/receipts.xml'),
      XmlAttribute(
        XmlName('ContentType'),
        'application/vnd.openxmlformats-officedocument.drawing+xml',
      ),
    ]),
  );
  write('[Content_Types].xml', types.toXmlString());
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
