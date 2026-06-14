/// Regional ω anchor — scopes user inputs and observations to the selected region.
class RegionContext {
  const RegionContext(this.regionId);

  final String regionId;

  bool get isGlobal => regionId == 'global';

  static const _keywords = <String, List<String>>{
    'global': [],
    'usa': [
      'usa',
      'u.s.',
      'u.s.a.',
      'united states',
      'america',
      'american',
      'washington',
      'white house',
      'congress',
      'federal',
      'pentagon',
      'new york',
      'california',
      'texas',
      'florida',
    ],
    'americas': [
      'americas',
      'canada',
      'mexico',
      'brazil',
      'argentina',
      'chile',
      'colombia',
      'ottawa',
      'mexico city',
    ],
    'europe': [
      'europe',
      'european',
      'eu',
      'france',
      'germany',
      'spain',
      'italy',
      'poland',
      'netherlands',
      'belgium',
      'sweden',
      'norway',
      'paris',
      'berlin',
      'madrid',
      'rome',
      'brussels',
    ],
    'uk_ireland': [
      'uk',
      'u.k.',
      'britain',
      'british',
      'scotland',
      'scottish',
      'wales',
      'welsh',
      'england',
      'english',
      'ireland',
      'irish',
      'northern ireland',
      'belfast',
      'london',
      'edinburgh',
      'cardiff',
      'glasgow',
      'manchester',
    ],
    'mena': [
      'mena',
      'middle east',
      'north africa',
      'saudi',
      'uae',
      'egypt',
      'turkey',
      'iran',
      'iraq',
      'israel',
      'palestine',
      'morocco',
      'algeria',
      'tunisia',
      'dubai',
      'cairo',
      'riyadh',
    ],
    'sub_saharan_africa': [
      'sub-saharan',
      'nigeria',
      'kenya',
      'south africa',
      'ghana',
      'ethiopia',
      'tanzania',
      'uganda',
      'senegal',
      'lagos',
      'nairobi',
      'johannesburg',
    ],
    'south_asia': [
      'south asia',
      'india',
      'indian',
      'pakistan',
      'bangladesh',
      'sri lanka',
      'nepal',
      'delhi',
      'mumbai',
      'karachi',
      'dhaka',
    ],
    'east_asia': [
      'east asia',
      'china',
      'chinese',
      'japan',
      'japanese',
      'korea',
      'korean',
      'taiwan',
      'beijing',
      'shanghai',
      'tokyo',
      'seoul',
    ],
    'southeast_asia': [
      'southeast asia',
      'indonesia',
      'vietnam',
      'thailand',
      'philippines',
      'malaysia',
      'singapore',
      'myanmar',
      'jakarta',
      'bangkok',
      'manila',
    ],
    'oceania': [
      'oceania',
      'australia',
      'australian',
      'new zealand',
      'zealand',
      'pacific',
      'sydney',
      'melbourne',
      'auckland',
      'wellington',
    ],
  };

  static const _constructBias = <String, ({double v, double s, double r, double f})>{
    'usa': (v: 3.5, s: 2.8, r: 2.2, f: 2.2),
    'americas': (v: 3, s: 2.5, r: 2, f: 2),
    'europe': (v: 3, s: 2, r: 2.5, f: 2),
    'uk_ireland': (v: 4, s: 3, r: 2.5, f: 1.5),
    'mena': (v: 3.5, s: 3.5, r: 3, f: 1.5),
    'sub_saharan_africa': (v: 3, s: 3, r: 2.5, f: 2),
    'south_asia': (v: 3, s: 2.5, r: 2.5, f: 2.5),
    'east_asia': (v: 2.5, s: 2, r: 3, f: 2.5),
    'southeast_asia': (v: 3, s: 2.5, r: 2, f: 2.5),
    'oceania': (v: 2.5, s: 2, r: 2, f: 3),
  };

  List<String> get keywords => _keywords[regionId] ?? const [];

  bool textMatchesRegion(String text) {
    if (isGlobal) return true;
    final lower = text.toLowerCase();
    return keywords.any((k) => RegExp(r'\b' + RegExp.escape(k) + r'\b').hasMatch(lower));
  }

  bool hasForeignGeography(String text) {
    if (isGlobal) return false;
    final lower = text.toLowerCase();
    for (final entry in _keywords.entries) {
      if (entry.key == regionId || entry.key == 'global') continue;
      for (final word in entry.value) {
        if (RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(lower)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Scope a subject line to the selected region when geography is absent.
  String scopeSubject(String subject, String regionLabel) {
    final t = subject.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (isGlobal || t.isEmpty) return t;
    if (textMatchesRegion(t)) return t;
    return '$t — $regionLabel focus';
  }

  /// Scope user-supplied construct text to the selected region.
  String scopeFieldText(String text, String regionLabel) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (isGlobal || t.isEmpty) return t;
    if (textMatchesRegion(t)) return t;
    return '$t [$regionLabel focus]';
  }

  ({double vortex, double shear, double resistance, double flow}) constructBias() {
    if (isGlobal) return (vortex: 0, shear: 0, resistance: 0, flow: 0);
    final b = _constructBias[regionId];
    if (b == null) return (vortex: 2, shear: 2, resistance: 2, flow: 2);
    return (vortex: b.v, shear: b.s, resistance: b.r, flow: b.f);
  }

  static String englishLabel(String regionId) => switch (regionId) {
        'usa' => 'United States',
        'americas' => 'Americas',
        'europe' => 'Europe',
        'uk_ireland' => 'UK & Ireland',
        'mena' => 'Middle East & North Africa',
        'sub_saharan_africa' => 'Sub-Saharan Africa',
        'south_asia' => 'South Asia',
        'east_asia' => 'East Asia',
        'southeast_asia' => 'Southeast Asia',
        'oceania' => 'Oceania',
        _ => 'Global',
      };
}