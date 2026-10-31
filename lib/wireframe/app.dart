import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../shopping_item.dart';
import 'model.dart';
import 'account.dart';
import 'settings.dart';
import 'suggestions.dart';

// Green palette. `green` is the main colour.
const paper = Color(0xfff6f7f2),
    ink = Color(0xff1a1917),
    green = Color(0xff4f6f52);
const line = Color(0xffdfe4d8),
    muted = Color(0xff66685f),
    pale = Color(0xffe6ede0);
const label = Color(0xff8e948a),
    amber = Color(0xff9a6b2f),
    yellow = Color(0xfff4ead3);
// Extra shades of the main green.
const greenDeep = Color(0xff2f4a33),
    greenMid = Color(0xff6f9273),
    greenLight = Color(0xffc9d9c4),
    mint = Color(0xfff0f5ec);
TextStyle type(double size, [int weight = 400, Color color = ink]) => TextStyle(
  fontFamily: 'Inter',
  letterSpacing: 0,
  fontSize: math.max(14.0, size * 1.05),
  fontWeight: FontWeight.values[weight ~/ 100 - 1],
  color: color,
  height: 1.3,
  fontVariations: const [FontVariation('opsz', 14)],
);
Widget words(
  String value,
  double size, {
  int weight = 400,
  Color color = ink,
  TextAlign? align,
  bool strike = false,
}) => Text(
  value,
  textAlign: align,
  style: type(
    size * uiTextScale,       
    weight,
    color,
  ).copyWith(decoration: strike ? TextDecoration.lineThrough : null),
);
Widget asset(String screen, String name, double w, [double? h]) =>
    ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/figma/$screen-img$name.svg',
        width: w,
        height: h ?? w,
        fit: BoxFit.contain,
      ),
    );

// Common grocery items used for suggestions and spell-check.
const commonItems = <String>[
  'Apples',
  'Bananas',
  'Oranges',
  'Mandarins',
  'Grapes',
  'Strawberries',
  'Blueberries',
  'Lemons',
  'Pears',
  'Peaches',
  'Mangoes',
  'Watermelon',
  'Pineapple',
  'Avocado',
  'Potatoes',
  'Sweet Potatoes',
  'Carrots',
  'Onions',
  'Garlic',
  'Tomatoes',
  'Lettuce',
  'Cucumber',
  'Broccoli',
  'Cauliflower',
  'Cabbage',
  'Spinach',
  'Pumpkin',
  'Zucchini',
  'Capsicum',
  'Mushrooms',
  'Celery',
  'Corn',
  'Peas',
  'Beans',
  'Milk',
  'Skim Milk',
  'Soy Milk',
  'Almond Milk',
  'Cream',
  'Sour Cream',
  'Butter',
  'Margarine',
  'Cheese',
  'Cheddar Cheese',
  'Cottage Cheese',
  'Yoghurt',
  'Eggs',
  'Ice Cream',
  'Bread',
  'Wholemeal Bread',
  'Bread Rolls',
  'Crumpets',
  'English Muffins',
  'Croissants',
  'Cake',
  'Biscuits',
  'Crackers',
  'Cereal',
  'Porridge Oats',
  'Rice',
  'Pasta',
  'Noodles',
  'Flour',
  'Sugar',
  'Salt',
  'Pepper',
  'Honey',
  'Jam',
  'Vegemite',
  'Peanut Butter',
  'Olive Oil',
  'Vegetable Oil',
  'Vinegar',
  'Tomato Sauce',
  'Pasta Sauce',
  'Soup',
  'Baked Beans',
  'Tinned Tomatoes',
  'Tinned Tuna',
  'Tinned Fruit',
  'Chicken',
  'Chicken Breast',
  'Beef Mince',
  'Steak',
  'Lamb',
  'Pork',
  'Sausages',
  'Bacon',
  'Ham',
  'Fish',
  'Salmon',
  'Prawns',
  'Tea Bags',
  'Coffee',
  'Hot Chocolate',
  'Orange Juice',
  'Apple Juice',
  'Water',
  'Lemonade',
  'Chocolate',
  'Lollies',
  'Chips',
  'Nuts',
  'Toilet Paper',
  'Tissues',
  'Paper Towels',
  'Dishwashing Liquid',
  'Laundry Powder',
  'Soap',
  'Shampoo',
  'Conditioner',
  'Toothpaste',
  'Toothbrush',
  'Deodorant',
  'Razors',
  'Bin Bags',
  'Sponges',
  'Batteries',
  'Light Bulbs',
  'Paracetamol',
  'Vitamins',
  'Band-Aids',
  'Cat Food',
  'Dog Food',
  'Razors',
  'Shaving Cream',
  'Moisturiser',
  'Hand Cream',
  'Antiseptic Cream',
  'Throat Lozenges',
  'Denture Cleaner',
  'Cleaning Spray',
  'Gloves',
  'Aluminium Foil',
  'Cling Wrap',
  'Baking Paper',
  'Sandwich Bags',
  'Candles',
  'Matches',
  'Pens',
  'Notepad',
  'Printer Paper',
  'Envelopes',
  'Stamps',
  'Greeting Card',
  'Birthday Card',
  'Birthday Present',
  'Wrapping Paper',
  'Sticky Tape',
  'Scissors',
  'Dog Treats',
  'Cat Litter',
  'Plant Pots',
  'Potting Mix',
];

// Cleans up a typed item name.
String cleanName(String value) {
  final t = value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return t.length > 60 ? t.substring(0, 60) : t;
}

// Edit distance between two words, used for spell-check.
int editDistance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

// Auto-complete by substring, falling back to spelling suggestions
// from known item names.
List<String> suggestionsFor(String typed, Iterable<String> known) {
  final t = typed.trim().toLowerCase();
  if (t.isEmpty) return [];
  final names = known.toSet().toList();
  final out = <String>[
    for (final n in names)
      if (n.toLowerCase() != t && n.toLowerCase().contains(t)) n,
  ];
  if (out.isEmpty && t.length >= 3) {
    final allowed = t.length > 5 ? 2 : 1;
    for (final n in names) {
      final l = n.toLowerCase();
      if (l == t) continue;
      final close = editDistance(t, l) <= allowed ||
          l.split(RegExp(r'[^a-z]+')).any(
            (w) => w.length >= 3 && editDistance(t, w) <= allowed,
          );
      if (close) out.add(n);
    }
  }
  return out.take(4).toList();
}

// Reduces a name such as "Fresh Whole Milk" to "milk" for picture search.
String searchTerm(String name) {
  var t = name.toLowerCase().replaceAll(RegExp(r'\(.*?\)'), ' ');
  for (final w in [
    'fresh', 'whole', 'organic', 'sliced', 'grade a', 'white', 'red',
    'large', 'small', 'free range',
  ]) {
    t = t.replaceAll(RegExp('\\b$w\\b'), ' ');
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.isEmpty ? name : t;
}


// Picture descriptions for common items, checked in order.
const _subjects = <List<String>>[
  ['eggplant', 'a purple eggplant'],
  ['watermelon', 'a slice of watermelon'],
  ['ice cream', 'an ice cream cone with a scoop of vanilla ice cream'],
  ['milk', 'a plastic bottle of milk with a white label'],
  ['banana', 'a bunch of yellow bananas'],
  ['apple', 'three red apples'],
  ['orange juice', 'a carton of orange juice with a glass of orange juice'],
  ['orange', 'three whole oranges'],
  ['mandarin', 'three mandarins'],
  ['grape', 'a bunch of green grapes'],
  ['strawberr', 'a pile of fresh strawberries'],
  ['blueberr', 'a small pile of blueberries'],
  ['lemon', 'two whole lemons'],
  ['pear', 'two green pears'],
  ['peach', 'two peaches'],
  ['mango', 'a ripe mango'],
  ['tomato', 'three red tomatoes'],
  ['potato', 'three potatoes'],
  ['carrot', 'a bunch of carrots'],
  ['onion', 'two brown onions'],
  ['broccoli', 'a head of broccoli'],
  ['lettuce', 'a head of green lettuce'],
  ['cucumber', 'a cucumber'],
  ['egg', 'a carton of white eggs'],
  ['bread', 'a loaf of sliced bread'],
  ['butter', 'a block of butter'],
  ['cheese', 'a block of yellow cheese'],
  ['yogurt', 'a tub of yogurt'],
  ['yoghurt', 'a tub of yogurt'],
  ['chicken', 'raw chicken pieces on a tray'],
  ['beef', 'a piece of raw beef steak'],
  ['mince', 'a tray of minced beef'],
  ['sausage', 'a row of sausages'],
  ['bacon', 'rashers of bacon'],
  ['fish', 'a raw fish fillet'],
  ['salmon', 'a salmon fillet'],
  ['rice', 'a bag of white rice'],
  ['pasta', 'a bag of dried pasta'],
  ['cereal', 'a box of breakfast cereal'],
  ['tea', 'a box of tea bags and a cup of tea'],
  ['coffee', 'a jar of instant coffee'],
  ['water', 'a bottle of water'],
  ['toilet', 'a pack of toilet rolls'],
  ['tissue', 'a box of tissues'],
  ['toothpaste', 'a tube of toothpaste'],
  ['soap', 'a bar of soap'],
  ['shampoo', 'a bottle of shampoo'],
  ['dog food', 'a bag of dog food'],
  ['cat food', 'a tin of cat food'],
];

String pictureSubject(String name) {
  final n = name.toLowerCase();
  for (final s in _subjects) {
    if (RegExp('\\b${s[0]}').hasMatch(n)) return s[1];
  }
  final t = searchTerm(name);
  return 'a $t, as sold in a shop';
}

// ---- Item pictures -----------------------------------------------------
// Generates an item picture with the Pollinations image service (no key).
// The service allows about one picture per 15 seconds, so requests are
// queued. On failure a Wikipedia photo is tried, then the icon.
// TODO: route this through the backend to remove the rate limit and keep a key private.
Future<void> _aiQueue = Future.value();
DateTime _lastAi = DateTime(2000);
final _inflight = <String, Future<String?>>{};

String photoProblem = '';

// Looks for a bundled picture in assets/items/ (e.g. milk.jpg for "Milk").
// Returns base64 text, or null if there is no picture for the item.
String _slug(String v) =>
    v.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

Future<String?> assetPhoto(String name) async {
  final tries = <String>{};
  for (final base in {_slug(name), _slug(searchTerm(name))}) {
    if (base.isEmpty) continue;
    tries.add(base);
    tries.add('${base}s');
    if (base.endsWith('s')) tries.add(base.substring(0, base.length - 1));
    if (base.endsWith('ies')) tries.add('${base.substring(0, base.length - 3)}y');
  }
  for (final t in tries) {
    try {
      await rootBundle.load('assets/items/$t.jpg');
      // Only the file name is stored with the item, not the picture.
      return 'asset:$t';
    } catch (_) {
      // no picture with that file name, try the next one
    }
  }
  return null;
}

final _tries = <String, int>{};
// Source of each item's picture (shown in the Picture box).
final photoOrigin = <String, String>{};

Future<String?> findPhoto(String name) {
  final key = name.toLowerCase().trim();
  return _inflight.putIfAbsent(key, () async {
    try {
      // 0) Bundled picture (instant, always available).
      final bundled = await assetPhoto(name);
      if (bundled != null) {
        photoProblem = '';
        photoOrigin[key] = 'from your pictures (${bundled.substring(6)}.jpg)';
        return bundled;
      }
      // 1) Wikimedia Commons photo.
      final real = await commonsPhoto(name, _tries[key] ?? 0);
      if (real != null) {
        photoProblem = '';
        photoOrigin[key] = 'from the photo library';
        return real;
      }
      // 2) Wikipedia page image.
      final wiki = await wikiPhoto(name);
      if (wiki != null) {
        photoProblem = '';
        photoOrigin[key] = 'from Wikipedia';
        return wiki;
      }
      // 3) AI-generated picture (slow, last resort).
      final job = _aiQueue.then((_) => _makePicture(name));
      _aiQueue = job.then((_) {}, onError: (_) {});
      final made = await job;
      if (made != null) {
        photoOrigin[key] =
            'made by AI (no file named ${_slug(name)}.jpg in assets/items)';
      }
      return made;
    } finally {
      _inflight.remove(key);
    }
  });
}

// Searches Wikimedia Commons for a photo of the item.
// [pick] selects the 1st, 2nd, 3rd... result for "Try another".
Future<String?> commonsPhoto(String name, int pick) async {
  try {
    final term = searchTerm(name);
    final parts = term.split(' ');
    // Try the full name first, then the main word (e.g. "dog bone" -> "bone").
    final attempts = <String>{term, parts.last};
    for (final q in attempts) {
      final got = await _commonsSearch(q, parts.last, pick);
      if (got != null) return got;
    }
    return null;
  } catch (e) {
    photoProblem = 'Could not reach the photo library ($e)';
    return null;
  }
}

Future<String?> _commonsSearch(String term, String first, int pick) async {
  try {
    final api = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrnamespace': '6',
      'gsrsearch': '$term filetype:bitmap',
      'gsrlimit': '20',
      'prop': 'imageinfo',
      'iiprop': 'url|mime|size',
      'iiurlwidth': '400',
      'format': 'json',
      'origin': '*',
    });
    final res = await http.get(api).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      photoProblem = 'Photo library said: ${res.statusCode}';
      return null;
    }
    final pages = (jsonDecode(res.body)['query']?['pages'] as Map?)?.values
        .whereType<Map>()
        .toList();
    if (pages == null || pages.isEmpty) return null;
    pages.sort(
      (x, y) => ((x['index'] ?? 99) as num).compareTo((y['index'] ?? 99) as num),
    );
    final urls = <String>[];
    for (final p in pages) {
      final info = (p['imageinfo'] as List?)?.first as Map?;
      if (info == null || info['mime'] != 'image/jpeg') continue;
      final title = '${p['title']}'.toLowerCase();
      if (!title.contains(first.toLowerCase())) continue;
      final url = (info['thumburl'] ?? info['url']) as String?;
      if (url != null) urls.add(url);
    }
    if (urls.isEmpty) return null;
    for (var i = 0; i < urls.length; i++) {
      final url = urls[(pick + i) % urls.length];
      final img = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );
      if (img.statusCode == 200 &&
          img.bodyBytes.isNotEmpty &&
          img.bodyBytes.length < 300000) {
        return base64Encode(img.bodyBytes);
      }
    }
    return null;
  } catch (e) {
    photoProblem = 'Could not reach the photo library ($e)';
    return null;
  }
}

