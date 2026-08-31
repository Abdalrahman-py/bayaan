/// Human copy for the engine's `sifat_errors` vocabulary.
///
/// The engine reports letter characteristics as raw identifiers —
/// `tafkheem_or_taqeeq`, `mofakham`, `not_moqalqal`. Rendering those straight
/// puts snake_case debug tokens on the result screen. The attribute names are
/// the ones in docs/tajweed-rules.md; the value names keep the tajweed term the
/// learner will hear from a teacher, glossed in English.
///
/// Both maps fall through to a readable form rather than a raw token, so an
/// upstream vocabulary change degrades to plain words instead of jargon.
library;

const _attributeNames = <String, String>{
  'qalqla': 'Qalqalah (bounce)',
  'ghonna': 'Ghunnah (nasal)',
  'tafkheem_or_taqeeq': 'Heavy or light',
  'hams_or_jahr': 'Breath',
  'shidda_or_rakhawa': 'Strength',
  'itbaq': 'Tongue elevation',
  'safeer': 'Whistle',
  'tikraar': 'Trill on rāʾ',
  'tafashie': 'Spreading on shīn',
  'istitala': 'Elongation on ḍād',
};

const _valueNames = <String, String>{
  'hams': 'breathy (hams)',
  'jahr': 'voiced (jahr)',
  'shadeed': 'a firm stop (shadeed)',
  'rikhw': 'flowing (rikhw)',
  'between': 'in between (bayn)',
  'mofakham': 'heavy (mofakham)',
  'moraqaq': 'light (moraqaq)',
  'motbaq': 'raised to the palate (motbaq)',
  'monfateh': 'open (monfateh)',
  'safeer': 'whistled (safeer)',
  'moqalqal': 'bounced (qalqalah)',
  'mokarar': 'trilled (mokarar)',
  'motafashie': 'spread (motafashie)',
  'mostateel': 'elongated (mostateel)',
  'maghnoon': 'nasal (ghunnah)',
};

/// Title for one sifat row, e.g. `tafkheem_or_taqeeq` → "Heavy or light".
String sifatAttributeLabel(String attribute) =>
    _attributeNames[attribute] ?? _prettify(attribute);

/// One side of a sifat mismatch, e.g. `not_moqalqal` → "not bounced (qalqalah)".
String sifatValueLabel(String value) {
  final known = _valueNames[value];
  if (known != null) return known;
  for (final prefix in const ['not_', 'no_', 'non_']) {
    if (value.startsWith(prefix)) {
      final base = value.substring(prefix.length);
      return 'not ${_valueNames[base] ?? _prettify(base).toLowerCase()}';
    }
  }
  return _prettify(value).toLowerCase();
}

/// "Should be light (moraqaq) — you said heavy (mofakham)."
///
/// Target first: the correct sound is what the learner has to reproduce, and
/// leading with what they got wrong is the shape that reads as a scolding.
String sifatDetail(String expected, String predicted) =>
    'Should be ${sifatValueLabel(expected)} — '
    'you said ${sifatValueLabel(predicted)}';

String _prettify(String raw) {
  final words = raw.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return raw;
  return '${words.first[0].toUpperCase()}${words.first.substring(1)}'
      '${words.length > 1 ? ' ${words.skip(1).join(' ')}' : ''}';
}
