import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:worktime/backup.dart';
import 'package:worktime/models.dart';
import 'package:worktime/bank_details.dart';

void main() {
  test('Backup roundtrip retains history, active timer and bank details', () {
    final original = WorktimeBackup(
      [
        Entry(
          'Repair',
          'Client',
          DateTime(2026, 10, 12, 9),
          DateTime(2026, 10, 12, 11),
          'Bike Repair',
        ),
      ],
      Entry('Active', 'Other', DateTime(2026, 10, 13, 10)),
      const BankDetails(accountNumber: '001234'),
    );
    final restored = WorktimeBackup.decode(original.encode());
    expect(restored.data, original.data);
  });
  test('Rejects damaged, unsupported and invalid backups', () {
    expect(() => WorktimeBackup.decode('broken'), throwsFormatException);
    expect(
      () => WorktimeBackup.decode('{"app":"other","version":1}'),
      throwsFormatException,
    );
    final data = jsonDecode(
      WorktimeBackup([], null, const BankDetails()).encode(),
    );
    data['data']['entries'] = [
      {
        'task': 'Bad',
        'project': 'P',
        'start': '2026-10-13T11:00:00',
        'end': '2026-10-13T10:00:00',
      },
    ];
    expect(
      () => WorktimeBackup.decode(jsonEncode(data)),
      throwsFormatException,
    );
  });
}