Future<String?> _makePicture(String name) async {
  final wait = 16 - DateTime.now().difference(_lastAi).inSeconds;
  if (wait > 0) await Future<void>.delayed(Duration(seconds: wait));
  final prompt =
      'realistic photograph of ${pictureSubject(name)}, the whole object '
      'fully visible and centred, isolated on a plain white background, '
      'simple, clear, natural colours, studio lighting, no text, no people';
  final url = Uri.https('image.pollinations.ai', '/prompt/$prompt', {
    'width': '384',
    'height': '384',
    'model': 'flux',
    'nologo': 'true',
    'seed': '7',
  });
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      _lastAi = DateTime.now();
      final res = await http.get(url).timeout(const Duration(seconds: 90));
      final isImage = (res.headers['content-type'] ?? '').startsWith('image');
      if (res.statusCode == 200 &&
          isImage &&
          res.bodyBytes.isNotEmpty &&
          res.bodyBytes.length < 150000) {
        return base64Encode(res.bodyBytes);
      }
      if (res.statusCode == 429) {
        await Future<void>.delayed(const Duration(seconds: 16));
        continue;
      }
      photoProblem = 'AI picture service said: ${res.statusCode}';
      return null;
    } catch (e) {
      photoProblem = 'Could not reach the AI picture service ($e)';
      return null;
    }
  }
  return null;
}

// Looks up a photo of the item on Wikipedia/Wikimedia.
// Returns base64 text, or null if none is found.
Future<String?> wikiPhoto(String name) async {
  try {
    final search = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': searchTerm(name),
      'gsrlimit': '5',
      'prop': 'pageimages',
      'piprop': 'thumbnail',
      'pithumbsize': '400',
      'format': 'json',
      'origin': '*',
    });
    final res = await http.get(search).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      photoProblem = 'Wikipedia said: ${res.statusCode}';
      return null;
    }
    final pages = (jsonDecode(res.body)['query']?['pages'] as Map?)?.values
        .whereType<Map>()
        .where((p) => p['thumbnail'] != null)
        .toList();
    if (pages == null || pages.isEmpty) return null;
    pages.sort(
      (x, y) => ((x['index'] ?? 99) as num).compareTo((y['index'] ?? 99) as num),
    );
    final url = pages.first['thumbnail']['source'] as String;
    final img = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 8),
    );
    if (img.statusCode != 200 || img.bodyBytes.length > 300000) return null;
    return base64Encode(img.bodyBytes);
  } catch (e) {
    photoProblem = 'Could not reach Wikipedia ($e)';
    return null;
  }
}

// Automatic picture: an icon chosen from the item name.
IconData iconFor(String name) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['milk'])) return Icons.local_drink;
  if (has(['egg'])) return Icons.egg;
  if (has(['bread', 'bun', 'roll', 'bagel', 'croissant'])) {
    return Icons.bakery_dining;
  }
  if (has(['cake', 'muffin', 'biscuit', 'cookie', 'cracker'])) {
    return Icons.cookie;
  }
  if (has(['cheese', 'yogurt', 'yoghurt', 'butter', 'cream'])) {
    return Icons.icecream;
  }
  if (has(['fish', 'salmon', 'tuna', 'prawn'])) return Icons.set_meal;
  if (has(['chicken', 'beef', 'lamb', 'pork', 'sausage', 'bacon', 'meat',
      'mince', 'ham'])) {
    return Icons.kebab_dining;
  }
  if (has(['rice', 'pasta', 'noodle', 'cereal', 'oat', 'flour'])) {
    return Icons.rice_bowl;
  }
  if (has(['tea', 'coffee'])) return Icons.local_cafe;
  if (has(['juice', 'water', 'drink', 'soda', 'cola'])) {
    return Icons.local_drink;
  }
  if (has(['soap', 'shampoo', 'toothpaste', 'tissue', 'toilet', 'detergent',
      'cleaner', 'wash'])) {
    return Icons.soap;
  }
  if (has(['tablet', 'medicine', 'vitamin', 'paracetamol', 'panadol'])) {
    return Icons.medication;
  }
  if (has(['dog', 'cat food', 'pet'])) return Icons.pets;
  if (has(['banana', 'apple', 'orange', 'grape', 'berry', 'lemon', 'pear',
      'peach', 'mango', 'fruit', 'potato', 'carrot', 'onion', 'tomato',
      'lettuce', 'salad', 'broccoli', 'cucumber', 'veg'])) {
    return Icons.eco;
  }
  return Icons.shopping_basket;
}

// Square item picture: the user's photo if set, otherwise the icon.
Widget itemPicture(String name, String? photo, double size) {
  size = size * 1.25;
  Uint8List? bytes;
  final bundled = photo != null && photo.startsWith('asset:')
      ? 'assets/items/${photo.substring(6)}.jpg'
      : null;
  if (photo != null && bundled == null) {
    try {
      bytes = base64Decode(photo);
    } catch (_) {
      bytes = null;
    }
  }
  final fallback = Icon(iconFor(name), size: size * .55, color: green);
  return ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: bytes == null && bundled == null ? pale : Colors.white,
        alignment: Alignment.center,
        child: bundled != null
            ? Image.asset(
                bundled,
                width: size,
                height: size,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => fallback,
              )
            : bytes == null
            ? fallback
            : Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => fallback,
              ),
      ),
    ),
  );
}

class FrameDecoration extends BoxDecoration {
  const FrameDecoration({super.color, super.border, super.borderRadius});
  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;
}

BoxDecoration box({
  Color color = Colors.white,
  double radius = 16,
  Color? border = line,
  double thickness = 1,
}) => FrameDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: border == null ? null : Border.all(color: border, width: thickness),
);

class Tap extends StatelessWidget {
  const Tap({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.checked,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? checked;
  @override
  Widget build(BuildContext context) => Semantics(
    button: checked == null,
    checked: checked,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    ),
  );
}

class WireframeApp extends StatelessWidget {
  const WireframeApp({super.key, this.model, this.initialScreen = 'home'});
  final WireframeModel? model;
  final String initialScreen;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Shopping List',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Inter',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Inter'),
      splashFactory: NoSplash.splashFactory,
    ),
    // Everything is laid out on a 420 wide page, then scaled to the screen
    // width so proportions are the same on every device.
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      final width = math.min(mq.size.width, 560.0);
      final scale = width / designWidth;
      final inner = Size(designWidth, mq.size.height / scale);
      return ColoredBox(
        color: ink,
        child: Center(
          child: SizedBox(
            width: width,
            height: mq.size.height,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: inner.width,
                height: inner.height,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: inner,
                    padding: mq.padding / scale,
                    viewPadding: mq.viewPadding / scale,
                    viewInsets: mq.viewInsets / scale,
                    textScaler: TextScaler.noScaling,
                  ),
                  child: child ?? const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );
    },
    home: WireframeHome(model: model, initialScreen: initialScreen),
  );
}

const double designWidth = 480;

class WireframeHome extends StatefulWidget {
  const WireframeHome({super.key, this.model, required this.initialScreen});
  final WireframeModel? model;
  final String initialScreen;
  @override
  State<WireframeHome> createState() => _WireframeHomeState();
}

class _WireframeHomeState extends State<WireframeHome> {
  late final WireframeModel model = widget.model ?? WireframeModel();
  late String screen = widget.initialScreen;
  String selected = 'Fresh Whole Milk', category = 'All';
  int catShown = 6;
  final search = TextEditingController();
  final pastSearch = TextEditingController();
  String pastCategory = 'All';
  int pastShown = 9;
  ShoppingItem? editing;
  String? photo;
  bool userPhoto = false;
  String settingsPage = '';
  bool newLimit = false;
  bool prompt = false;
  final addName = TextEditingController();
  final editName = TextEditingController();
  int dupQty = 1;
  bool detailed = false, addFav = false, pendingDetails = false;
  String? addCategory;
  String? editCategory;
  String assignTo = '', storeSel = '';
  List<int> shopQueue = [];
  int shopIndex = 0, shopGot = 0;
  String addUnit = 'items';
  int addQty = 1;
  ShoppingItem? dup;
  bool searchingList = false, sortOpen = false;
  String sortBy = 'Oldest at the top', listFilter = 'Everything';
  String shopFilter = '';
  final listSearch = TextEditingController();
  ShoppingItem? deleting;
  final photoTried = <String>{};
  final finding = <String>{};
  List<String> related = [];
  String lastAdded = '';
  final limitName = TextEditingController();
  final suggested = <String, String?>{};
  final picker = ImagePicker();
  int quantity = 2, maximum = 2;
  bool block = false, warning = false, listening = false;
  String? voiceError, notice;
  @override
  void initState() {
    super.initState();
    if (screen == 'warning') {
      screen = 'list';
      warning = true;
      quantity = 10;
    }
    model.addListener(changed);
    if (!model.ready) model.load();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(changed);
    if (widget.model == null) model.dispose();
    search.dispose();
    pastSearch.dispose();
    limitName.dispose();
    listSearch.dispose();
    addName.dispose();
    editName.dispose();
    super.dispose();
  }

  void go(String next) {
    setState(() {
      if (next != 'add') detailed = false;
      screen = next;
      notice = null;
    });
  }

  void details(String name, [ShoppingItem? item]) {
    setState(() {
      selected = name;
      editing = item;
      editName.text = item?.name ?? name;
      editCategory = item?.category;
      assignTo = item == null ? '' : model.assigneeOf(item.id);
      storeSel = item == null ? '' : model.storeOf(item.id);
      photo = item == null ? null : model.photos[item.id];
      userPhoto = photo != null;
      quantity = item?.quantity ?? (name == 'Fresh Whole Milk' ? 2 : 1);
      screen = 'details';
      notice = null;
      pendingDetails = false;
    });
    if (photo == null) {
      final cached = suggested[name];
      if (cached != null) {
        setState(() => photo = cached);
      } else {
        suggest(name);
      }
    }
  }

  // Finds a photo for the name in the background and stores it.
  Future<void> suggest(String name, {bool force = false}) async {
    if (!force && suggested.containsKey(name)) return;
    suggested[name] = null;
    finding.add(name);
    final found = await findPhoto(name);
    finding.remove(name);
    if (!mounted) return;
    if (found != null) suggested[name] = found;
    setState(() {
      if (found != null &&
          screen == 'details' &&
          selected == name &&
          !userPhoto) {
        photo = found;
      }
    });
  }

  Future<void> useSuggested() async {
    final wasUser = userPhoto;
    userPhoto = false;
    final cached = suggested[selected];
    if (wasUser && cached != null) {
      setState(() => photo = cached);
      return;
    }
    final key = selected.toLowerCase().trim();
    _tries[key] = (_tries[key] ?? 0) + (wasUser ? 0 : 1);
    setState(() => photo = null);
    await suggest(selected, force: true);
    if (mounted && suggested[selected] == null) {
      setState(
        () => notice = 'We could not find a picture. You can take your own photo.',
      );
    }
  }

  // Opens the Set safety limit screen for an item with an existing rule.
  void editLimit(String name) {
    setState(() {
      selected = name;
      newLimit = false;
      limitName.text = name;
      maximum = model.rules[name]?.maximum ?? 2;
      block = model.rules[name]?.block ?? false;
      notice = null;
      screen = 'safety';
    });
  }

  // Opens the Set safety limit screen for a new rule.
  void addLimit() {
    setState(() {
      selected = '';
      newLimit = true;
      limitName.clear();
      maximum = 2;
      block = false;
      notice = null;
      screen = 'safety';
    });
  }

  void saveLimit() {
    final name = cleanName(limitName.text);
    if (name.isEmpty) {
      setState(() => notice = 'Please enter a name for this rule.');
      return;
    }
    final renamed = !newLimit && name != selected;
    if ((newLimit || renamed) && model.rules.containsKey(name)) {
      setState(() => notice = 'There is already a safety limit for $name.');
      return;
    }
    // Renaming moves the rule to the new name.
    if (renamed) model.rules.remove(selected);
    model.setRule(name, SafetyRule(maximum, block: block));
    selected = name;
    go('limits');
  }

