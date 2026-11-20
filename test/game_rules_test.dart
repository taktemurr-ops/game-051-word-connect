import 'package:flutter_test/flutter_test.dart';
import 'package:game_051_word_connect/core/level_plan.dart';
import 'package:game_051_word_connect/game/connect_engine.dart';
import 'package:game_051_word_connect/game/rules.dart';
import 'package:game_051_word_connect/game/word_kit.dart';

void main() {
  final rules = ConnectRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('every target can be built from the wheel, in both languages', () {
    for (final n in [1, 7, 55, 333, 4000, 49999]) {
      final l = rules.build(planner.spec(n)).puzzle;
      for (final tr in [false, true]) {
        final p = l.p.of(tr);
        expect(checkConnect(p, WordLang.of(tr)), isNull, reason: 'level $n tr=$tr');
        expect(p.targets.length, greaterThanOrEqualTo(3));
      }
    }
  });

  test('difficulty grows the wheel', () {
    final easy = rules.build(planner.spec(1)).puzzle.p.en.letters.length;
    final hard = rules.build(planner.spec(4999)).puzzle.p.en.letters.length;
    expect(hard, greaterThanOrEqualTo(easy));
  });

  test('submit targets, bonus, duplicates and invalid words; win', () {
    final p = rules.build(planner.spec(12)).puzzle.p.en;
    final g = ConnectGame(p);
    expect(g.submit('QQQ'), ConnectResult.invalid);
    expect(g.mistakes, 1);
    expect(g.submit(p.targets.first), ConnectResult.target);
    expect(g.submit(p.targets.first), ConnectResult.duplicate);
    if (p.bonus.isNotEmpty) expect(g.submit(p.bonus.first), ConnectResult.bonus);
    for (final t in p.targets) {
      g.submit(t);
    }
    expect(g.won, isTrue);
  });

  test('hints reveal letters and finally the word; resume restores state', () {
    final p = rules.build(planner.spec(3)).puzzle.p.tr;
    final g = ConnectGame(p);
    final w = g.hint()!;
    expect(g.revealed[w], 1);
    g.revealFirstLetters();
    var guard = 0;
    while (!g.won && guard++ < 200) {
      g.hint();
    }
    expect(g.won, isTrue);
    expect(ConnectGame.restore(p, g.serialize()).serialize(), g.serialize());
  });

  test('levels 1..60 valid without fallback-heavy generation', () {
    for (var n = 1; n <= 60; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
