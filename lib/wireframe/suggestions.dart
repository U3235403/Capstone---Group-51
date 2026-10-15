
// Only things that are NOT food, and that people do not buy every week, are
// suggested. Weekly shopping (milk, bread, fruit...) never pops up.


class _Link {
  const _Link(this.keywords, this.suggest);
  final List<String> keywords;
  final List<String> suggest;
}

// Most specific first: the first links that match are used.
const _links = <_Link>[
  _Link(['birthday card'], ['Birthday Present', 'Wrapping Paper', 'Birthday Cake']),
  _Link(['birthday present', 'birthday gift'], ['Wrapping Paper', 'Birthday Card', 'Sticky Tape']),
  _Link(['birthday cake'], ['Candles', 'Birthday Card']),
  _Link(['get well card'], ['Flowers', 'Chocolate']),
  _Link(['sympathy card'], ['Flowers']),
  _Link(['christmas card'], ['Stamps', 'Wrapping Paper']),
  _Link(['wrapping paper'], ['Sticky Tape', 'Birthday Card']),
  _Link(['present', 'gift'], ['Wrapping Paper', 'Birthday Card', 'Sticky Tape']),
  _Link(['card'], ['Stamps']),
  _Link(['stamp'], ['Envelopes']),
  _Link(['envelope'], ['Stamps']),
  _Link(['candle'], ['Matches']),
  _Link(['flowers'], ['Greeting Card']),
  _Link(['bread', 'toast'], ['Butter', 'Jam', 'Eggs']),
  _Link(['butter'], ['Bread', 'Jam']),
  _Link(['jam', 'vegemite', 'peanut butter'], ['Bread', 'Butter']),
  _Link(['pasta', 'spaghetti', 'noodle'], ['Pasta Sauce', 'Cheese']),
  _Link(['pasta sauce'], ['Pasta', 'Cheese']),
  _Link(['mince'], ['Pasta', 'Pasta Sauce', 'Onions']),
  _Link(['cereal', 'porridge', 'oats'], ['Milk', 'Bananas']),
  _Link(['tea'], ['Milk', 'Biscuits', 'Sugar']),
  _Link(['coffee'], ['Milk', 'Sugar', 'Biscuits']),
  _Link(['biscuit', 'cracker'], ['Cheese', 'Tea Bags']),
  _Link(['egg'], ['Bacon', 'Bread']),
  _Link(['bacon'], ['Eggs', 'Bread']),
  _Link(['sausage', 'bbq'], ['Bread Rolls', 'Tomato Sauce', 'Onions']),
  _Link(['chicken'], ['Rice', 'Potatoes', 'Carrots']),
  _Link(['steak', 'lamb', 'pork'], ['Potatoes', 'Carrots', 'Peas']),
  _Link(['fish', 'salmon'], ['Lemons', 'Potatoes', 'Peas']),
  _Link(['ham'], ['Bread', 'Cheese', 'Lettuce']),
  _Link(['lettuce', 'salad'], ['Tomatoes', 'Cucumber']),
  _Link(['ice cream'], ['Chocolate']),
  _Link(['toothpaste'], ['Toothbrush']),
  _Link(['toothbrush'], ['Toothpaste']),
  _Link(['shampoo'], ['Conditioner', 'Soap']),
  _Link(['conditioner'], ['Shampoo', 'Soap']),
  _Link(['soap'], ['Shampoo']),
  _Link(['dishwashing', 'dish liquid'], ['Sponges']),
  _Link(['toilet paper'], ['Tissues']),
  _Link(['battery', 'batteries'], ['Light Bulbs']),
  _Link(['light bulb'], ['Batteries']),
  // Household and cleaning
  _Link(['cleaner', 'cleaning spray', 'disinfectant'], ['Sponges', 'Paper Towels', 'Gloves']),
  _Link(['sponge'], ['Dishwashing Liquid']),
  _Link(['paper towel'], ['Dishwashing Liquid']),
  _Link(['glove'], ['Cleaning Spray', 'Sponges']),
  _Link(['bin bag', 'rubbish bag', 'garbage bag'], ['Paper Towels']),
  _Link(['aluminium foil', 'foil\\b'], ['Cling Wrap', 'Baking Paper']),
  _Link(['cling wrap'], ['Aluminium Foil', 'Sandwich Bags']),
  _Link(['baking paper'], ['Aluminium Foil']),
  _Link(['sandwich bag'], ['Cling Wrap']),
  _Link(['matches\\b'], ['Candles']),
  // Personal care and pharmacy
  _Link(['razor'], ['Shaving Cream']),
  _Link(['shaving'], ['Razors']),
  _Link(['deodorant'], ['Soap', 'Shampoo']),
  _Link(['body wash', 'shower'], ['Shampoo', 'Soap']),
  _Link(['moisturiser', 'moisturizer'], ['Hand Cream']),
  _Link(['hand cream'], ['Moisturiser']),
  _Link(['band aid', 'bandage', 'plaster'], ['Antiseptic Cream']),
  _Link(['antiseptic'], ['Band-Aids']),
  _Link(['tissue'], ['Toilet Paper']),
  _Link(['cough', 'flu\\b', 'cold and flu'], ['Tissues', 'Throat Lozenges']),
  _Link(['throat lozenge'], ['Tissues']),
  _Link(['denture cleaner'], ['Denture Adhesive']),
  _Link(['denture adhesive'], ['Denture Cleaner']),
  // Stationery, gifts and occasions
  _Link(['pens?\\b'], ['Notepad', 'Envelopes']),
  _Link(['notepad', 'notebook'], ['Pens']),
  _Link(['printer paper'], ['Printer Ink']),
  _Link(['ink\\b'], ['Printer Paper']),
  _Link(['sticky tape', 'tape\\b'], ['Wrapping Paper', 'Scissors']),
  _Link(['balloon'], ['Birthday Cake', 'Candles']),
  // Pets
  _Link(['dog food'], ['Dog Treats']),
  _Link(['cat food'], ['Cat Litter']),
  _Link(['cat litter'], ['Cat Food']),
  // Garden
  _Link(['potting mix'], ['Plant Pots', 'Fertiliser']),
  _Link(['plants?\\b'], ['Potting Mix', 'Fertiliser']),
];

