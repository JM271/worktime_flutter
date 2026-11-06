import 'dart:convert';

import 'models.dart';

/// Completed time entries are kept on the device for the current month plus
/// this many full previous months. Older entries may be removed once they are
/// part of a confirmed Drive backup.
const entryRetentionMonths = 3;

/// Entries that ended on or before this moment are old enough to remove.
DateTime entryRetentionCutoff(DateTime now) =>
    DateTime(now.year, now.month - entryRetentionMonths);

String _entryKey(Object? json) => jsonEncode(json);

/// Keys of every completed entry contained in a confirmed backup snapshot
/// (the JSON stored under `worktime-confirmed-backup`).
Set<String> backedUpEntryKeys(String? confirmedBackupData) {
  if (confirmedBackupData == null) return const {};
  try {
    final data = jsonDecode(confirmedBackupData) as Map;
    return {for (final entry in data['entries'] as List) _entryKey(entry)};
  } catch (_) {
    return const {};
  }
}

/// Completed entries older than the retention window that are also present,
/// unchanged, in the confirmed backup — removing them loses nothing.
List<Entry> prunableEntries(
  List<Entry> entries,
  Set<String> backedUpKeys,
  DateTime now,
) {
  if (backedUpKeys.isEmpty) return const [];
  final cutoff = entryRetentionCutoff(now);
  return [
    for (final entry in entries)
      if (entry.end != null &&
          !entry.end!.isAfter(cutoff) &&
          backedUpKeys.contains(_entryKey(entry.toJson())))
        entry,
  ];
}
