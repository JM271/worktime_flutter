import 'models.dart';

const uncategorizedCategory = 'Uncategorized';

class AnalyzedEntry {
  AnalyzedEntry({
    required this.entry,
    required this.start,
    required this.end,
    required this.category,
    List<String> flags = const [],
  }) : flags = List.unmodifiable(flags);

  final Entry entry;
  final DateTime start;
  final DateTime end;
  final String category;
  final List<String> flags;

  Duration get duration => end.difference(start);
}

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.total,
    required this.share,
    required this.sessionCount,
  });

  final String category;
  final Duration total;
  final double share;
  final int sessionCount;
}

class DailyTotal {
  const DailyTotal({
    required this.date,
    required this.total,
    required this.sessionCount,
  });

  final DateTime date;
  final Duration total;
  final int sessionCount;
}

class WeeklyTotal {
  const WeeklyTotal({
    required this.monday,
    required this.start,
    required this.end,
    required this.total,
    required this.sessionCount,
  });

  final DateTime monday;
  final DateTime start;
  final DateTime end;
  final Duration total;
  final int sessionCount;
}

/// Completed work for one local calendar month, with its original rows intact.
///
/// Durations are elapsed time. Day and week boundaries use calendar constructors
/// so a daylight-saving transition cannot move a boundary away from midnight.
/// Overlapping work remains in recorded totals and is reported separately.
class MonthlyAnalysis {
  MonthlyAnalysis(List<Entry> entries, DateTime selectedMonth, {DateTime? asOf})
    : month = DateTime(selectedMonth.year, selectedMonth.month),
      asOf = (asOf ?? DateTime.now()).toLocal() {
    start = month;
    end = DateTime(month.year, month.month + 1);
    isCurrentMonth =
        this.asOf.year == month.year && this.asOf.month == month.month;
    isFutureMonth = start.isAfter(this.asOf);
    rows = List.unmodifiable(
      _completedRows(entries, start, end, asOf: this.asOf),
    );
    total = _sum(rows);
    sessionCount = rows.length;
    categories = List.unmodifiable(_categoryTotals(rows, total));
    days = List.unmodifiable(_dailyTotals(rows, start, end));
    weeks = List.unmodifiable(_weeklyTotals(rows, start, end));
    activeDays = days.where((day) => day.total > Duration.zero).length;
    averageSession = _average(total, sessionCount);
    averageActiveDay = _average(total, activeDays);
    longestSession = rows.fold(
      Duration.zero,
      (longest, row) => row.duration > longest ? row.duration : longest,
    );
    DailyTotal? busiest;
    for (final day in days) {
      if (day.total > Duration.zero &&
          (busiest == null || day.total > busiest.total)) {
        busiest = day;
      }
    }
    busiestDay = busiest;

    final previousStart = DateTime(month.year, month.month - 1);
    previousMonthTotal = _sum(
      _completedRows(entries, previousStart, start, overlapFlags: false),
    );
    comparisonStart = start;
    comparisonPreviousStart = previousStart;
    if (isFutureMonth) {
      comparisonEnd = start;
      comparisonPreviousEnd = previousStart;
      comparisonLabel = 'Future month · comparison unavailable';
    } else if (isCurrentMonth) {
      comparisonEnd = this.asOf;
      comparisonPreviousEnd = _previousCutoff(this.asOf, previousStart, start);
      comparisonLabel =
          'Month-to-date through ${_stamp(comparisonEnd)} '
          'vs previous month through ${_stamp(comparisonPreviousEnd)} '
          '(same calendar cutoff, capped at month end)';
    } else {
      comparisonEnd = end;
      comparisonPreviousEnd = start;
      comparisonLabel =
          'Full calendar month ${_date(start)}–${_date(end)} '
          'vs ${_date(previousStart)}–${_date(start)} (end exclusive)';
    }
    comparisonTotal = _sum(
      _completedRows(entries, start, comparisonEnd, overlapFlags: false),
    );
    comparisonPreviousTotal = _sum(
      _completedRows(
        entries,
        previousStart,
        comparisonPreviousEnd,
        overlapFlags: false,
      ),
    );
    comparisonChangePercent =
        !isFutureMonth && comparisonPreviousTotal > Duration.zero
        ? (comparisonTotal.inMicroseconds /
                      comparisonPreviousTotal.inMicroseconds -
                  1) *
              100
        : null;

    final calendarDays = DateTime(month.year, month.month + 1, 0).day;
    final targetDays = isCurrentMonth
        ? _elapsedCalendarDays(this.asOf)
        : calendarDays.toDouble();
    goal = Duration(
      microseconds: (const Duration(hours: 20).inMicroseconds * targetDays / 7)
          .round(),
    );
    goalLabel = isFutureMonth
        ? 'Planned monthly target · 20h/week prorated over $calendarDays calendar days'
        : isCurrentMonth
        ? 'Month-to-date target · 20h/week prorated by elapsed calendar days '
              'through ${_stamp(this.asOf)}'
        : 'Monthly target · 20h/week prorated over $calendarDays calendar days';
    final goalActual = isCurrentMonth ? comparisonTotal : total;
    goalProgress = !isFutureMonth && goal > Duration.zero
        ? goalActual.inMicroseconds / goal.inMicroseconds
        : 0;

    overlapDuration = total - _unionDuration(rows);
    missingCategoryCount = rows
        .where((row) => _missingCategory(row.entry))
        .length;
    longSessionCount = rows
        .where(
          (row) =>
              row.entry.end!.difference(row.entry.start) >
              const Duration(hours: 12),
        )
        .length;
    futureEntryCount = rows
        .where((row) => row.entry.end!.isAfter(this.asOf))
        .length;
    invalidEntryCount = entries.where((entry) {
      if (entry.end == null || entry.end!.isAfter(entry.start)) return false;
      return _invalidTouchesMonth(entry, start, end);
    }).length;
    activeTimerCount = entries.where((entry) {
      if (entry.end != null) return false;
      final entryStart = entry.start.toLocal();
      return entryStart.isBefore(this.asOf) &&
          entryStart.isBefore(end) &&
          this.asOf.isAfter(start);
    }).length;
    insights = List.unmodifiable(_insights(this));
    checks = List.unmodifiable(_checks(this));
  }

