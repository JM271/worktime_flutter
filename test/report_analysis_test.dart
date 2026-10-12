import 'package:flutter_test/flutter_test.dart';
import 'package:worktime/models.dart';
import 'package:worktime/report_analysis.dart';

void main() {
  test('Month boundaries and midnight splits conserve recorded time', () {
    final analysis = MonthlyAnalysis(
      [
        Entry(
          'Carry-in',
          'General',
          DateTime(2026, 9, 30, 23),
          DateTime(2026, 10, 1, 2),
          'Project Work',
        ),
        Entry(
          'Overnight repair',
          'General',
          DateTime(2026, 10, 1, 23),
          DateTime(2026, 10, 2, 1),
          'Bike Repair',
        ),
        Entry(
          'Carry-out',
          'General',
          DateTime(2026, 10, 31, 23),
          DateTime(2026, 11, 1, 2),
          'Bike Repair',
        ),
      ],
      DateTime(2026, 10),
      asOf: DateTime(2026, 11, 3),
    );

    expect(analysis.total, const Duration(hours: 5));
    expect(analysis.sessionCount, 3);
    expect(analysis.activeDays, 3);
    expect(analysis.days, hasLength(31));
    expect(analysis.rows.first.start, DateTime(2026, 10));
    expect(analysis.rows.last.end, DateTime(2026, 11));
    expect(analysis.days[0].total, const Duration(hours: 3));
    expect(analysis.days[1].total, const Duration(hours: 1));
    expect(analysis.days[30].total, const Duration(hours: 1));
    expect(analysis.days[2].total, Duration.zero);
    expect(analysis.busiestDay!.date, DateTime(2026, 10));
    expect(analysis.averageSession, const Duration(minutes: 100));
    expect(analysis.averageActiveDay, const Duration(minutes: 100));
    expect(
      analysis.days.fold(Duration.zero, (sum, day) => sum + day.total),
      analysis.total,
    );
    expect(
      analysis.weeks.fold(Duration.zero, (sum, week) => sum + week.total),
      analysis.total,
    );
    expect(
      analysis.weeks.fold(
        Duration.zero,
        (sum, week) => sum + analysis.weeklyGoal(week),
      ),
      analysis.goal,
    );
    expect(analysis.weeks.first.monday, DateTime(2026, 9, 28));
    expect(analysis.weeks.first.start, DateTime(2026, 10));
    expect(analysis.weeks.first.end, DateTime(2026, 10, 5));
    final categories = {
      for (final category in analysis.categories) category.category: category,
    };
    expect(categories['Bike Repair']!.total, const Duration(hours: 3));
    expect(categories['Bike Repair']!.sessionCount, 2);
    expect(categories['Bike Repair']!.share, closeTo(0.6, 0.000001));
    expect(categories['Project Work']!.total, const Duration(hours: 2));
  });

  test('Overlaps count extra recorded time, including triple coverage', () {
    final analysis = MonthlyAnalysis(
      [
        Entry(
          'Primary session',
          'General',
          DateTime(2026, 10, 5, 9),
          DateTime(2026, 10, 5, 12),
          'Bike Build',
        ),
        Entry(
          'Second session',
          'General',
          DateTime(2026, 10, 5, 10),
          DateTime(2026, 10, 5, 11),
        ),
        Entry(
          'Third session',
          'General',
          DateTime(2026, 10, 5, 10, 30),
          DateTime(2026, 10, 5, 12, 30),
          '  ',
        ),
      ],
      DateTime(2026, 10),
      asOf: DateTime(2026, 11),
    );

    expect(analysis.total, const Duration(hours: 6));
    expect(analysis.overlapDuration, const Duration(minutes: 150));
    expect(analysis.missingCategoryCount, 2);
    final uncategorized = analysis.categories.singleWhere(
      (category) => category.category == 'Uncategorized',
    );
    expect(uncategorized.total, const Duration(hours: 3));
    expect(uncategorized.sessionCount, 2);
    expect(analysis.checks, isNotEmpty);
  });

  test(
    'Invalid and running sessions are excluded and surfaced for checking',
    () {
      final analysis = MonthlyAnalysis(
        [
          Entry(
            'Valid task',
            'General',
            DateTime(2026, 10, 5, 9),
            DateTime(2026, 10, 5, 10),
            'Administration',
          ),
          Entry('Running', 'General', DateTime(2026, 10, 5, 10)),
          Entry(
            'Zero duration',
            'General',
            DateTime(2026, 10, 5, 11),
            DateTime(2026, 10, 5, 11),
          ),
          Entry(
            'Reversed dates',
            'General',
            DateTime(2026, 10, 6, 12),
            DateTime(2026, 10, 6, 9),
          ),
        ],
        DateTime(2026, 10),
        asOf: DateTime(2026, 10, 12),
      );

      expect(analysis.total, const Duration(hours: 1));
      expect(analysis.sessionCount, 1);
      expect(analysis.activeTimerCount, 1);
      expect(analysis.invalidEntryCount, 2);
      expect(analysis.missingCategoryCount, 0);
      expect(analysis.rows.single.entry.task, 'Valid task');
      expect(analysis.checks, isNotEmpty);
    },
  );

  test('Long session check uses original duration despite month clipping', () {
    final analysis = MonthlyAnalysis(
      [
        Entry(
          'Check forgotten timer',
          'General',
          DateTime(2026, 9, 30, 12),
          DateTime(2026, 10, 1, 1),
          'Project Work',
        ),
      ],
      DateTime(2026, 10),
      asOf: DateTime(2026, 11),
    );

    expect(analysis.total, const Duration(hours: 1));
    expect(analysis.longSessionCount, 1);
    expect(analysis.checks, isNotEmpty);
  });

  test('Current-month comparison uses equal elapsed calendar day and time', () {
    final entries = [
      Entry(
        'October early',
        'General',
        DateTime(2026, 10, 2, 9),
        DateTime(2026, 10, 2, 11),
        'Bike Build',
      ),
      Entry(
        'October cutoff',
        'General',
        DateTime(2026, 10, 12, 11),
        DateTime(2026, 10, 12, 13),
        'Bike Build',
      ),
      Entry(
        'October later',
        'General',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 15),
        'Bike Build',
      ),
      Entry(
        'September early',
        'General',
        DateTime(2026, 9, 2, 9),
        DateTime(2026, 9, 2, 11),
        'Bike Build',
      ),
      Entry(
        'September cutoff',
        'General',
        DateTime(2026, 9, 12, 11),
        DateTime(2026, 9, 12, 13),
        'Bike Build',
      ),
      Entry(
        'September later',
        'General',
        DateTime(2026, 9, 20, 9),
        DateTime(2026, 9, 20, 17),
        'Bike Build',
      ),
    ];
    final analysis = MonthlyAnalysis(
      entries,
      DateTime(2026, 10),
      asOf: DateTime(2026, 10, 12, 12),
    );

    expect(analysis.isCurrentMonth, isTrue);
    expect(analysis.total, const Duration(hours: 10));
    expect(analysis.previousMonthTotal, const Duration(hours: 12));
    expect(analysis.comparisonTotal, const Duration(hours: 3));
    expect(analysis.comparisonPreviousTotal, const Duration(hours: 3));
    expect(analysis.comparisonChangePercent, 0);
    expect(analysis.futureEntryCount, 2);
    expect(
      analysis.rows
          .where(
            (row) =>
                row.flags.contains('Completed entry is dated in the future'),
          )
          .length,
      2,
    );
    expect(
      analysis.weeks.fold(
        Duration.zero,
        (sum, week) => sum + analysis.weeklyGoal(week),
      ),
      analysis.goal,
    );
    expect(
      analysis.weeks.fold(
        Duration.zero,
        (sum, week) => sum + analysis.weeklyGoalActual(week),
      ),
      analysis.comparisonTotal,
    );
  });

  test('Current-month cutoff clamps to shorter previous month', () {
    final analysis = MonthlyAnalysis(
      [
        Entry(
          'Previous month end',
          'General',
          DateTime(2026, 2, 28, 22),
          DateTime(2026, 3, 1, 2),
          'Project Work',
        ),
        Entry(
          'Current month',
          'General',
          DateTime(2026, 3, 30, 9),
          DateTime(2026, 3, 30, 10),
          'Project Work',
        ),
      ],
      DateTime(2026, 3),
      asOf: DateTime(2026, 3, 31, 12),
    );

    expect(analysis.comparisonPreviousTotal, const Duration(hours: 2));
    expect(analysis.comparisonTotal, const Duration(hours: 3));
    expect(analysis.comparisonChangePercent, 50);
  });

  test(
    'No previous baseline and future months avoid misleading percentages',
    () {
      final entry = Entry(
        'October work',
        'General',
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 5, 11),
        'Prospection',
      );
      final past = MonthlyAnalysis(
        [entry],
        DateTime(2026, 10),
        asOf: DateTime(2026, 11),
      );
      expect(past.comparisonPreviousTotal, Duration.zero);
      expect(past.comparisonChangePercent, isNull);
      final future = MonthlyAnalysis(
        [entry],
        DateTime(2026, 10),
        asOf: DateTime(2026, 9, 12),
      );
      expect(future.isFutureMonth, isTrue);
      expect(future.comparisonChangePercent, isNull);
      expect(future.futureEntryCount, 1);
      expect(
        future.weeks.fold(
          Duration.zero,
          (sum, week) => sum + future.weeklyGoal(week),
        ),
        future.goal,
      );
      expect(
        future.weeks.fold(
          Duration.zero,
          (sum, week) => sum + future.weeklyGoalActual(week),
        ),
        Duration.zero,
      );
      final empty = MonthlyAnalysis(
        [],
        DateTime(2026, 10),
        asOf: DateTime(2026, 11),
      );
      expect(empty.total, Duration.zero);
      expect(empty.sessionCount, 0);
      expect(empty.activeDays, 0);
      expect(empty.averageSession, Duration.zero);
      expect(empty.averageActiveDay, Duration.zero);
      expect(empty.busiestDay, isNull);
      expect(empty.categories, isEmpty);
      expect(empty.overlapDuration, Duration.zero);
      expect(empty.comparisonChangePercent, isNull);
    },
  );

  test('Monthly target follows the existing 20-hour weekly goal', () {
    final completed = MonthlyAnalysis(
      [],
      DateTime(2026, 2),
      asOf: DateTime(2026, 3),
    );
    expect(completed.goal, const Duration(hours: 80));
    expect(completed.goalProgress, 0);
    final current = MonthlyAnalysis(
      [],
      DateTime(2026, 2),
      asOf: DateTime(2026, 2, 15),
    );
    expect(current.goal, const Duration(hours: 40));
    expect(current.isCurrentMonth, isTrue);
    final planned = MonthlyAnalysis(
      [],
      DateTime(2026, 2),
      asOf: DateTime(2026, 1),
    );
    expect(planned.goal, const Duration(hours: 80));
    expect(planned.isFutureMonth, isTrue);
  });
}
