import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'connect_engine.dart';
import 'word_kit.dart';

class ConnectRules extends GameRules<ConnectLevel> {
  @override
  String get gameId => 'game-051-word-connect';

  @override
  List<String> get optionalMechanics => const ['bonus', 'timer'];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('words_found', 'Bulunan kelime', 'Words found', scale: 100),
        GameStat('bonus_words', 'Bonus kelime', 'Bonus words', scale: 20),
        GameStat('long_words', 'Uzun kelime (6+)', 'Long words (6+)', scale: 20),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'words_found', [10, 25, 50]),
        MissionTemplate('m2', 'bonus_words', [1, 3, 5], coinReward: 80),
      ];

  @override
  ConnectLevel generate(LevelSpec spec) => generateConnect(spec);

  @override
  Validation validate(ConnectLevel l, LevelSpec spec) {
    final e = checkConnect(l.p.en, WordLang.of(false)) ?? checkConnect(l.p.tr, WordLang.of(true));
    return e == null ? Validation.ok(l.p.en.targets.length) : Validation.fail(e);
  }
}

GameRules createRules() => ConnectRules();