  // Opens the Add item screen.
  void openAdd() {
    setState(() {
      addName.clear();
      detailed = false;
      photo = null;
      userPhoto = false;
      addCategory = null;
      addUnit = 'items';
      addQty = 1;
      addFav = false;
      assignTo = '';
      storeSel = '';
      voiceError = null;
      notice = null;
      screen = 'add';
    });
  }

  // Adds the typed item.
  void submitAdd() {
    final name = cleanName(addName.text);
    if (name.isEmpty) {
      setState(() => notice = 'Please type what you need.');
      return;
    }
    editing = null;
    selected = name;
    quantity = detailed ? addQty : 1;
    pendingDetails = detailed;
    if (!detailed) {
      assignTo = '';
      storeSel = '';
    }
    detailed = false;
    if (!userPhoto) photo = suggested[name];
    add();
  }

  void add({bool confirmed = false, bool skipDup = false}) {
    if (editing != null) {
      final typedName = cleanName(editName.text);
      if (typedName.isEmpty) {
        setState(() => notice = 'Please type a name for this item.');
        return;
      }
      selected = typedName;
      notice = null;
    }
    if (editing == null && !skipDup) {
      final existing = model.existingOnList(selected);
      if (existing != null) {
        dupQty = quantity;
        setState(() => dup = existing);
        return;
      }
    }
    if (model.exceeds(selected, quantity, exceptId: editing?.id) &&
        !confirmed) {
      setState(() {
        warning = true;
        screen = 'list';
      });
      return;
    }
    if (model.put(selected, quantity, edit: editing, confirmed: confirmed)) {
      // Attach the picture to the item (a new item is the last one added).
      final id = editing?.id ?? model.items.last.id;
      if (model.photos[id] != photo) model.setPhoto(id, photo);
      if (model.assigneeOf(id) != assignTo) model.setAssignee(id, assignTo);
      if (model.storeOf(id) != storeSel) model.setStore(id, storeSel);
      if (editing != null &&
          editCategory != null &&
          editCategory != editing!.category) {
        model.setDetails(id, category: editCategory);
      }
      if (pendingDetails) {
        model.setDetails(
          id,
          category: addCategory ?? guessCategory(selected),
          unit: addUnit,
        );
        if (addFav && !model.isFavourite(selected)) {
          model.toggleFavourite(selected);
        }
        pendingDetails = false;
      }
      if (editing == null) model.logHabit(selected);
      // For a new item, offer related items.
      final ideas = editing == null
          ? relatedItems(
              selected,
              model.items.map((i) => i.name),
              skip: model.boughtWeekly,
            )
          : <String>[];
      for (final n in ideas) {
        suggest(n);
      }
      setState(() {
        warning = false;
        lastAdded = selected;
        related = ideas;
        prompt = ideas.isNotEmpty;
        screen = 'list';
      });
    }
  }

