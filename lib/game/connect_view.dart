import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';
import 'connect_engine.dart';
import 'rules.dart';
import 'word_ui.dart';

class ConnectView extends StatefulWidget {
  final PlayContext ctx;
  const ConnectView({super.key, required this.ctx});

  @override
  State<ConnectView> createState() => _ConnectViewState();
}

class _ConnectViewState extends State<ConnectView> with RoundClock {
  late ConnectLevel level;
  late ConnectGame game;
  late List<String> wheel;
  final List<int> picked = [];
  int _hints = 0;
  int _solved = 0;
  int _words = 0;
  bool _ended = false;
  String _msg = '';
  bool _good = true;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<ConnectLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? ConnectGame.restore(level.p.of(_tr), snap) : ConnectGame(level.p.of(_tr));
    wheel = [...game.p.letters];
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _solved = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    startClock(
        initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0,
        limit: ctx.spec.mode == GameModeId.timeAttack ? 120 : level.timeLimit);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(_chain ? _solved > 0 : game.won);

  void _persist() =>
      ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _solved});

  String get _current => picked.map((i) => wheel[i]).join();

  void _tap(int i) {
    if (_ended) return;
    setState(() {
      if (picked.isNotEmpty && picked.last == i) {
        picked.removeLast();
      } else if (!picked.contains(i)) {
        picked.add(i);
      }
    });
    ctx.sfx(Sfx.tap);
  }

  void _submit() {
    final w = _current;
    if (w.length < 2) return;
    final res = game.submit(w);
    setState(() {
      picked.clear();
      switch (res) {
        case ConnectResult.target:
          _words++;
          _msg = w;
          _good = true;
        case ConnectResult.bonus:
          _words++;
          _msg = tx(ctx, 'Bonus word! +coins', 'Bonus kelime!');
          _good = true;
        case ConnectResult.duplicate:
          _msg = tx(ctx, 'Already found', 'Zaten bulundu');
          _good = false;
        case ConnectResult.invalid:
          _msg = tx(ctx, 'Not in the list', 'Listede yok');
          _good = false;
      }
    });
    ctx.sfx(switch (res) {
      ConnectResult.target => Sfx.place,
      ConnectResult.bonus => Sfx.coin,
      _ => Sfx.error,
    });
    _persist();
    _checkWin();
  }

  void _checkWin() {
    if (!game.won) return;
    if (_chain) {
      _solved++;
      ctx.sfx(Sfx.combo);
      final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _solved]));
      setState(() {
        level = ConnectRules().build(next).puzzle;
        game = ConnectGame(level.p.of(_tr));
        wheel = [...game.p.letters];
        picked.clear();
      });
      _persist();
      return;
    }
    _end(true);
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    var stars = game.mistakes == 0 && _hints == 0 ? 3 : (game.mistakes <= 3 ? 2 : 1);
    if (level.bonusGoal && game.bonusFound.isEmpty && stars == 3) stars = 2;
    if (_chain) stars = _solved >= 4 ? 3 : (_solved >= 2 ? 2 : 1);
    ctx.finish(RoundResult(
      won: won,
      score: _chain ? _solved * 1000 : (won ? (3000 + game.bonusFound.length * 200 - game.mistakes * 100 - seconds).clamp(100, 9000) : 0),
      stars: won ? stars : 0,
      seconds: seconds,
      moves: game.moves,
      hintsUsed: _hints,
      gameStats: {
        'words_found': _words,
        'bonus_words': game.bonusFound.length,
        'long_words': game.found.where((w) => w.length >= 6).length,
      },
    ));
  }

  Future<void> _hint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => game.hint());
    _persist();
    _checkWin();
  }

  Future<void> _booster() async {
    if (!await ctx.requestBooster()) return;
    setState(game.revealFirstLetters);
    _persist();
  }

  void _shuffle() {
    final r = SeededRandom(mixSeed([ctx.spec.seed, game.moves, seconds]));
    setState(() {
      r.shuffle(wheel);
      picked.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = game.p;
    return WordBackdrop(
      colors: ctx.background,
      child: Column(children: [
        PlayHud(items: [
          (Icons.timer, timeText),
          (Icons.check_circle, '${game.found.length}/${p.targets.length}'),
          (Icons.star, '${game.bonusFound.length}'),
          if (_chain) (Icons.emoji_events, '$_solved'),
        ]),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 8, children: [
              for (final t in p.targets)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var k = 0; k < t.length; k++)
                    LetterTile(
                      game.found.contains(t) || k < (game.revealed[t] ?? 0) ? t[k] : '',
                      size: t.length > 6 ? 28 : 32,
                      color: game.found.contains(t) ? cs.primary : cs.surfaceContainerHighest,
                      textColor: game.found.contains(t) ? cs.onPrimary : cs.onSurface,
                    ),
                ]),
            ]),
          ),
        ),
        FeedbackLine(_msg, good: _good),
        SizedBox(
          height: 44,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final c in _current.split('')) if (c.isNotEmpty) LetterTile(c, size: 36),
          ]),
        ),
        Expanded(
          flex: 6,
          child: LayoutBuilder(builder: (context, c) {
            final side = math.min(c.maxWidth, c.maxHeight) - 8;
            final n = wheel.length;
            final radius = side / 2 - 34;
            return Center(
              child: SizedBox(
                width: side,
                height: side,
                child: Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _WheelPainter(cs.primary.withValues(alpha: 0.12))),
                  ),
                  for (var i = 0; i < n; i++)
                    Positioned(
                      left: side / 2 + radius * math.cos(2 * math.pi * i / n - math.pi / 2) - 28,
                      top: side / 2 + radius * math.sin(2 * math.pi * i / n - math.pi / 2) - 28,
                      child: LetterTile(wheel[i],
                          size: 56,
                          color: picked.contains(i) ? cs.primary : cs.primaryContainer,
                          textColor: picked.contains(i) ? cs.onPrimary : cs.onPrimaryContainer,
                          onTap: () => _tap(i)),
                    ),
                  Center(
                    child: FilledButton(
                      onPressed: picked.length >= 2 ? _submit : null,
                      child: Text(tx(ctx, 'Enter', 'Gir')),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
        BoosterBar(buttons: [
          BoosterButton(Icons.shuffle, tx(ctx, 'Shuffle', 'Karıştır'), _shuffle),
          BoosterButton(Icons.backspace, tx(ctx, 'Clear', 'Temizle'), picked.isEmpty ? null : () => setState(picked.clear)),
          BoosterButton(Icons.auto_fix_high, tx(ctx, 'First letters', 'İlk harfler'), _booster),
          BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
        ]),
      ]),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final Color color;
  _WheelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.color != color;
}
