import '../core/level_plan.dart';
import '../core/rng.dart';
import 'word_kit.dart';

/// Word Connect: form words from a letter wheel to fill the puzzle slots.
class ConnectPuzzle {
  final List<String> letters;
  final List<String> targets;
  final List<String> bonus;
  const ConnectPuzzle(this.letters, this.targets, this.bonus);
}

class ConnectLevel {
  final Dual<ConnectPuzzle> p;
  final int timeLimit;
  final bool bonusGoal;
  const ConnectLevel(this.p, this.timeLimit, this.bonusGoal);
}

ConnectPuzzle makeConnect(WordLang lang, SeededRandom r, int difficulty) {
  final want = (4 + (difficulty - 1) ~/ 3).clamp(4, 7);
  final maxTargets = (3 + difficulty ~/ 2).clamp(3, 8);
  for (var len = want; len >= 3; len--) {
    final bases = [...?lang.byLength[len]];
    r.shuffle(bases);
    for (final base in bases.take(120)) {
      final pool = letterCounts(base);
      final subs = [
        for (final w in lang.words)
          if (w.length >= 3 && w.length <= len && canForm(w, pool)) w
      ];
      if (subs.length < 3) continue;
      subs.remove(base);
      r.shuffle(subs);
      subs.sort((a, b) => b.length.compareTo(a.length));
      final targets = [base, ...subs.take(maxTargets - 1)];
      final bonus = subs.skip(maxTargets - 1).toList();
      targets.sort((a, b) => a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b));
      final letters = base.split('');
      for (var k = 0; k < 6; k++) {
        r.shuffle(letters);
        if (letters.join() != base) break;
      }
      return ConnectPuzzle(letters, targets, bonus);
    }
  }
  return const ConnectPuzzle([], [], []);
}

ConnectLevel generateConnect(LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final en = makeConnect(WordLang.of(false), SeededRandom(r.nextUint32()), spec.difficulty);
  final tr = makeConnect(WordLang.of(true), SeededRandom(r.nextUint32()), spec.difficulty);
  final n = en.targets.length > tr.targets.length ? en.targets.length : tr.targets.length;
  return ConnectLevel(Dual(en, tr), spec.has('timer') ? 40 + n * 15 : 0, spec.has('bonus'));
}

String? checkConnect(ConnectPuzzle p, WordLang lang) {
  if (p.targets.length < 3) return 'few targets';
  final pool = letterCounts(p.letters.join());
  if (p.targets.toSet().length != p.targets.length) return 'duplicate';
  for (final t in [...p.targets, ...p.bonus]) {
    if (!lang.dict.contains(t)) return 'unknown $t';
    if (!canForm(t, pool)) return 'cannot form $t';
  }
  if (!p.targets.any((t) => t.length == p.letters.length)) return 'no full word';
  return null;
}

enum ConnectResult { target, bonus, duplicate, invalid }

class ConnectGame {
  final ConnectPuzzle p;
  final Set<String> found = {};
  final Set<String> bonusFound = {};
  final Map<String, int> revealed = {};
  int mistakes = 0;
  int moves = 0;

  ConnectGame(this.p);

  bool get won => p.targets.every(found.contains);

  ConnectResult submit(String w) {
    moves++;
    if (found.contains(w) || bonusFound.contains(w)) return ConnectResult.duplicate;
    if (p.targets.contains(w)) {
      found.add(w);
      return ConnectResult.target;
    }
    if (p.bonus.contains(w)) {
      bonusFound.add(w);
      return ConnectResult.bonus;
    }
    mistakes++;
    return ConnectResult.invalid;
  }

  /// Reveals one more letter of the first unfound word. Returns the word.
  String? hint() {
    for (final t in p.targets) {
      if (found.contains(t)) continue;
      final n = (revealed[t] ?? 0) + 1;
      revealed[t] = n;
      if (n >= t.length) found.add(t);
      return t;
    }
    return null;
  }

  /// Reveals the first letter of every unfound word (booster).
  void revealFirstLetters() {
    for (final t in p.targets) {
      if (!found.contains(t) && (revealed[t] ?? 0) < 1) revealed[t] = 1;
    }
  }

  String serialize() => [joinList(found), joinList(bonusFound),
        joinList(revealed.entries.map((e) => '${e.key}:${e.value}')), '$mistakes', '$moves'].join('|');

  factory ConnectGame.restore(ConnectPuzzle p, String s) {
    final g = ConnectGame(p);
    final parts = s.split('|');
    if (parts.length < 5) return g;
    g.found.addAll(splitList(parts[0]).where(p.targets.contains));
    g.bonusFound.addAll(splitList(parts[1]));
    for (final kv in splitList(parts[2])) {
      final i = kv.lastIndexOf(':');
      if (i > 0) g.revealed[kv.substring(0, i)] = int.tryParse(kv.substring(i + 1)) ?? 0;
    }
    g.mistakes = int.tryParse(parts[3]) ?? 0;
    g.moves = int.tryParse(parts[4]) ?? 0;
    return g;
  }
}