  Future<void> choosePhoto(ImageSource source) async {
    try {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 300000) {
        setState(() => notice = 'That photo is too big. Please try a different one.');
        return;
      }
      setState(() {
        photo = base64Encode(bytes);
        userPhoto = true;
        notice = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => notice = 'We could not open the camera. A picture will be shown instead.',
        );
      }
    }
  }

  List<Widget> photoSection() => [
    words('PICTURE', 16, weight: 700, color: muted),
    const SizedBox(height: 18),
    Container(
      padding: const EdgeInsets.all(22),
      decoration: box(radius: 20),
      child: Row(
        children: [
          itemPicture(selected, photo, 88),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(
                  userPhoto
                      ? (editing != null ? 'Current picture' : 'Your photo')
                      : photo != null
                      ? 'Picture found'
                      : finding.contains(selected)
                      ? 'Making a picture…'
                      : 'No picture yet',
                  16,
                  weight: 700,
                ),
                if (photo == null && !userPhoto && photoProblem.isNotEmpty &&
                    !finding.contains(selected)) ...[
                  const SizedBox(height: 4),
                  words(photoProblem, 12, color: const Color(0xffb91c1c)),
                ],
                if (photo != null && !userPhoto) ...[
                  const SizedBox(height: 4),
                  words(
                    'Picture ${photoOrigin[selected.toLowerCase().trim()] ?? 'added for you'}',
                    12,
                    color: muted,
                  ),
                ],
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    photoButton(
                      'Take a photo',
                      Icons.photo_camera,
                      () => choosePhoto(ImageSource.camera),
                    ),
                    photoButton(
                      'Choose a photo',
                      Icons.photo_library,
                      () => choosePhoto(ImageSource.gallery),
                    ),
                    photoButton(
                      photo != null && !userPhoto
                          ? 'Try another picture'
                          : 'Find a picture',
                      Icons.refresh,
                      useSuggested,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ];
  Widget photoButton(String text, IconData icon, VoidCallback onTap) => Tap(
    label: text,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: box(color: pale, radius: 12, border: green),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: green),
          const SizedBox(width: 6),
          words(text, 14, weight: 700, color: green),
        ],
      ),
    ),
  );

  Future<void> voice() async {
    setState(() {
      listening = true;
      voiceError = null;
    });
    try {
      final result = await model.operation('voice', {});
      if (mounted && (screen == 'catalogue' || screen == 'add')) {
        setState(() {
          (screen == 'add' ? addName : search).text = result['text'] as String;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          voiceError = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          listening = false;
        });
      }
    }
  }

  String get source => switch (screen) {
    'catalogue' => 'addContext',
    'details' => '28-111',
    'safety' => '2-348',
    _ => model.items.isEmpty ? '2-126' : '2-63',
  };
  @override
  Widget build(BuildContext context) {
    // First launch: account setup (once).
    if (model.ready && !model.signedIn) return AccountSetup(model: model);
    return mainScaffold(context);
  }

  Widget mainScaffold(BuildContext context) => Scaffold(
    backgroundColor: ink,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: ColoredBox(
            color: paper,
            child: Stack(
              children: [
                Opacity(
                  opacity: warning || prompt || deleting != null || dup != null ? .55 : 1,
                  child: AbsorbPointer(
                    absorbing: warning || prompt || deleting != null || dup != null,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        header(),
                        if (model.error != null || notice != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Semantics(
                              liveRegion: true,
                              child: Column(
                                children: [
                                  words(
                                    model.error ?? notice!,
                                    14,
                                    color: const Color(0xffb91c1c),
                                  ),
                                  if (model.error != null)
                                    TextButton(
                                      onPressed: () {
                                        if (model.ready) {
                                          model.save();
                                        } else {
                                          model.load();
                                        }
                                      },
                                      child: const Text('Retry'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: !model.ready
                              ? Center(
                                  child: model.error == null
                                      ? const CircularProgressIndicator()
                                      : const SizedBox(),
                                )
                              : switch (screen) {
                                  'home' => homeBody(),
                                  'add' => addBody(),
                                  'past' => pastBody(),
                                  'lists' => listsBody(),
                                  'shop' => shopBody(),
                                  'catalogue' => catalogueBody(),
                                  'details' => detailBody(),
                                  'safety' => safetyBody(),
                                  'limits' => limitsBody(),
                                  'settings' => SettingsList(
                                    model: model,
                                    onSafety: () => go('limits'),
                                    onOpen: (title) => setState(() {
                                      settingsPage = title;
                                      screen = 'page';
                                    }),
                                  ),
                                    'page' => switch (settingsPage) {
                                        'My details' =>
                                          AccountDetails(model: model, onDone: () => go('settings')),
                                        'Household' => HouseholdSettings(model: model),
                                        'Shops' => ShopSettings(model: model),
                                        'Display' => DisplaySettings(model: model),  
                                        _ => SettingsComingSoon(title: settingsPage),

                                      },
                                  _ => listBody(),
                                },
                        ),
                        if (model.ready && screen == 'list') listFooter(),
                        if (model.ready && screen == 'details') detailFooter(),
                        if (model.ready && screen == 'safety') safetyFooter(),
                        if (model.ready && screen == 'limits') limitsFooter(),
                      ],
                    ),
                  ),
                ),
                if (warning) warningCard(),
                if (prompt && related.isNotEmpty) suggestCard(),
                if (deleting != null) deleteCard(),
                if (dup != null) dupCard(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget statusBar() => ExcludeSemantics(
    child: SizedBox(
      height: 57,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            words('9:41', 15, weight: 600),
            Row(
              children: [
                asset(source, 'IosSignal', 20),
                const SizedBox(width: 6),
                asset(source, 'IosWifiSignal', 20),
                const SizedBox(width: 6),
                asset(source, 'IosBatteryFull', 28, 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget header() => (screen == 'safety' || screen == 'limits')
      ? limitsHeader()
      : Container(
    padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
    decoration: const FrameDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (screen == 'safety') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: box(color: yellow, radius: 8, border: null),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                asset(source, 'Lock', 16),
                const SizedBox(width: 6),
                words('CAREGIVER MODE', 14, weight: 700, color: amber),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (screen != 'list' && screen != 'home') ...[
              Tap(
                label: 'Go back',
                onTap: () {
                  if (screen == 'catalogue' || screen == 'add') {
                    model.operation('cancelVoice', {});
                  }
                  go(backTarget());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: box(radius: 20, color: Colors.white),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 18, color: ink),
                      const SizedBox(width: 6),
                      words('Go Back', 16, weight: 700),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 17),
            ],
            if (screen == 'list') ...[
              headerButton(
                Icons.arrow_back,
                'Back to my lists',
                false,
                () => go('lists'),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: words(
                switch (screen) {
                  'home' => 'Shopping List',
                  'add' => 'Add item',
                  'past' => 'Past items',
                  'lists' => 'My lists',
                  'shop' => 'Shopping',
                  'catalogue' => 'Favourites, Recent & Suggestions',
                  'details' => 'Item Details',
                  'safety' => 'Set Safety Limit',
                  'settings' => 'Settings',
                  'page' => settingsPage,
                  _ => model.currentList,
                },
                screen == 'list' ? 24 : 22,
                weight: 800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget goBackButton() => Tap(
    onTap: () => go(screen == 'safety' ? 'limits' : 'settings'),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: box(radius: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back, size: 18, color: ink),
          const SizedBox(width: 6),
          words('Go Back', 16, weight: 700),
        ],
      ),
    ),
  );
  Widget limitsHeader() => Container(
    padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
    decoration: const FrameDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        words(
          screen == 'safety' ? 'Set safety limit' : 'Safety limits',
          20,
          weight: 800,
        ),
        Align(alignment: Alignment.centerLeft, child: goBackButton()),
      ],
    ),
  );
  Widget action(
    String text,
    VoidCallback onTap, {
    Color color = green,
    Color textColor = Colors.white,
    String? icon,
    String? assetSource,
    bool outline = false,
    double height = 56,
    double radius = 28,
    double size = 18,
  }) => Tap(
    onTap: onTap,
    child: Container(
      height: height,
      width: double.infinity,
      decoration: box(
        color: color,
        radius: radius,
        border: outline ? line : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            asset(assetSource ?? source, icon, 20),
            const SizedBox(width: 11),
          ],
          words(text, size, weight: 800, color: textColor),
        ],
      ),
    ),
  );
  Widget listFooter() => Container(
    padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
    decoration: const FrameDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: action(
      model.items.isEmpty ? 'Add First Item' : 'Add New Item',
      openAdd,
      icon: 'Plus',
    ),
  );
  String backTarget() => switch (screen) {
    'catalogue' || 'past' || 'settings' || 'lists' => 'home',
    'page' => 'settings',
    _ => 'list',
  };

  bool get listFiltered =>
      listFilter != 'Everything' ||
      shopFilter.isNotEmpty ||
      listSearch.text.trim().isNotEmpty;
  bool get listReordered => sortBy != 'Oldest at the top';

  // Resets all filters.
  void showEverything() => setState(() {
    listFilter = 'Everything';
    shopFilter = '';
    sortBy = 'Oldest at the top';
    listSearch.clear();
    searchingList = false;
    sortOpen = false;
  });

  Widget headerButton(
    IconData icon,
    String text,
    bool active,
    VoidCallback onTap,
  ) => Tap(
    label: text,
    onTap: onTap,
    child: Container(
      width: 48,
      height: 48,
      decoration: box(
        radius: 12,
        color: active ? green : Colors.white,
        border: active ? null : line,
      ),
      child: Icon(icon, size: 22, color: active ? Colors.white : ink),
    ),
  );

  // Banner shown whenever the list is filtered or reordered.
  Widget filterBanner(int shownCount) {
    final parts = <String>[
      if (listSearch.text.trim().isNotEmpty)
        'Searching for "${listSearch.text.trim()}"',
      if (listFilter != 'Everything') 'Only: ${listFilter.toLowerCase()}',
      if (shopFilter.isNotEmpty) 'Only items for: $shopFilter',
      if (listReordered) 'Order: ${sortBy.toLowerCase()}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: box(color: yellow, radius: 16, border: amber, thickness: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: amber),
              const SizedBox(width: 11),
              Expanded(
                child: words(
                  listFiltered
                      ? 'You are not seeing everything'
                      : 'Your list is in a different order',
                  16,
                  weight: 800,
                  color: amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (listFiltered)
            words(
              'Showing $shownCount of ${model.items.length} items',
              15,
              weight: 600,
            ),
          for (final p in parts) words(p, 15),
          const SizedBox(height: 18),
          action(
            listFiltered ? 'Show everything' : 'Put back in order',
            showEverything,
            color: amber,
            height: 65,
            radius: 25,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget pill(String text, bool on, VoidCallback onTap) => Tap(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: box(
        color: on ? green : Colors.white,
        radius: 12,
        border: on ? null : line,
      ),
      child: words(text, 14, weight: 700, color: on ? Colors.white : muted),
    ),
  );

  Widget listSearchBar() => Container(
    height: 70,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: box(),
    child: Row(
      children: [
        const Icon(Icons.search, color: muted),
        const SizedBox(width: 17),
        Expanded(
          child: TextField(
            controller: listSearch,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            autocorrect: true,
            enableSuggestions: true,
            style: type(18, 500),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Search your list',
              hintStyle: type(18, 500, label),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (listSearch.text.isNotEmpty)
          Tap(
            label: 'Clear search',
            onTap: () => setState(listSearch.clear),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, color: muted),
            ),
          ),
      ],
    ),
  );

  Widget sortPanel() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: box(radius: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        words('ORDER', 11, weight: 700, color: label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in [
              'Oldest at the top',
              'Newest at the top',
              'A to Z',
              'Z to A',
              'By shop section',
            ])
              pill(s, sortBy == s, () => setState(() => sortBy = s)),
          ],
        ),
        const SizedBox(height: 16),
        words('SHOW ME', 11, weight: 700, color: label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in ['Everything', 'Things to buy', 'Things bought'])
              pill(f, listFilter == f, () => setState(() => listFilter = f)),
          ],
        ),
        const SizedBox(height: 16),
        words('SHOP', 11, weight: 700, color: label),
        const SizedBox(height: 8),
        if (model.stores.isEmpty)
          words(
            'Choose a shop when you add or edit an item, then you can filter by it here.',
            14,
            weight: 500,
            color: muted,
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              pill('All shops', shopFilter.isEmpty,
                  () => setState(() => shopFilter = '')),
              for (final st in model.stores)
                pill(st, shopFilter == st, () => setState(() => shopFilter = st)),
            ],
          ),
        const SizedBox(height: 16),
        action(
          'Done',
          () => setState(() => sortOpen = false),
          height: 50,
          radius: 20,
          size: 16,
        ),
      ],
    ),
  );

  // Finds a photo for list items that have none and saves it (once per item per visit).
  void ensurePhotos() {
    for (final item in model.items) {
      if (model.photos[item.id] != null ||
          !photoTried.add('${item.id}:${item.name}')) {
        continue;
      }
      final id = item.id, name = item.name;
      () async {
        final found = suggested[name] ?? await findPhoto(name);
        if (!mounted || found == null) return;
        suggested[name] = found;
        if (model.items.any((i) => i.id == id) && model.photos[id] == null) {
          model.setPhoto(id, found);
        }
      }();
    }
  }

  Widget deleteCard() {
    final item = deleting!;
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          Align(
            alignment: const Alignment(0, -.081),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(20),
                decoration: box(radius: 24).copyWith(
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1a000000),
                      offset: Offset(0, 12),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    words('Remove ${item.name}?', 16, weight: 700),
                    const SizedBox(height: 6),
                    words(
                      'It will be taken off your shopping list.',
                      14,
                      color: muted,
                    ),
                    const SizedBox(height: 24),
                    action(
                      'Yes, remove',
                      () {
                        model.removeItem(item.id);
                        setState(() {
                          deleting = null;
                          if (screen == 'details') screen = 'list';
                        });
                      },
                      color: const Color(0xffdc2626),
                      height: 68,
                      radius: 26,
                      size: 16,
                    ),
                    const SizedBox(height: 15),
                    action(
                      'Keep it',
                      () => setState(() => deleting = null),
                      color: Colors.white,
                      textColor: green,
                      outline: true,
                      height: 68,
                      radius: 26,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget listInfoCard() => Container(
    margin: const EdgeInsets.only(bottom: 28),
    padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
    decoration: box(radius: 20, color: pale, border: null),
    child: Row(
      children: [
        Expanded(
          child: words(
            model.listAssignee(model.currentList).isEmpty
                ? 'Anyone can shop from this list'
                : 'This list is for ${model.listAssignee(model.currentList)}',
            18,
            weight: 700,
          ),
        ),
        Tap(
          label: 'Edit this list',
          onTap: () => manageList(model.currentList),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: words('Edit', 18, weight: 800, color: green),
          ),
        ),
      ],
    ),
  );

  Widget listBody() {
    if (model.items.isEmpty) {
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
          child: listInfoCard(),
        ),
        Expanded(child: _emptyList()),
      ]);
    }
    return _fullList();
  }

  Widget _emptyList() {
    {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              words(
                'Nothing here yet',
                22,
                weight: 800,
                align: TextAlign.center,
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      );
    }
  }

  Widget _fullList() {
    ensurePhotos();
    final q = listSearch.text.trim().toLowerCase();
    int order(ShoppingItem x, ShoppingItem y) => switch (sortBy) {
      'Newest at the top' => y.id.compareTo(x.id),
      'A to Z' => x.name.toLowerCase().compareTo(y.name.toLowerCase()),
      'Z to A' => y.name.toLowerCase().compareTo(x.name.toLowerCase()),
      'By shop section' =>
        x.category == y.category
            ? x.name.toLowerCase().compareTo(y.name.toLowerCase())
            : x.category.compareTo(y.category),
      _ => x.id.compareTo(y.id),
    };
    final shown =
        model.items
            .where((i) => q.isEmpty || i.name.toLowerCase().contains(q))
            .where(
              (i) => shopFilter.isEmpty || model.storeOf(i.id) == shopFilter,
            )
            .toList()
          ..sort(order);
    final buying = listFilter == 'Things bought'
        ? <ShoppingItem>[]
        : shown.where((i) => !i.purchased).toList();
    final purchased = listFilter == 'Things to buy'
        ? <ShoppingItem>[]
        : shown.where((i) => i.purchased).toList();
    final sections = <String, List<ShoppingItem>>{};
    for (final i in buying) {
      sections.putIfAbsent(i.category, () => []).add(i);
    }
    const order0 = ['Produce', 'Dairy & Eggs', 'Bakery', 'Meat', 'Pantry', 'Other'];
    final names = sections.keys.toList()
      ..sort((x, y) {
        int rank(String n) {
          final r = order0.indexOf(n);
          return r < 0 ? order0.length : r;
        }
        return rank(x).compareTo(rank(y));
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            topPill(
              Icons.search,
              'Search',
              searchingList || listSearch.text.trim().isNotEmpty,
              () => setState(() {
                searchingList = !searchingList;
                if (!searchingList) listSearch.clear();
              }),
            ),
            topPill(
              Icons.tune,
              'Sort and filter',
              sortOpen ||
                  listFilter != 'Everything' ||
                  shopFilter.isNotEmpty ||
                  listReordered,
              () => setState(() => sortOpen = !sortOpen),
            ),
            if (model.items.any((i) => i.purchased))
              topPill(Icons.delete_outline, 'Clear Purchase History', false,
                  clearPurchased),
          ],
        ),
        const SizedBox(height: 20),

        if (listFiltered || listReordered)
          filterBanner(buying.length + purchased.length),
        if (searchingList) listSearchBar(),
        if (sortOpen) sortPanel(),
        if (buying.isEmpty && purchased.isEmpty)
          words(
            q.isEmpty
                ? 'Nothing to show here.'
                : 'No items match "${listSearch.text.trim()}".',
            16,
            color: muted,
          ),
        for (final n in names) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: sectionColour(n),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              words('${sectionName(n)} (${sections[n]!.length})', 21,
                  weight: 800),
            ],
          ),
          const SizedBox(height: 14),
          for (var k = 0; k < sections[n]!.length; k += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: itemTile(sections[n]![k])),
                const SizedBox(width: 14),
                Expanded(
                  child: k + 1 < sections[n]!.length
                      ? itemTile(sections[n]![k + 1])
                      : const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 14),
        ],
        if (purchased.isNotEmpty) ...[
          const SizedBox(height: 8),
          listDivider('PURCHASED (${purchased.length})', muted),
          const SizedBox(height: 14),
          for (var k = 0; k < purchased.length; k += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: itemTile(purchased[k])),
                const SizedBox(width: 14),
                Expanded(
                  child: k + 1 < purchased.length
                      ? itemTile(purchased[k + 1])
                      : const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }

  // Confirms, then removes one item from the list.
  Future<void> removeFromList(ShoppingItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => model.removeItem(item.id));
  }

  // Confirms, then removes all purchased items.
  Future<void> clearPurchased() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear Purchase History?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => model.clearPurchased());
  }

  // Section heading with a line, e.g. PURCHASED.
  Widget listDivider(String text, Color colour) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        words(text, 15, weight: 800, color: colour),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 2, color: colour.withValues(alpha:.5))),
      ],
    ),
  );

  // Display names for shop sections.
  String sectionName(String category) => switch (category) {
    'Produce' => 'Fruit and veg',
    'Dairy & Eggs' => 'Milk and eggs',
    _ => category,
  };

  Color sectionColour(String category) => switch (category) {
    'Produce' => const Color(0xff5d9a62),
    'Dairy & Eggs' => const Color(0xff4f8fa8),
    'Bakery' => const Color(0xffc79a4a),
    'Meat' => const Color(0xffb8665d),
    'Pantry' => const Color(0xff8c7455),
    _ => const Color(0xff7f8f80),
  };

  // Top buttons on the list: Search, Sort and filter.
  Widget topPill(IconData icon, String text, bool active, VoidCallback onTap) =>
      Tap(
        label: text,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: box(
            radius: 22,
            color: active ? green : Colors.white,
            border: active ? null : line,
            thickness: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : ink),
              const SizedBox(width: 8),
              words(
                text,
                16,
                weight: 700,
                color: active ? Colors.white : ink,
              ),
            ],
          ),
        ),
      );

  // Not shown at the moment. Kept so it can be restored.
  Widget startShoppingButton() => Tap(
    label: 'Start shopping, one item at a time',
    onTap: startShopping,
    child: Container(
      height: 64,
      alignment: Alignment.center,
      decoration: box(color: Colors.white, radius: 32, border: green, thickness: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_basket_outlined, color: green, size: 26),
          const SizedBox(width: 12),
          words('Start shopping', 20, weight: 800, color: green),
        ],
      ),
    ),
  );

  // Item picture tile: tick bottom right, amount top left.
  Widget itemTile(ShoppingItem item) {
    final tint = sectionColour(item.category).withValues(alpha:.14);
    return Tap(
      label: 'Edit ${item.name}',
      onTap: () => details(item.name, item),
      child: Container(
        decoration: box(
          radius: 26,
          color: item.purchased ? pale : Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  color: tint,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: item.purchased ? .55 : 1,
                    child: itemPicture(item.name, model.photos[item.id], 96),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: box(radius: 14, border: null),
                    child: words(
                      'x${item.quantity}${item.unit.isEmpty || item.unit == 'items' ? '' : ' ${item.unit}'}',
                      16,
                      weight: 800,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Tap(
                    label: 'Remove ${item.name} from my list',
                    onTap: () => removeFromList(item),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(Icons.close,
                          size: 22, color: Color(0xffb8665d)),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Tap(
                    label:
                        'Mark ${item.name} ${item.purchased ? 'to buy' : 'got'}',
                    checked: item.purchased,
                    onTap: () {
                      final wasToBuy = !item.purchased;
                      if (model.toggle(item)) {
                        if (wasToBuy) model.logHabit(item.name);
                      } else {
                        setState(
                          () => notice =
                              'The quantity limit prevents returning this item to your list.',
                        );
                      }
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.purchased ? green : Colors.white,
                        border: Border.all(color: green, width: 3),
                      ),
                      child: item.purchased
                          ? const Icon(Icons.check, color: Colors.white, size: 30)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words(
                    item.name,
                    19,
                    weight: 800,
                    color: item.purchased ? muted : ink,
                    strike: item.purchased,
                  ),
                  if (model.storeOf(item.id).isNotEmpty ||
                      model.assigneeOf(item.id).isNotEmpty)
                    words(
                      [
                        if (model.assigneeOf(item.id).isNotEmpty)
                          'For ${model.assigneeOf(item.id)}',
                        if (model.storeOf(item.id).isNotEmpty)
                          'At ${model.storeOf(item.id)}',
                      ].join(' · '),
                      14,
                      weight: 600,
                      color: muted,
                    ),
                  if (WireframeModel.niceDate(model.addedOn[item.id]).isNotEmpty)
                    words(
                      item.purchased &&
                              WireframeModel.niceDate(model.gotOn[item.id])
                                  .isNotEmpty
                          ? 'Added ${WireframeModel.niceDate(model.addedOn[item.id])} · Got ${WireframeModel.niceDate(model.gotOn[item.id])}'
                          : 'Added ${WireframeModel.niceDate(model.addedOn[item.id])}',
                      13,
                      weight: 600,
                      color: muted,
                    ),
                  if (!item.purchased && model.ruleFor(item.name) != null) ...[
                    const SizedBox(height: 6),
                    limitBadge(model.ruleFor(item.name)!.maximum),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shopping mode: one item at a time.
  void startShopping() {
    final items = model.items.where((i) => !i.purchased).toList();
    if (items.isEmpty) return;
    const order0 = ['Produce', 'Dairy & Eggs', 'Bakery', 'Meat', 'Pantry', 'Other'];
    int rank(ShoppingItem i) {
      final r = order0.indexOf(i.category);
      return r < 0 ? order0.length : r;
    }
    items.sort((x, y) {
      final c = rank(x).compareTo(rank(y));
      return c != 0 ? c : x.id.compareTo(y.id);
    });
    setState(() {
      shopQueue = items.map((i) => i.id).toList();
      shopIndex = 0;
      shopGot = 0;
      screen = 'shop';
    });
  }

  Widget shopBody() {
    final total = shopQueue.length;
    if (shopIndex >= total) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: pale,
              ),
              child: const Icon(Icons.check, color: green, size: 80),
            ),
            const SizedBox(height: 28),
            words('All done!', 34, weight: 800, align: TextAlign.center),
            const SizedBox(height: 10),
            words(
              shopGot == total
                  ? 'You got everything.'
                  : 'You got $shopGot of $total things.',
              20,
              weight: 600,
              color: muted,
              align: TextAlign.center,
            ),
            const Spacer(),
            action('Back to my list', () => go('list'),
                height: 72, radius: 36, size: 22),
          ],
        ),
      );
    }
    final item = model.items.where((i) => i.id == shopQueue[shopIndex]).firstOrNull;
    if (item == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => shopIndex++);
      });
      return const SizedBox();
    }
    final tint = sectionColour(item.category).withValues(alpha:.14);
    void next() => setState(() => shopIndex++);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var k = 0; k < total && total <= 12; k++) ...[
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: k < shopIndex ? green : line,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      if (k < total - 1) const SizedBox(width: 6),
                    ],
                    if (total > 12)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: shopIndex / total,
                            minHeight: 10,
                            color: green,
                            backgroundColor: line,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              words('${shopIndex + 1} of $total', 19, weight: 800, color: muted),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(36),
              ),
              child: Stack(
                children: [
                  Center(child: itemPicture(item.name, model.photos[item.id], 150)),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: box(radius: 20, border: null),
                      child: words(item.category, 16,
                          weight: 800, color: sectionColour(item.category)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          words(item.name, 38, weight: 800, align: TextAlign.center),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: box(color: pale, radius: 22, border: null),
              child: words(
                'Get ${item.quantity}${item.unit.isEmpty || item.unit == 'items' ? '' : ' ${item.unit}'}',
                22,
                weight: 800,
                color: green,
              ),
            ),
          ),
          const SizedBox(height: 18),
          action(
            'Got it',
            () {
              if (model.toggle(item)) {
                model.logHabit(item.name);
                shopGot++;
              }
              next();
            },
            icon: 'Check',
            height: 76,
            radius: 38,
            size: 24,
          ),
          const SizedBox(height: 12),
          action(
            'Not now',
            next,
            color: Colors.white,
            textColor: muted,
            outline: true,
            height: 58,
            radius: 29,
            size: 19,
          ),
        ],
      ),
    );
  }

  Widget limitBadge(int limit, {bool small = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: box(color: yellow, radius: 6, border: null),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        asset(small ? 'addContext' : '2-63', 'Lock', small ? 12 : 14),
        const SizedBox(width: 4),
        words('Limit: $limit', small ? 11 : 13, weight: 700, color: amber),
      ],
    ),
  );
  Widget itemRow(ShoppingItem item) => Container(
    padding: const EdgeInsets.all(14),
    decoration: box(),
    child: Row(
      children: [
        Tap(
          label: 'Mark ${item.name} ${item.purchased ? 'to buy' : 'purchased'}',
          checked: item.purchased,
          onTap: () {
            final wasToBuy = !item.purchased;
            if (model.toggle(item)) {
              if (wasToBuy) model.logHabit(item.name);
            } else {
              setState(
                () => notice = 'The quantity limit prevents returning this item to your list.',
              );
            }
          },
          child: Container(
            width: 62,
            height: 62,
            decoration: box(
              color: item.purchased ? green : pale,
              radius: 12,
              border: green,
              thickness: item.purchased ? 0 : 3,
            ),
            child: item.purchased
                ? Center(child: asset('2-63', 'Check', 24))
                : null,
          ),
        ),
        const SizedBox(width: 14),
        itemPicture(item.name, model.photos[item.id], 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              words(
                item.name,
                20,
                weight: 700,
                color: item.purchased ? muted : ink,
                strike: item.purchased,
              ),
              const SizedBox(height: 2),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  words(
                    'Qty: ${item.quantity}${item.unit.isEmpty || item.unit == 'items' ? '' : ' ${item.unit}'}',
                    16,
                    weight: 600,
                    color: muted,
                  ),
                  if (model.storeOf(item.id).isNotEmpty)
                    words(
                      'At ${model.storeOf(item.id)}',
                      16,
                      weight: 600,
                      color: muted,
                    ),
                  if (model.assigneeOf(item.id).isNotEmpty)
                    words(
                      'For ${model.assigneeOf(item.id)}',
                      16,
                      weight: 700,
                      color: green,
                    ),
                  if (!item.purchased && model.ruleFor(item.name) != null)
                    limitBadge(model.ruleFor(item.name)!.maximum),
                ],
              ),
            ],
          ),
        ),
        Tap(
          label: 'Edit ${item.name}',
          onTap: () => details(item.name, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: words('Edit', 16, weight: 700, color: green),
          ),
        ),
        Tap(
          label: 'Remove ${item.name}',
          onTap: () => setState(() => deleting = item),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.delete_outline,
              size: 26,
              color: Color(0xffdc2626),
            ),
          ),
        ),
      ],
    ),
  );
  Widget catalogueBody() {
    final q0 = search.text.trim().toLowerCase();
    final special = category == 'Favourites' || category == 'Recent';
    bool matches(String n) =>
        (category == 'All' || special || guessCategory(n) == category) &&
        n.toLowerCase().contains(q0);
    final favs = category == 'Recent'
        ? <String>[]
        : model.favourites.where(matches).toList();
    final recent = category == 'Favourites'
        ? <String>[]
        : model.history
              .where(
                (n) =>
                    (category == 'Recent' || !model.isFavourite(n)) &&
                    matches(n),
              )
              .take(category == 'Recent' ? 30 : 5)
              .toList();
    final taken = {...favs, ...recent}.map((n) => n.toLowerCase()).toSet();
    final browsing = category != 'All' || q0.isNotEmpty;
    final ideas = (!browsing || special)
        ? <String>[]
        : <String>{...groceries.keys, ...commonItems}
              .where((n) => matches(n) && !taken.contains(n.toLowerCase()))
              .toList();
    final typed = cleanName(search.text);
    final hints = suggestionsFor(typed, [
      ...groceries.keys,
      ...commonItems,
      ...model.items.map((i) => i.name),
    ]);
    final showCustom =
        typed.isNotEmpty &&
        ![...groceries.keys, ...commonItems].any(
          (k) => k.toLowerCase() == typed.toLowerCase(),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
      children: [
        Container(
          height: 70,
          decoration: box(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // The search artwork is 100x100, clipped into a 20x20 slot.
              SizedBox(
                width: 20,
                height: 20,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: 100,
                    maxWidth: 100,
                    minHeight: 100,
                    maxHeight: 100,
                    child: asset('addContext', 'Search', 100),
                  ),
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() => catShown = 6),
                  autocorrect: true,
                  enableSuggestions: true,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  style: type(18, 500),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Type any item (e.g. Milk)',
                    hintStyle: type(18, 500, label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Tap(
                label: 'Voice search',
                onTap: listening ? null : voice,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(child: asset('addContext', 'Mic', 16)),
                ),
              ),
            ],
          ),
        ),
        if (voiceError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: words(voiceError!, 14, color: muted),
            ),
          ),
        if (listening) words('Listening…', 14, color: muted),
        const SizedBox(height: 24),
        if (hints.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in hints)
                Tap(
                  label: 'Use $h',
                  onTap: () => setState(() {
                    search.text = h;
                    search.selection = TextSelection.collapsed(
                      offset: h.length,
                    );
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: box(color: pale, radius: 12, border: green),
                    child: words(h, 15, weight: 700, color: green),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (showCustom) ...[customRow(typed), const SizedBox(height: 24)],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in [
              'All',
              'Favourites',
              'Recent',
              'Produce',
              'Dairy & Eggs',
              'Bakery',
              'Meat',
              'Pantry',
              'Other',
            ])
              Tap(
                onTap: () => setState(() {
                  category = c;
                  catShown = 6;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: box(
                    color: category == c ? green : Colors.white,
                    radius: 12,
                    border: category == c ? null : line,
                  ),
                  child: words(
                    c,
                    14,
                    weight: 700,
                    color: category == c ? Colors.white : muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (!browsing) ...habitSection(),
        if (favs.isNotEmpty) ...[
          words('FAVOURITES', 12, weight: 700, color: label),
          const SizedBox(height: 18),
          addFavouritesButton(),
          const SizedBox(height: 22),
          ...groupedRows(favs),
          const SizedBox(height: 12),
        ],
        if (recent.isNotEmpty) ...[
          words('RECENT', 12, weight: 700, color: label),
          const SizedBox(height: 18),
          ...groupedRows(recent),
          const SizedBox(height: 12),
        ],
        if (ideas.isNotEmpty) ...[
          words(
            category == 'All' ? 'ITEMS' : category.toUpperCase(),
            12,
            weight: 700,
            color: label,
          ),
          const SizedBox(height: 18),
          ...groupedRows(ideas.take(catShown).toList()),
          if (ideas.length > catShown) ...[
            const SizedBox(height: 28),
            action(
              'Show more',
              () => setState(() => catShown += 6),
              color: Colors.white,
              textColor: green,
              outline: true,
              height: 64,
              radius: 32,
              size: 18,
            ),
          ],
        ],
        if (favs.isEmpty && recent.isEmpty && (!browsing || special))
          words(
            'Nothing here yet',
            16,
            color: muted,
          ),
        if (favs.isEmpty && recent.isEmpty && ideas.isEmpty &&
            !showCustom && typed.isNotEmpty)
          words('No matching items', 16, color: muted),
      ],
    );
  }

  // Item rows with a divider after every 3 items.
  List<Widget> groupedRows(List<String> names) {
    final out = <Widget>[];
    for (var i = 0; i < names.length; i++) {
      out.add(nameRow(names[i]));
      final last = i == names.length - 1;
      if (!last && (i + 1) % 3 == 0) {
        out.add(const SizedBox(height: 28));
        out.add(const Divider(color: line, thickness: 2, height: 2));
        out.add(const SizedBox(height: 28));
      } else if (!last) {
        out.add(const SizedBox(height: 22));
      }
    }
    return out;
  }

  Widget favStar(String name) => Tap(
    label: model.isFavourite(name)
        ? 'Remove $name from favourites'
        : 'Make $name a favourite',
    onTap: () => model.toggleFavourite(name),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        model.isFavourite(name) ? Icons.star : Icons.star_border,
        size: 28,
        color: model.isFavourite(name) ? amber : muted,
      ),
    ),
  );

  // Item name row with picture, favourite star and + button.
  Widget nameRow(String name) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    decoration: box(),
    child: Row(
      children: [
        itemPicture(name, photoFor(name), 52),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              words(name, 18, weight: 700),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  words(guessCategory(name), 14, weight: 600, color: muted),
                  if (model.ruleFor(name) != null)
                    limitBadge(model.ruleFor(name)!.maximum, small: true),
                ],
              ),
            ],
          ),
        ),
        favStar(name),
        Tap(
          label: 'Add $name',
          onTap: () => details(name),
          child: Container(
            width: 62,
            height: 62,
            decoration: box(color: pale, radius: 8, border: null),
            child: const Center(child: Icon(Icons.add, color: green)),
          ),
        ),
      ],
    ),
  );

  Widget homeCard(IconData icon, String title, String sub, VoidCallback onTap) =>
      Tap(
        label: title,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: box(radius: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: box(color: pale, radius: 12, border: null),
                child: Icon(icon, color: green, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    words(title, 19, weight: 700),
                    if (sub.isNotEmpty) words(sub, 13, color: muted),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      );

  Widget homeBody() {
    final toBuy = model.items.where((i) => !i.purchased).length;
    final gotAll = model.items.length - toBuy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
      children: [
        // Opens the most recently used list.
        Tap(
          label: 'Open ${model.currentList}',
          onTap: () => go('list'),
          child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [greenMid, green, greenDeep],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: words(model.currentList, 26,
                        weight: 800, color: Colors.white),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.white, size: 32),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: model.items.isEmpty ? 0 : gotAll / model.items.length,
                  minHeight: 12,
                  color: Colors.white,
                  backgroundColor: const Color(0x55ffffff),
                ),
              ),
              const SizedBox(height: 14),
              words('Tap to open your current list', 17,
                  weight: 700, color: Colors.white),
            ],
          ),
        ),
        ),
        const SizedBox(height: 18),
        homeCard(
          Icons.list_alt,
          'My Lists',
          '',
          () => go('lists'),
        ),
        // PAST ITEMS is switched off. To restore it, remove the leading //
        // from each line below (the screen is still in the code as pastBody()).
        // const SizedBox(height: 14),
        // homeCard(
        // Icons.history,
        // 'Past items',
        // model.history.isEmpty ? '' : '${model.history.length} items',
        // () {
        // pastSearch.clear();
        // pastCategory = 'All';
        // pastShown = 9;
        // go('past');
        // },
        // ),
        const SizedBox(height: 14),
        homeCard(Icons.star_border, 'Favourites, Recent & Suggestions', '', () {
          search.clear();
          category = 'All';
          go('catalogue');
        }),
        const SizedBox(height: 14),
        homeCard(Icons.settings_outlined, 'Settings', '', () => go('settings')),
        const SizedBox(height: 18),
        Center(child: words('App version 56', 12, color: muted)),
      ],
    );
  }

  // Opens a list from the lists screen.
  void openListScreen(String name) {
    model.openList(name);
    setState(() {
      listFilter = 'Everything';
      shopFilter = '';
      sortBy = 'Oldest at the top';
      listSearch.clear();
      searchingList = false;
      sortOpen = false;
      screen = 'list';
    });
  }

  Future<void> newList() async {
    final box0 = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words('Name your new list', 22, weight: 800),
                const SizedBox(height: 6),
                words('For example: Weekend, Chemist, Party', 15,
                    weight: 500, color: muted),
                const SizedBox(height: 18),
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: box(radius: 18, border: green, thickness: 2),
                  child: TextField(
                    controller: box0,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => Navigator.pop(c, v),
                    style: type(20, 700),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Tap(
                  label: 'Make the list',
                  onTap: () => Navigator.pop(c, box0.text),
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: box(color: green, radius: 36, border: null),
                    child: words('Make the list', 20,
                        weight: 800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 14),
                Tap(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(c),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: box(radius: 32, border: line, thickness: 2),
                    child: words('Cancel', 18, weight: 700, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    box0.dispose();
    final name = cleanName(result ?? '');
    if (name.isEmpty) return;
    if (model.listExists(name)) {
      setState(() => notice = 'You already have a list called $name.');
      return;
    }
    if (model.createList(name)) {
      setState(() {
        notice = null;
        listFilter = 'Everything';
        shopFilter = '';
        listSearch.clear();
        searchingList = false;
        sortOpen = false;
        screen = 'list';
      });
    }
  }

  String everyText(double days) {
    if (days < 2) return 'about every day';
    if (days < 4) return 'every few days';
    if (days < 10) return 'about every week';
    if (days < 19) return 'about every 2 weeks';
    if (days < 40) return 'about every month';
    return 'now and then';
  }

  String agoText(double days) {
    final d = days.round();
    if (d <= 0) return 'today';
    if (d == 1) return 'yesterday';
    if (d < 14) return '$d days ago';
    return '${(d / 7).round()} weeks ago';
  }

  // "Time to buy again?" Calculated on the device from purchase habits.
  List<Widget> habitSection() {
    final hints = model.habitHints();
    if (hints.isEmpty) return [];
    return [
      words('TIME TO BUY AGAIN?', 12, weight: 700, color: label),
      const SizedBox(height: 6),
      words('Things you usually buy, based on your past lists', 15,
          weight: 500, color: muted),
      const SizedBox(height: 16),
      for (final h in hints) ...[
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: box(radius: 16, color: pale, border: green),
          child: Row(
            children: [
              itemPicture(h.name, photoFor(h.name), 52),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    words(h.name, 20, weight: 800),
                    const SizedBox(height: 4),
                    words(
                      'You buy this ${everyText(h.everyDays)}. Last time: ${agoText(h.sinceDays)}.',
                      15,
                      weight: 500,
                      color: muted,
                    ),
                    const SizedBox(height: 4),
                    Tap(
                      label: 'Not now for ${h.name}',
                      onTap: () => setState(() => model.snoozeHabit(h.name)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: words('Not now', 15,
                            weight: 700, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
              Tap(
                label: 'Add ${h.name}',
                onTap: () => details(h.name),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: box(color: green, radius: 14, border: null),
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      const SizedBox(height: 14),
    ];
  }

  // Favourite shown as a small picture tile. Tap to add one to the list.
  Widget favTile(String name) => Tap(
    label: 'Add $name to my list',
    onTap: () => quickAdd(name),
    child: Container(
      decoration: box(radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 92,
            width: double.infinity,
            color: pale,
            alignment: Alignment.center,
            child: itemPicture(name, photoFor(name), 54),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
            child: words(
              name,
              16,
              weight: 800,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );

  // Adds a suggested item straight to the list, with no extra screens.
  void quickAdd(String name) {
    setState(() => prompt = false);
    String? message;
    if (model.existingOnList(name) != null) {
      message = '$name is already on your list.';
    } else if (model.exceeds(name, 1)) {
      message = '$name is over a safety limit, so it was not added.';
    } else if (model.put(name, 1)) {
      model.logHabit(name);
      message = 'Added $name to your list.';
    }
    setState(() {
      related = [];
      prompt = false;
      lastAdded = name;
    });
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(message, style: type(16, 700, Colors.white)),
        ),
      );
    }
  }

  // Adds every favourite not already on the current list.
  void addAllFavourites() {
    var added = 0, skipped = 0;
    for (final n in List<String>.from(model.favourites)) {
      if (model.existingOnList(n) != null) continue;
      if (model.exceeds(n, 1)) {
        skipped++;
        continue;
      }
      if (model.put(n, 1)) added++;
    }
    final text = added == 0
        ? 'All your favourites are already on this list.'
        : added == 1
        ? 'Added 1 favourite to ${model.currentList}.'
        : 'Added $added favourites to ${model.currentList}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(
          skipped == 0 ? text : '$text $skipped went over a safety limit.',
          style: type(17, 700, Colors.white),
        ),
      ),
    );
    setState(() {
      notice = null;
      screen = 'list';
    });
  }

  Widget addFavouritesButton() => Tap(
    label: 'Add all my favourites to ${model.currentList}',
    onTap: addAllFavourites,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: box(radius: 18, color: pale, border: green, thickness: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: amber, size: 26),
          const SizedBox(width: 12),
          Flexible(
            child: words(
              'Add all my favourites to my list',
              18,
              weight: 800,
              color: green,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );

  // Shows the shop for an item. Tap to change.
  Widget storeRow(String shop, VoidCallback onTap) => Tap(
    label: 'Which shop. Now: ${shop.isEmpty ? 'any shop' : shop}',
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: box(radius: 18, border: green, thickness: 2),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: green, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: words(shop.isEmpty ? 'Any shop' : shop, 20, weight: 700),
          ),
          words('Change', 17, weight: 800, color: green),
        ],
      ),
    ),
  );

  // Shop picker. '' means any shop, null means cancelled.
  Future<String?> pickStore(String current) async {
    final result = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words('Which shop?', 22, weight: 800),
                const SizedBox(height: 18),
                choice('Any shop', current.isEmpty, () => Navigator.pop(c, '')),
                for (final p in model.stores) ...[
                  const SizedBox(height: 12),
                  choice(p, p == current, () => Navigator.pop(c, p)),
                ],
                const SizedBox(height: 12),
                Tap(
                  label: 'Add a new shop',
                  onTap: () => Navigator.pop(c, '\u0000new'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: box(radius: 18, color: pale, border: null),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: green, size: 26),
                        const SizedBox(width: 12),
                        words('Add a new shop', 20,
                            weight: 800, color: green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Tap(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(c),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: box(radius: 32, border: line, thickness: 2),
                    child: words('Cancel', 18, weight: 700, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == '\u0000new') {
      final name = await askText(
        'Add a shop',
        'For example: Woolworths, Chemist',
        '',
        'Add',
      );
      final n = cleanName(name ?? '');
      if (n.isNotEmpty) {
        model.addStore(n);
        return n;
      }
      return pickStore(current);
    }
    return result;
  }

  // Choice button used in dialogs.
  Widget choice(String text, bool on, VoidCallback onTap) => Tap(
    label: text,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: box(
        color: on ? green : Colors.white,
        radius: 18,
        border: on ? null : line,
        thickness: 2,
      ),
      child: words(
        text,
        20,
        weight: 700,
        color: on ? Colors.white : ink,
      ),
    ),
  );

  // Row showing who an item is for. Tap to change.
  Widget personRow(String who, VoidCallback onTap) => Tap(
    label: 'Who is it for. Now: ${who.isEmpty ? 'anyone' : who}',
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: box(radius: 18, border: green, thickness: 2),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: green, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: words(who.isEmpty ? 'Anyone' : who, 20, weight: 700),
          ),
          words('Change', 17, weight: 800, color: green),
        ],
      ),
    ),
  );

  // Asks for short text. Returns null if cancelled.
  Future<String?> askText(String title, String hint, String start,
      String okText) async {
    final box0 = TextEditingController(text: start);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(title, 22, weight: 800),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  words(hint, 15, weight: 500, color: muted),
                ],
                const SizedBox(height: 18),
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: box(radius: 18, border: green, thickness: 2),
                  child: TextField(
                    controller: box0,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => Navigator.pop(c, v),
                    style: type(20, 700),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Tap(
                  label: okText,
                  onTap: () => Navigator.pop(c, box0.text),
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: box(color: green, radius: 36, border: null),
                    child: words(okText, 20, weight: 800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 14),
                Tap(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(c),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: box(radius: 32, border: line, thickness: 2),
                    child: words('Cancel', 18, weight: 700, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    box0.dispose();
    return result;
  }

  // Household member picker. '' means anyone, null means cancelled.
  Future<String?> pickPerson(String current) async {
    final result = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words('Who is it for?', 22, weight: 800),
                const SizedBox(height: 18),
                choice('Anyone', current.isEmpty, () => Navigator.pop(c, '')),
                for (final p in model.people) ...[
                  const SizedBox(height: 12),
                  choice(
                    p == model.accountName.trim() ? '$p (me)' : p,
                    p == current,
                    () => Navigator.pop(c, p),
                  ),
                ],
                const SizedBox(height: 12),
                Tap(
                  label: 'Add a new person',
                  onTap: () => Navigator.pop(c, '\u0000new'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: box(
                      radius: 18,
                      color: pale,
                      border: null,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: green, size: 26),
                        const SizedBox(width: 12),
                        words('Add a new person', 20,
                            weight: 800, color: green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Tap(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(c),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: box(radius: 32, border: line, thickness: 2),
                    child: words('Cancel', 18, weight: 700, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == '\u0000new') {
      final name = await askText(
        'Add a person',
        'Someone you shop with at home',
        '',
        'Add',
      );
      final n = cleanName(name ?? '');
      if (n.isNotEmpty) {
        model.addPerson(n);
        return n;
      }
      return pickPerson(current);
    }
    return result;
  }

  // Edit a list's name, assignee, or delete it.
  Future<void> manageList(String name) async {
    final nameBox = TextEditingController(text: name);
    var who = model.listAssignee(name);
    var asking = false;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: asking
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        words('Delete $name?', 22, weight: 800),
                        const SizedBox(height: 10),
                        words(
                          'Everything on this list will be taken off.',
                          17,
                          weight: 500,
                          color: muted,
                        ),
                        const SizedBox(height: 24),
                        action(
                          'Yes, delete it',
                          () => Navigator.pop(c, 'delete'),
                          color: const Color(0xffdc2626),
                          height: 62,
                          radius: 31,
                          size: 18,
                        ),
                        const SizedBox(height: 14),
                        action(
                          'Keep it',
                          () => setSt(() => asking = false),
                          color: Colors.white,
                          textColor: green,
                          outline: true,
                          height: 62,
                          radius: 31,
                          size: 18,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        words('Change this list', 22, weight: 800),
                        const SizedBox(height: 22),
                        words('NAME', 15, weight: 700, color: muted),
                        const SizedBox(height: 10),
                        Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration:
                              box(radius: 18, border: green, thickness: 2),
                          child: TextField(
                            controller: nameBox,
                            textCapitalization: TextCapitalization.words,
                            style: type(20, 700),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        words('WHO IS IT FOR?', 15, weight: 700, color: muted),
                        const SizedBox(height: 10),
                        personRow(who, () async {
                          final p = await pickPerson(who);
                          if (p != null) setSt(() => who = p);
                        }),
                        const SizedBox(height: 26),
                        action(
                          'Save',
                          () => Navigator.pop(c, 'save'),
                          height: 62,
                          radius: 31,
                          size: 20,
                        ),
                        const SizedBox(height: 14),
                        action(
                          'Cancel',
                          () => Navigator.pop(c),
                          color: Colors.white,
                          textColor: muted,
                          outline: true,
                          height: 56,
                          radius: 28,
                          size: 18,
                        ),
                        if (model.listNames.length > 1) ...[
                          const SizedBox(height: 22),
                          Center(
                            child: Tap(
                              label: 'Delete this list',
                              onTap: () => setSt(() => asking = true),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: words(
                                  'Delete this list',
                                  17,
                                  weight: 700,
                                  color: const Color(0xffdc2626),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    final newName = cleanName(nameBox.text);
    nameBox.dispose();
    if (result == 'delete') {
      model.deleteList(name);
      setState(() => notice = null);
      return;
    }
    if (result != 'save') return;
    if (!model.renameList(name, newName.isEmpty ? name : newName)) {
      setState(() => notice = 'You already have a list called $newName.');
      return;
    }
    model.setListAssignee(newName.isEmpty ? name : newName, who);
    setState(() => notice = null);
  }

  Widget listCard(String name, {required bool current}) {
    final n = model.toBuyIn(name);
    return Tap(
      label: 'Open $name. ${n == 0 ? 'Nothing to buy' : '$n to buy'}',
      onTap: () => openListScreen(name),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: box(
          radius: 20,
          color: current ? pale : Colors.white,
          border: current ? green : line,
          thickness: current ? 2 : 1,
        ),
        child: Row(
          children: [
            const Icon(Icons.list_alt, color: green, size: 32),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words(name, 22, weight: 800),
                  const SizedBox(height: 4),
                  words(
                    '${n == 0 ? 'Nothing to buy' : '$n to buy'}${model.listAssignee(name).isEmpty ? '' : ' · For ${model.listAssignee(name)}'}',
                    16,
                    weight: 600,
                    color: muted,
                  ),
                ],
              ),
            ),
            Tap(
              label: 'Change $name: name, person or delete',
              onTap: () => manageList(name),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: words('Edit', 18, weight: 800, color: green),
              ),
            ),
            const Icon(Icons.chevron_right, color: muted, size: 30),
          ],
        ),
      ),
    );
  }

  Widget listsBody() => ListView(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
    children: [
      words('THE LIST YOU ARE USING', 15, weight: 800, color: label),
      const SizedBox(height: 16),
      listCard(model.currentList, current: true),
      if (model.otherLists.isNotEmpty) ...[
        const SizedBox(height: 40),
        words('YOUR OTHER LISTS', 15, weight: 800, color: label),
        const SizedBox(height: 16),
        for (final n in model.otherLists.keys.toList()) ...[
          listCard(n, current: false),
          const SizedBox(height: 20),
        ],
      ],
      const SizedBox(height: 28),
      action('Make a new list', newList, icon: 'Plus', height: 68, radius: 34, size: 20),
    ],
  );

  Widget pastBody() {
    if (model.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: words(
            'No past items yet. Things you add will show up here.',
            16,
            weight: 500,
            color: muted,
            align: TextAlign.center,
          ),
        ),
      );
    }
    final q = pastSearch.text.trim().toLowerCase();
    final all = model.history
        .where(
          (n) =>
              (pastCategory == 'All' || guessCategory(n) == pastCategory) &&
              n.toLowerCase().contains(q),
        )
        .toList();
    final shown = all.take(pastShown).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
      children: [
        Container(
          height: 64,
          decoration: box(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.search, color: muted, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: pastSearch,
                  onChanged: (_) => setState(() => pastShown = 9),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.search,
                  style: type(17, 500),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search past items',
                    hintStyle: type(17, 500, label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (pastSearch.text.isNotEmpty)
                Tap(
                  label: 'Clear search',
                  onTap: () => setState(() {
                    pastSearch.clear();
                    pastShown = 9;
                  }),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in [
              'All',
              'Produce',
              'Dairy & Eggs',
              'Bakery',
              'Meat',
              'Pantry',
              'Other',
            ])
              pill(
                c == 'All' ? 'All items' : c,
                pastCategory == c,
                () => setState(() {
                  pastCategory = c;
                  pastShown = 9;
                }),
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (all.isEmpty)
          words(
            'No past items match. Try a different search or section.',
            16,
            weight: 500,
            color: muted,
          )
        else ...[
          words(
            'THINGS YOU HAVE ADDED BEFORE (${all.length})',
            12,
            weight: 700,
            color: label,
          ),
          const SizedBox(height: 18),
          ...groupedRows(shown),
          if (all.length > shown.length) ...[
            const SizedBox(height: 28),
            action(
              'Show more',
              () => setState(() => pastShown += 9),
              color: Colors.white,
              textColor: green,
              outline: true,
              height: 60,
              radius: 30,
              size: 17,
            ),
          ],
        ],
      ],
    );
  }

  Widget squareButton(IconData icon, String text, VoidCallback? onTap) => Tap(
    label: text,
    onTap: onTap,
    child: Container(
      width: 70,
      height: 70,
      decoration: box(color: pale, radius: 14, border: line),
      child: Icon(icon, color: green),
    ),
  );

  Widget addBody() {
    final typed = cleanName(addName.text);
    final low = typed.toLowerCase();
    final hints = suggestionsFor(typed, [
      ...model.favourites,
      ...model.history,
      ...groceries.keys,
      ...commonItems,
    ]);
    final favs = model.favourites
        .where((n) => n.toLowerCase().contains(low))
        .toList();
    final recent = model.history
        .where((n) => !model.isFavourite(n) && n.toLowerCase().contains(low))
        .take(5)
        .toList();
    final shownCategory = addCategory ?? guessCategory(typed);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
      children: [
        Center(
          child: Tap(
            label: listening ? 'Listening' : 'Tap and say what you need',
            onTap: listening ? null : voice,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: pale,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green,
                  boxShadow: [
                    BoxShadow(
                      color: green.withValues(alpha:.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: words(
            listening ? 'Listening…' : 'Tap and say it',
            22,
            weight: 800,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Divider(color: line, thickness: 2)),
            const SizedBox(width: 14),
            words('or type it', 17, weight: 700, color: muted),
            const SizedBox(width: 14),
            const Expanded(child: Divider(color: line, thickness: 2)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: box(radius: 22, border: green, thickness: 2),
          alignment: Alignment.center,
          child: TextField(
            controller: addName,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => submitAdd(),
            autocorrect: true,
            enableSuggestions: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: type(19, 600),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'For example, Milk',
              hintStyle: type(19, 600, label),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tap(
              label: detailed ? 'Show less' : 'Show more',
              onTap: () => setState(() => detailed = !detailed),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: box(
                    radius: 20,
                    color: pale,
                    border: green,
                    thickness: 1.5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      words(
                        detailed ? 'Show less' : 'Show more',
                        17,
                        weight: 700,
                        color: green,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        detailed ? Icons.expand_less : Icons.expand_more,
                        color: green,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Tap(
              label: 'Take a photo',
              onTap: () => choosePhoto(ImageSource.camera),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined,
                        color: green, size: 22),
                    const SizedBox(width: 8),
                    words('Take a photo', 17, weight: 700, color: green),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (voiceError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: words(voiceError!, 14, color: muted),
          ),
        if (listening)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: words('Listening…', 14, color: muted),
          ),
        if (photo != null && userPhoto) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              itemPicture(typed.isEmpty ? 'item' : typed, photo, 56),
              const SizedBox(width: 17),
              Expanded(child: words('Your photo is added', 15, weight: 700)),
              Tap(
                label: 'Remove photo',
                onTap: () => setState(() {
                  photo = null;
                  userPhoto = false;
                }),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: muted),
                ),
              ),
            ],
          ),
        ],
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in hints)
                Tap(
                  label: 'Use $h',
                  onTap: () => setState(() {
                    addName.text = h;
                    addName.selection = TextSelection.collapsed(
                      offset: h.length,
                    );
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: box(color: pale, radius: 12, border: green),
                    child: words(h, 15, weight: 700, color: green),
                  ),
                ),
            ],
          ),
        ],
        if (detailed) ...[
          const SizedBox(height: 30),
          Tap(
            label: addFav ? 'Remove favourite' : 'Make it a favourite',
            onTap: () => setState(() => addFav = !addFav),
            child: Row(
              children: [
                Icon(
                  addFav ? Icons.star : Icons.star_border,
                  size: 30,
                  color: addFav ? amber : muted,
                ),
                const SizedBox(width: 11),
                words('Favourite', 16, weight: 600),
              ],
            ),
          ),
          const SizedBox(height: 24),
          words('Category', 14, weight: 700),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in [
                'Produce',
                'Dairy & Eggs',
                'Bakery',
                'Meat',
                'Pantry',
                'Other',
              ])
                pill(c, shownCategory == c, () => setState(() => addCategory = c)),
            ],
          ),
          const SizedBox(height: 24),
          words('Which shop?', 14, weight: 700),
          const SizedBox(height: 12),
          storeRow(storeSel, () async {
            final p = await pickStore(storeSel);
            if (p != null) setState(() => storeSel = p);
          }),
          const SizedBox(height: 24),
          words('Who is it for?', 14, weight: 700),
          const SizedBox(height: 12),
          personRow(assignTo, () async {
            final p = await pickPerson(assignTo);
            if (p != null) setState(() => assignTo = p);
          }),
          const SizedBox(height: 24),
          words('Picture', 14, weight: 700),
          const SizedBox(height: 12),
          action(
            'Choose a photo from my phone',
            () => choosePhoto(ImageSource.gallery),
            color: Colors.white,
            textColor: green,
            outline: true,
            height: 60,
            radius: 30,
            size: 16,
          ),
          const SizedBox(height: 24),
          words('How many?', 14, weight: 700),
          const SizedBox(height: 12),
          stepper(addQty, (n) => setState(() => addQty = n), safety: true),
          const SizedBox(height: 24),
          words('Unit', 14, weight: 700),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in {'Units': 'items', 'Litres': 'litres', 'Kg': 'kg'}.entries)
                pill(u.key, addUnit == u.value, () => setState(() => addUnit = u.value)),
            ],
          ),
        ],
        const SizedBox(height: 30),
        action('Add item', submitAdd),
        if (typed.isEmpty) ...[
          const SizedBox(height: 36),
          ...habitSection(),
        ],
        if (favs.isNotEmpty) ...[
          const SizedBox(height: 36),
          words('FAVOURITES', 12, weight: 700, color: label),
          const SizedBox(height: 18),
          addFavouritesButton(),
          const SizedBox(height: 22),
          words('Tap one to add it', 15, weight: 600, color: muted),
          const SizedBox(height: 14),
          for (var k = 0; k < favs.length; k += 3) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = k; j < k + 3; j++) ...[
                  Expanded(
                    child: j < favs.length
                        ? favTile(favs[j])
                        : const SizedBox(),
                  ),
                  if (j < k + 2) const SizedBox(width: 12),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 21),
          words('RECENT', 12, weight: 700, color: label),
          const SizedBox(height: 18),
          for (final n in recent) ...[nameRow(n), const SizedBox(height: 15)],
        ],
        const SizedBox(height: 15),
        Tap(
          label: 'See more suggestions',
          onTap: () {
            search.clear();
            category = 'All';
            go('catalogue');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: words('See more suggestions', 16, weight: 700, color: green),
            ),
          ),
        ),
      ],
    );
  }

  // "Already on the list" dialog.
  Widget dupCard() {
    final item = dup!;
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          Align(
            alignment: const Alignment(0, -.081),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(20),
                decoration: box(radius: 24).copyWith(
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1a000000),
                      offset: Offset(0, 12),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: box(color: pale, radius: 24, border: null),
                      child: const Icon(Icons.search, color: green),
                    ),
                    const SizedBox(height: 21),
                    words('Already on your list', 16, weight: 700),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: type(14, 400, muted).copyWith(height: 1.4),
                        children: [
                          TextSpan(
                            text: item.name,
                            style: type(14, 700, ink).copyWith(height: 1.4),
                          ),
                          const TextSpan(
                            text: ' is already there. What would you like to do?',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    action(
                      'Update the amount',
                      () {
                        final newAmount = math.min(999, item.quantity + dupQty);
                        setState(() {
                          dup = null;
                          pendingDetails = false;
                        });
                        details(item.name, item);
                        setState(() => quantity = newAmount);
                      },
                      height: 68,
                      radius: 26,
                      size: 16,
                    ),
                    const SizedBox(height: 15),
                    action(
                      'Add as a new item anyway',
                      () {
                        setState(() => dup = null);
                        add(skipDup: true);
                      },
                      color: Colors.white,
                      textColor: green,
                      outline: true,
                      height: 68,
                      radius: 26,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget customRow(String name) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    decoration: box(color: pale, border: green),
    child: Row(
      children: [
        itemPicture(name, null, 52),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              words(name, 18, weight: 700),
              const SizedBox(height: 4),
              words('Not on our list. Tap + to add it.', 14,
                  weight: 600, color: muted),
              if (model.ruleFor(name) != null) ...[
                const SizedBox(height: 6),
                limitBadge(model.ruleFor(name)!.maximum, small: true),
              ],
            ],
          ),
        ),
        Tap(
          label: 'Add $name',
          onTap: () => details(name),
          child: Container(
            width: 62,
            height: 62,
            decoration: box(color: Colors.white, radius: 8, border: green),
            child: const Center(child: Icon(Icons.add, color: green)),
          ),
        ),
      ],
    ),
  );

  Widget stepper(int value, ValueChanged<int> update, {bool safety = false}) =>
      Container(
        padding: EdgeInsets.all(safety ? 12 : 16),
        decoration: box(radius: safety ? 16 : 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            stepButton('Minus', () => update(math.max(1, value - 1)), safety),
            words('$value', safety ? 28 : 36, weight: 800),
            stepButton('Plus', () => update(math.min(999, value + 1)), safety),
          ],
        ),
      );
  Widget stepButton(String icon, VoidCallback press, bool safety) => Tap(
    label: icon == 'Minus' ? 'Decrease quantity' : 'Increase quantity',
    onTap: press,
    child: Container(
      width: 73,
      height: 73,
      decoration: box(color: pale, radius: 28, border: green, thickness: 2),
      child: Center(child: asset(safety ? '2-348' : '28-111', icon, 24)),
    ),
  );
  Widget headsUpText() {
    final key = model.ruleKey(selected);
    final rule = key == null ? null : model.rules[key];
    final style = type(15, 400, amber).copyWith(height: 1.4);
    final bold = type(15, 700, amber).copyWith(height: 1.4);
    if (rule == null) return const SizedBox.shrink();
    final same = key!.toLowerCase() == selected.toLowerCase();
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (!same) TextSpan(text: '$selected is like '),
          if (!same) TextSpan(text: '"$key". ', style: bold),
          const TextSpan(text: 'The limit is '),
          TextSpan(text: '${rule.maximum}', style: bold),
          TextSpan(
            text: rule.block
                ? '. You cannot add more than this.'
                : '. If you add more, we will ask you first.',
          ),
        ],
      ),
    );
  }

  // Dialog with one large text box for the new name.
  Future<void> renameName() async {
    final box0 = TextEditingController(text: selected);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              words('Change the name', 22, weight: 800),
              const SizedBox(height: 18),
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: box(radius: 18, border: green, thickness: 2),
                child: TextField(
                  controller: box0,
                  autofocus: true,
                  autocorrect: true,
                  enableSuggestions: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => Navigator.pop(c, v),
                  style: type(20, 700),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Tap(
                label: 'Save the name',
                onTap: () => Navigator.pop(c, box0.text),
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: box(color: green, radius: 36, border: null),
                  child: words('Save', 20, weight: 800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Tap(
                label: 'Cancel',
                onTap: () => Navigator.pop(c),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: box(radius: 32, border: line, thickness: 2),
                  child: words('Cancel', 18, weight: 700, color: muted),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
    box0.dispose();
    final name = cleanName(result ?? '');
    if (name.isEmpty) return;
    setState(() {
      selected = name;
      editName.text = name;
    });
    // Editing an existing item: one Save applies everything.
    if (editing != null) add();
  }

  Widget detailBody() => ListView(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: box(radius: 20),
        child: Row(
          children: [
            itemPicture(selected, photo, 72),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words('SELECTED ITEM', 14, weight: 700, color: label),
                  const SizedBox(height: 12),
                  editing == null
                      ? words(selected, 22, weight: 800)
                      : Tap(
                          label: 'Change the name. Now: $selected',
                          onTap: renameName,
                          child: Row(
                            children: [
                              Flexible(
                                child: words(selected, 22, weight: 800),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.edit, size: 22, color: green),
                            ],
                          ),
                        ),
                  if (editing != null) ...[
                    const SizedBox(height: 4),
                    words('Tap the name to change it', 14,
                        weight: 600, color: green),
                  ],
                  if (editing != null &&
                      WireframeModel.niceDate(model.addedOn[editing!.id])
                          .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    words(
                      'Added ${WireframeModel.niceDate(model.addedOn[editing!.id])}'
                      '${WireframeModel.niceDate(model.gotOn[editing!.id]).isEmpty ? '' : ' · Got ${WireframeModel.niceDate(model.gotOn[editing!.id])}'}',
                      15,
                      weight: 600,
                      color: green,
                    ),
                  ],
                  const SizedBox(height: 4),
                  words(
                    (editCategory ?? editing?.category ?? guessCategory(selected)) == 'Other'
                        ? 'Your own item'
                        : '${editCategory ?? editing?.category ?? guessCategory(selected)} Section',
                    15,
                    weight: 600,
                    color: muted,
                  ),
                ],
              ),
            ),
            favStar(selected),
          ],
        ),
      ),
      const SizedBox(height: 36),
      words(editing != null ? 'HOW MANY' : 'QUANTITY TO ADD', 16, weight: 700, color: muted),
      const SizedBox(height: 18),
      stepper(quantity, (n) => setState(() => quantity = n)),
      const SizedBox(height: 36),
      ...photoSection(),
      const SizedBox(height: 36),
      words('WHO IS THIS FOR?', 16, weight: 700, color: muted),
      const SizedBox(height: 16),
      personRow(assignTo, () async {
        final p = await pickPerson(assignTo);
        if (p != null) setState(() => assignTo = p);
      }),
      const SizedBox(height: 36),
      words('WHICH SHOP?', 16, weight: 700, color: muted),
      const SizedBox(height: 16),
      storeRow(storeSel, () async {
        final p = await pickStore(storeSel);
        if (p != null) setState(() => storeSel = p);
      }),
      const SizedBox(height: 36),
      if (editing != null) ...[
        words('SHOP SECTION', 16, weight: 700, color: muted),
        const SizedBox(height: 6),
        words('Where you find it in the shop', 15, weight: 500, color: muted),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in [
              'Produce',
              'Dairy & Eggs',
              'Bakery',
              'Meat',
              'Pantry',
              'Other',
            ])
              Tap(
                label: 'Shop section $c',
                onTap: () => setState(() => editCategory = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  decoration: box(
                    color: (editCategory ?? editing!.category) == c
                        ? green
                        : Colors.white,
                    radius: 18,
                    border: (editCategory ?? editing!.category) == c
                        ? null
                        : line,
                    thickness: 2,
                  ),
                  child: words(
                    c,
                    18,
                    weight: 700,
                    color: (editCategory ?? editing!.category) == c
                        ? Colors.white
                        : muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 36),
      ],
      if (model.ruleFor(selected) != null)
      Container(
        padding: const EdgeInsets.all(24),
        decoration: box(color: yellow, border: null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            words('HEADS UP...', 15, weight: 800, color: amber),
            const SizedBox(height: 18),
            headsUpText(),
          ],
        ),
      ),
      if (editing != null) ...[
        const SizedBox(height: 8),
        Center(
          child: Tap(
            label: 'Take ${editing!.name} off my list',
            onTap: () => setState(() => deleting = editing),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: words(
                'Take off my list',
                18,
                weight: 700,
                color: const Color(0xffdc2626),
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 24),
    ],
  );

  // The Save button is pinned to the bottom of the screen.
  Widget detailFooter() => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
    decoration: const FrameDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: action(
            'Cancel',
            () => go('list'),
            color: Colors.white,
            textColor: muted,
            outline: true,
            height: 56,
            radius: 28,
            size: 17,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 3,
          child: action(
            editing != null ? 'Save changes' : 'Add to list',
            () => add(),
            icon: 'Check',
            height: 56,
            radius: 28,
            size: 18,
          ),
        ),
      ],
    ),
  );
  String? photoFor(String name) {
    for (final i in model.items) {
      if (i.name == name && model.photos[i.id] != null) {
        return model.photos[i.id];
      }
    }
    return suggested[name];
  }

  Widget limitsBody() {
    final names = model.rules.keys.toList();
    if (names.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: words(
            'No safety limits yet. Tap the green button to add one.',
            16,
            weight: 500,
            color: muted,
            align: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
      children: [
        for (final n in names) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: box(radius: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      words(n, 18, weight: 600),
                      const SizedBox(height: 2),
                      words(
                        'Limit ${model.rules[n]!.maximum} · ${model.rules[n]!.block ? 'Blocks addition' : 'Warns only'}',
                        13,
                        color: muted,
                      ),
                    ],
                  ),
                ),
                Tap(
                  label: 'Change limit for $n',
                  onTap: () => editLimit(n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: box(radius: 12),
                    child: words('Change', 14, weight: 700, color: green),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  // "an apple", "a birthday card", but "stamps" and "wrapping paper".
  String withArticle(String name) {
    final n = name.toLowerCase();
    final last = n.split(' ').last;
    const uncountable = {
      'milk', 'bread', 'butter', 'rice', 'pasta', 'cereal', 'coffee', 'tea',
      'jam', 'sugar', 'flour', 'cheese', 'water', 'soap', 'shampoo',
      'conditioner', 'toothpaste', 'bacon', 'ham', 'chicken', 'fish',
      'salmon', 'lamb', 'pork', 'mince', 'cream', 'soup', 'oil', 'juice',
      'honey', 'salad', 'paper', 'tape', 'floss', 'litter', 'food', 'sauce',
      'dressing', 'chocolate', 'vegemite', 'porridge', 'steak',
    };
    if ((last.endsWith('s') && !last.endsWith('ss')) ||
        uncountable.contains(last)) {
      return n;
    }
    return 'aeiou'.contains(n[0]) ? 'an $n' : 'a $n';
  }

  // Dialog offering a related item after an add.
  Widget suggestCard() {
    final idea = related.first;
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          Align(
            alignment: const Alignment(0, -.081),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(20),
                decoration: box(radius: 24).copyWith(
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1a000000),
                      offset: Offset(0, 12),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    words(
                      'You added ${withArticle(lastAdded)}',
                      16,
                      weight: 700,
                    ),
                    const SizedBox(height: 6),
                    words(
                      'Want to add ${withArticle(idea)} too?',
                      14,
                      color: muted,
                    ),
                    const SizedBox(height: 24),
                    action(
                      'Yes, add ${idea.toLowerCase()}',
                      () => quickAdd(idea),
                      height: 68,
                      radius: 26,
                      size: 16,
                    ),
                    const SizedBox(height: 15),
                    action(
                      'No thanks',
                      () => setState(() => prompt = false),
                      color: Colors.white,
                      textColor: green,
                      outline: true,
                      height: 68,
                      radius: 26,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget limitsFooter() => Container(
    padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
    decoration: const FrameDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: action('+ Add safety limit', addLimit),
  );

  Widget safetyBody() {
    final typed = cleanName(limitName.text);
    final hints = suggestionsFor(typed, [
      ...model.items.map((i) => i.name),
      ...groceries.keys,
      ...commonItems,
    ]);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        words('Rule name', 14, weight: 700),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: box(radius: 20),
          child: Row(
            children: [
              itemPicture(
                typed.isEmpty ? selected : typed,
                photoFor(typed.isEmpty ? selected : typed),
                48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: limitName,
                  onChanged: (_) => setState(() {}),
                  autocorrect: true,
                  enableSuggestions: true,
                  textCapitalization: TextCapitalization.words,
                  style: type(20, 600),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Item name (e.g. Soap)',
                    hintStyle: type(20, 500, label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const Icon(Icons.edit_outlined, size: 18, color: muted),
            ],
          ),
        ),
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in hints)
                Tap(
                  label: 'Use $h',
                  onTap: () => setState(() {
                    limitName.text = h;
                    limitName.selection = TextSelection.collapsed(
                      offset: h.length,
                    );
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: box(color: pale, radius: 12, border: green),
                    child: words(h, 15, weight: 700, color: green),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 30),
        words('Maximum quantity allowed', 14, weight: 700),
        const SizedBox(height: 15),
        stepper(maximum, (n) => setState(() => maximum = n), safety: true),
        const SizedBox(height: 30),
        words('If this limit is exceeded', 14, weight: 700),
        const SizedBox(height: 15),
        ruleChoice(
          false,
          'Warn only',
          'Show a friendly notice but still allow adding it',
        ),
        const SizedBox(height: 15),
        ruleChoice(
          true,
          'Block addition',
          "Don't allow adding past this amount",
        ),
      ],
    );
  }
  Widget ruleChoice(bool value, String title, String subtitle) => Tap(
    label: title,
    checked: block == value,
    onTap: () => setState(() => block = value),
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: box(
        color: block == value ? pale : Colors.white,
        border: block == value ? green : line,
        thickness: block == value ? 2 : 1,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: box(
              color: block == value ? green : Colors.white,
              radius: 12,
              border: block == value ? null : line,
            ),
            child: block == value
                ? Center(child: asset('2-348', 'Check', 14))
                : null,
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(title, 16, weight: 800),
                const SizedBox(height: 2),
                words(subtitle, 14, color: muted),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget safetyFooter() => Container(
    padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
    decoration: const FrameDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: Column(
      children: [
        action('Save safety limit', saveLimit),
        if (!newLimit) ...[
          const SizedBox(height: 18),
          action(
            'Delete limit rule',
            () {
              model.setRule(selected, null);
              go('limits');
            },
            color: Colors.white,
            textColor: const Color(0xffdc2626),
            outline: true,
          ),
        ],
      ],
    ),
  );
  Widget warningCard() {
    final key = model.ruleKey(selected);
    final rule = key == null ? null : model.rules[key];
    final blocked = rule?.block ?? false;
    final limitText = key == null || key.toLowerCase() == selected.toLowerCase()
        ? 'The limit is ${rule?.maximum}.'
        : '$selected is like "$key". The limit is ${rule?.maximum}.';
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Colors.transparent),
            Align(
              alignment: const Alignment(0, -.081),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(20),
                  decoration: box(radius: 24).copyWith(
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x1a000000),
                        offset: Offset(0, 12),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: box(
                          color: const Color(0xfff3f4f6),
                          radius: 24,
                          border: null,
                        ),
                        child: Center(
                          child: asset('17-206', 'AlertTriangle', 18),
                        ),
                      ),
                      const SizedBox(height: 24),
                      words('Add $quantity $selected?', 16, weight: 700),
                      const SizedBox(height: 6),
                      Text(
                        blocked
                            ? '$limitText Please choose a smaller number.'
                            : '$limitText Do you want to add $quantity anyway?',
                            style: type(14 * uiTextScale, 400, muted).copyWith(height: 1.4),
                            ),
                      const SizedBox(height: 24),
                      if (!blocked) ...[
                        action(
                          'Yes, add $quantity',
                          () => add(confirmed: true, skipDup: true),
                          height: 68,
                          radius: 26,
                          size: 16,
                        ),
                        const SizedBox(height: 15),
                      ],
                      action(
                        'Change amount',
                        () => setState(() {
                          warning = false;
                          screen = 'details';
                        }),
                        color: Colors.white,
                        textColor: green,
                        outline: true,
                        height: 68,
                        radius: 26,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}