  final DateTime month;
  final DateTime asOf;
  late final DateTime start;
  late final DateTime end;
  late final bool isCurrentMonth;
  late final bool isFutureMonth;
  late final List<AnalyzedEntry> rows;
  late final List<CategoryTotal> categories;
  late final List<DailyTotal> days;
  late final List<WeeklyTotal> weeks;
  late final Duration total;
  late final int sessionCount;
  late final int activeDays;
  late final Duration averageSession;
  late final Duration averageActiveDay;
  late final Duration longestSession;
  late final DailyTotal? busiestDay;
  late final Duration previousMonthTotal;
  late final DateTime comparisonStart;
  late final DateTime comparisonEnd;
  late final DateTime comparisonPreviousStart;
  late final DateTime comparisonPreviousEnd;
  late final Duration comparisonTotal;
  late final Duration comparisonPreviousTotal;
  late final String comparisonLabel;
  late final double? comparisonChangePercent;
  late final Duration goal;
  late final String goalLabel;
  late final double goalProgress;
  late final Duration overlapDuration;
  late final int missingCategoryCount;
  late final int invalidEntryCount;
  late final int longSessionCount;
  late final int futureEntryCount;
  late final int activeTimerCount;
  late final List<String> insights;
  late final List<String> checks;

  /// Target for this month's part of a Monday week, at the report's cutoff.
  /// Cumulative rounding keeps the weekly targets equal to the monthly target.
  Duration weeklyGoal(WeeklyTotal week) {
    final from = _later(start, week.start);
    var to = _earlier(end, week.end);
    if (isCurrentMonth) to = _earlier(to, asOf);
    if (!to.isAfter(from)) return Duration.zero;
    final rate = const Duration(hours: 20).inMicroseconds / 7;
    final before = (rate * _calendarDaysBetween(start, from)).round();
    final through = (rate * _calendarDaysBetween(start, to)).round();
    return Duration(microseconds: through - before);
  }

  /// Recorded completed time used for progress against [weeklyGoal].
  /// Future-dated time remains in [WeeklyTotal.total], outside progress.
  Duration weeklyGoalActual(WeeklyTotal week) {
    if (isFutureMonth) return Duration.zero;
    final from = _later(start, week.start);
    var to = _earlier(end, week.end);
    if (isCurrentMonth) to = _earlier(to, asOf);
    if (!to.isAfter(from)) return Duration.zero;
    return _bucket(rows, from, to).total;
  }
}

bool _missingCategory(Entry entry) =>
    entry.category == null || entry.category!.trim().isEmpty;

String _category(Entry entry) =>
    _missingCategory(entry) ? uncategorizedCategory : entry.category!.trim();

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
DateTime _nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);