// The only things the pop-up may suggest: non-food, not bought weekly.
const _allowed = <String>{
  'Birthday Present', 'Wrapping Paper', 'Birthday Card', 'Greeting Card',
  'Flowers', 'Stamps', 'Envelopes', 'Candles', 'Matches', 'Sticky Tape',
  'Toothbrush', 'Toothpaste', 'Conditioner', 'Shampoo', 'Soap', 'Sponges',
  'Tissues', 'Light Bulbs', 'Batteries', 'Paper Towels', 'Gloves',
  'Cleaning Spray', 'Dishwashing Liquid', 'Cling Wrap', 'Baking Paper',
  'Aluminium Foil', 'Sandwich Bags', 'Razors', 'Shaving Cream', 'Hand Cream',
  'Moisturiser', 'Antiseptic Cream', 'Band-Aids', 'Throat Lozenges',
  'Denture Cleaner', 'Denture Adhesive', 'Notepad', 'Pens', 'Printer Ink',
  'Printer Paper', 'Scissors', 'Cat Litter', 'Plant Pots', 'Fertiliser',
  'Potting Mix', 'Toilet Paper',
};

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z ]+'), ' ').trim();

// Up to [max] items people often add together with [name], leaving out
// anything already on the list.
List<String> relatedItems(
  String name,
  Iterable<String> alreadyOnList, {
  int max = 3,
  bool Function(String name)? skip,
}) {
  final n = _norm(name);
  if (n.isEmpty) return [];
  final have = alreadyOnList.map(_norm).toList();
  bool onList(String s) {
    final t = _norm(s);
    return have.any((h) => h == t || h.contains(t) || t.contains(h));
  }

  final out = <String>[];
  for (final link in _links) {
    if (!link.keywords.any((k) => RegExp('\\b$k').hasMatch(n))) continue;
    for (final s in link.suggest) {
      if (!_allowed.contains(s)) continue;
      if (skip != null && skip(s)) continue;
      if (!out.contains(s) && !onList(s)) out.add(s);
      if (out.length >= max) return out;
    }
  }
  return out;
}