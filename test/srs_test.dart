import 'package:flutter_test/flutter_test.dart';
import 'package:oxvox/core/srs.dart';

void main() {
  test('new card with Good is due tomorrow', () {
    final c = reviewCard(null, Rating.good);
    expect(c.interval, 1);
    expect(c.reps, 1);
  });

  test('Again resets reps and schedules next day', () {
    final c = reviewCard(const SrsCard(reps: 5, interval: 30, due: '2000-01-01'), Rating.again);
    expect(c.reps, 0);
    expect(c.interval, 1);
  });

  test('ease never drops below 1.3', () {
    var c = reviewCard(null, Rating.again);
    for (var i = 0; i < 20; i++) {
      c = reviewCard(c, Rating.again);
    }
    expect(c.ease >= 1.3, isTrue);
  });
}