List<AnalyzedEntry> _completedRows(
  List<Entry> entries,
  DateTime from,
  DateTime to, {
  bool overlapFlags = true,
  DateTime? asOf,
}) {
  if (!to.isAfter(from)) return [];
  final selected = <AnalyzedEntry>[];
  for (final entry in entries) {
    if (entry.end == null || !entry.end!.isAfter(entry.start)) continue;
    final clippedStart = _later(entry.start.toLocal(), from);
    final clippedEnd = _earlier(entry.end!.toLocal(), to);
    if (!clippedEnd.isAfter(clippedStart)) continue;
    selected.add(
      AnalyzedEntry(
        entry: entry,
        start: clippedStart,
        end: clippedEnd,
        category: _category(entry),
        flags: [
          if (_missingCategory(entry)) 'Missing category',
          if (entry.end!.difference(entry.start) > const Duration(hours: 12))
            'Session longer than 12 hours',
          if (asOf != null && entry.end!.isAfter(asOf))
            'Completed entry is dated in the future',
        ],
      ),
    );
  }
  selected.sort((a, b) {
    final order = a.start.compareTo(b.start);
    return order == 0 ? a.end.compareTo(b.end) : order;
  });
  if (!overlapFlags || selected.length < 2) return selected;
  final overlapping = <int>{};
  var furthest = 0;
  for (var index = 1; index < selected.length; index++) {
    if (selected[index].start.isBefore(selected[furthest].end)) {
      overlapping.add(index);
      overlapping.add(furthest);
    }
    if (selected[index].end.isAfter(selected[furthest].end)) furthest = index;
  }
  return [
    for (var index = 0; index < selected.length; index++)
      if (overlapping.contains(index))
        AnalyzedEntry(
          entry: selected[index].entry,
          start: selected[index].start,
          end: selected[index].end,
          category: selected[index].category,
          flags: [...selected[index].flags, 'Overlaps another session'],
        )
      else
        selected[index],
  ];
}

Duration _sum(Iterable<AnalyzedEntry> rows) =>
    rows.fold(Duration.zero, (sum, row) => sum + row.duration);

Duration _average(Duration total, int count) => count == 0
    ? Duration.zero
    : Duration(microseconds: (total.inMicroseconds / count).round());

List<CategoryTotal> _categoryTotals(List<AnalyzedEntry> rows, Duration total) {
  final totals = <String, Duration>{};
  final counts = <String, int>{};
  for (final row in rows) {
    totals.update(
      row.category,
      (sum) => sum + row.duration,
      ifAbsent: () => row.duration,
    );
    counts.update(row.category, (count) => count + 1, ifAbsent: () => 1);
  }
  final categories = [
    for (final category in totals.keys)
      CategoryTotal(
        category: category,
        total: totals[category]!,
        share: total == Duration.zero
            ? 0
            : totals[category]!.inMicroseconds / total.inMicroseconds,
        sessionCount: counts[category]!,
      ),
  ];
  categories.sort((a, b) {
    final order = b.total.compareTo(a.total);
    return order == 0 ? a.category.compareTo(b.category) : order;
  });
  return categories;
}

({Duration total, int count}) _bucket(
  List<AnalyzedEntry> rows,
  DateTime from,
  DateTime to,
) {
  var total = Duration.zero;
  var count = 0;
  for (final row in rows) {
    final start = _later(row.start, from);
    final end = _earlier(row.end, to);
    if (end.isAfter(start)) {
      total += end.difference(start);
      count++;
    }
  }
  return (total: total, count: count);
}

List<DailyTotal> _dailyTotals(
  List<AnalyzedEntry> rows,
  DateTime start,
  DateTime end,
) {
  final days = <DailyTotal>[];
  for (var date = start; date.isBefore(end); date = _nextDay(date)) {
    final bucket = _bucket(rows, date, _nextDay(date));
    days.add(
      DailyTotal(date: date, total: bucket.total, sessionCount: bucket.count),
    );
  }
  return days;
}

List<WeeklyTotal> _weeklyTotals(
  List<AnalyzedEntry> rows,
  DateTime start,
  DateTime end,
) {
  final weeks = <WeeklyTotal>[];
  var monday = DateTime(start.year, start.month, start.day - start.weekday + 1);
  while (monday.isBefore(end)) {
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    final from = _later(monday, start);
    final to = _earlier(nextMonday, end);
    final bucket = _bucket(rows, from, to);
    weeks.add(
      WeeklyTotal(
        monday: monday,
        start: from,
        end: to,
        total: bucket.total,
        sessionCount: bucket.count,
      ),
    );
    monday = nextMonday;
  }
  return weeks;
}

Duration _unionDuration(List<AnalyzedEntry> rows) {
  if (rows.isEmpty) return Duration.zero;
  var from = rows.first.start;
  var to = rows.first.end;
  var total = Duration.zero;
  for (final row in rows.skip(1)) {
    if (row.start.isAfter(to)) {
      total += to.difference(from);
      from = row.start;
      to = row.end;
    } else {
      to = _later(to, row.end);
    }
  }
  return total + to.difference(from);
}

bool _invalidTouchesMonth(Entry entry, DateTime start, DateTime end) {
  bool inside(DateTime point) => !point.isBefore(start) && point.isBefore(end);
  return inside(entry.start) ||
      inside(entry.end!) ||
      (entry.end!.isBefore(start) && !entry.start.isBefore(end));
}

