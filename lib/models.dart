class Entry {
  final String task;
  final String? category;
  final DateTime start;
  final DateTime? end;
  Entry(this.task, this.start, [this.end, this.category]);
  Map<String, dynamic> toJson() => {
    'task': task,
    if (category != null) 'category': category,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    j['task'],
    DateTime.parse(j['start']),
    j['end'] == null ? null : DateTime.parse(j['end']),
    j['category'] as String?,
  );
}

String hours(Duration d) {
  final m = d.inMinutes;
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

String clock(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

Duration monthlyTotal(List<Entry> entries, DateTime month) {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1);
  var total = Duration.zero;
  for (final entry in entries) {
    if (entry.end == null) continue;
    final start = entry.start.isAfter(from) ? entry.start : from;
    final end = entry.end!.isBefore(to) ? entry.end! : to;
    if (end.isAfter(start)) total += end.difference(start);
  }
  return total;
}
