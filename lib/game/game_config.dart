import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'connect_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-051-word-connect',
  title: const ['Kelime Bağla', 'Word Connect', 'Wörter Verbinden', 'Conecta Palabras', 'Relie les Mots'],
  tagline: const ['Harfleri birleştir, bulmacayı kelimelerle doldur!', 'Link the letters and fill the puzzle with words!', 'Verbinde Buchstaben zu Wörtern!', '¡Une letras y forma palabras!', 'Reliez les lettres pour former des mots !'],
  seedColor: const Color(0xFF7B2CBF),
  icon: Icons.hub,
  rules: ConnectRules(),
  buildPlay: (ctx) => ConnectView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.touch_app, ['Harflere sırayla dokun, son harfe tekrar dokunursan geri alınır.', 'Tap letters in order; tap the last one again to undo.', 'Tippe Buchstaben nacheinander an.', 'Toca las letras en orden.', 'Touchez les lettres dans l\'ordre.']),
    TutorialStep(Icons.star, ['Listede olmayan ama geçerli kelimeler bonus sayılır.', 'Valid words that are not in the puzzle count as bonus words.', 'Gültige Extrawörter sind Bonuswörter.', 'Las palabras extra válidas son bonus.', 'Les mots valides en plus sont des bonus.']),
    TutorialStep(Icons.shuffle, ['Takılırsan harfleri karıştır ya da ipucu kullan.', 'Stuck? Shuffle the letters or use a hint.', 'Mischen oder Tipp nutzen.', 'Mezcla o usa una pista.', 'Mélangez ou utilisez un indice.']),
  ],
);