DateTime _previousCutoff(
  DateTime asOf,
  DateTime previousStart,
  DateTime previousEnd,
) {
  final lastDay = DateTime(previousStart.year, previousStart.month + 1, 0).day;
  if (asOf.day > lastDay) return previousEnd;
  return DateTime(
    previousStart.year,
    previousStart.month,
    asOf.day,
    asOf.hour,
    asOf.minute,
    asOf.second,
    asOf.millisecond,
    asOf.microsecond,
  );
}

double _elapsedCalendarDays(DateTime asOf) {
  return _calendarDaysBetween(DateTime(asOf.year, asOf.month), asOf);
}

double _calendarDaysBetween(DateTime from, DateTime to) {
  final fromDate = DateTime.utc(from.year, from.month, from.day);
  final toDate = DateTime.utc(to.year, to.month, to.day);
  return toDate.difference(fromDate).inDays +
      _fractionOfDay(to) -
      _fractionOfDay(from);
}

double _fractionOfDay(DateTime date) {
  final today = DateTime(date.year, date.month, date.day);
  final tomorrow = _nextDay(today);
  return date.difference(today).inMicroseconds /
      tomorrow.difference(today).inMicroseconds;
}

String _date(DateTime date) =>
    '${date.year}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _stamp(DateTime date) =>
    '${_date(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

List<String> _insights(MonthlyAnalysis analysis) {
  final insights = <String>[];
  if (analysis.rows.isEmpty) {
    insights.add('No completed time was recorded for this month.');
  } else {
    final largest = analysis.categories.first;
    insights.add(
      '${largest.category} accounts for '
      '${(largest.share * 100).toStringAsFixed(1)}% of recorded time '
      '(${hours(largest.total)}).',
    );
    final busiest = analysis.busiestDay!;
    insights.add(
      '${_date(busiest.date)} has the most recorded time: '
      '${hours(busiest.total)}.',
    );
  }
  if (analysis.isFutureMonth) {
    insights.add(
      'This month is in the future; comparison and target progress '
      'are unavailable.',
    );
  } else if (analysis.comparisonChangePercent != null) {
    final change = analysis.comparisonChangePercent!;
    if (change == 0) {
      insights.add('Completed time matches the previous comparison period.');
    } else if (change.abs() < 0.1) {
      insights.add(
        'Completed time differs by less than 0.1% from the previous '
        'comparison period.',
      );
    } else {
      insights.add(
        'Completed time is ${change.abs().toStringAsFixed(1)}% '
        '${change > 0 ? 'higher' : 'lower'} than the previous comparison period.',
      );
    }
  } else {
    insights.add(
      'The previous comparison period has no completed time; '
      'a percentage change is unavailable.',
    );
  }
  return insights;
}

List<String> _checks(MonthlyAnalysis analysis) {
  final checks = <String>[
    if (analysis.overlapDuration > Duration.zero)
      'Overlapping sessions add ${hours(analysis.overlapDuration)} above elapsed '
          'time. Totals retain all recorded sessions.',
    if (analysis.missingCategoryCount > 0)
      '${analysis.missingCategoryCount} completed '
          '${analysis.missingCategoryCount == 1 ? 'session has' : 'sessions have'} '
          'no category and ${analysis.missingCategoryCount == 1 ? 'is' : 'are'} '
          'listed as Uncategorized.',
    if (analysis.invalidEntryCount > 0)
      '${analysis.invalidEntryCount} completed '
          '${analysis.invalidEntryCount == 1 ? 'entry has' : 'entries have'} '
          'an end at or before the start and '
          '${analysis.invalidEntryCount == 1 ? 'was' : 'were'} excluded.',
    if (analysis.longSessionCount > 0)
      '${analysis.longSessionCount} completed '
          '${analysis.longSessionCount == 1 ? 'session lasts' : 'sessions last'} '
          'more than 12 hours. Review the start and end times.',
    if (analysis.futureEntryCount > 0)
      '${analysis.futureEntryCount} completed '
          '${analysis.futureEntryCount == 1 ? 'entry is' : 'entries are'} '
          'dated after ${_stamp(analysis.asOf)}. Whole-month totals retain this '
          'recorded work; month-to-date comparison excludes time after the cutoff.',
    if (analysis.activeTimerCount > 0)
      '${analysis.activeTimerCount} running '
          '${analysis.activeTimerCount == 1 ? 'entry overlaps' : 'entries overlap'} '
          'this month and ${analysis.activeTimerCount == 1 ? 'is' : 'are'} '
          'excluded from completed totals.',
  ];
  if (checks.isEmpty) {
    checks.add(
      analysis.rows.isEmpty
          ? 'No completed entries are available to check.'
          : 'No issues were found in completed entries for this month.',
    );
  }
  return checks;
}
