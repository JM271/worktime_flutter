import 'dart:convert';

import 'models.dart';
import 'bank_details.dart';

class WorktimeBackup {
  WorktimeBackup(this.entries, this.running, this.bankDetails);
  final List<Entry> entries;
  final Entry? running;
  final BankDetails bankDetails;
  Map<String, dynamic> get data => {
    'entries': entries.map((e) => e.toJson()).toList(),
    'running': running?.toJson(),
    'bankDetails': bankDetails.toJson(),
  };
  String encode() => const JsonEncoder.withIndent('  ').convert({
    'app': 'worktime',
    'version': 1,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'data': data,
  });
  factory WorktimeBackup.decode(String text) {
    try {
      final root = jsonDecode(text);
      if (root is! Map || root['app'] != 'worktime' || root['version'] != 1) {
        throw const FormatException('Choose a supported Worktime backup.');
      }
      final data = Map<String, dynamic>.from(root['data'] as Map);
      Entry read(dynamic value, {required bool active}) {
        final entry = Entry.fromJson(Map<String, dynamic>.from(value as Map));
        if (active
            ? entry.end != null
            : entry.end == null || !entry.end!.isAfter(entry.start)) {
          throw const FormatException('Backup contains an invalid time entry.');
        }
        return entry;
      }

      final entries = (data['entries'] as List)
          .map((e) => read(e, active: false))
          .toList();
      final running = data['running'] == null
          ? null
          : read(data['running'], active: true);
      final bank = BankDetails.fromJson(
        Map<String, dynamic>.from(data['bankDetails'] as Map),
      );
      return WorktimeBackup(entries, running, bank);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('This backup is incomplete or damaged.');
    }
  }
}
