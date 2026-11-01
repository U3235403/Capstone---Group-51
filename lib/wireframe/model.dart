import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_model.dart' show LocalOperation;
import '../local_platform.dart';
import '../shopping_item.dart';
double uiTextScale = 1.0;

const groceries = <String, String>{
  'Organic Bananas': 'Produce',
  'Fresh Whole Milk': 'Dairy & Eggs',
  'Eggs (Grade A)': 'Dairy & Eggs',
  'White Sliced Bread': 'Bakery',
  'Greek Yogurt': 'Dairy & Eggs',
  'Fresh Red Apples': 'Produce',
};

// Picks a shop section for any typed name.
String guessCategory(String name) {
  final known = groceries[name];
  if (known != null) return known;
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['banana', 'apple', 'orange', 'grape', 'berry', 'lemon', 'pear',
      'peach', 'mango', 'fruit', 'potato', 'carrot', 'onion', 'tomato',
      'lettuce', 'salad', 'broccoli', 'cucumber', 'veg'])) {
    return 'Produce';
  }
  if (has(['milk', 'egg', 'cheese', 'yogurt', 'yoghurt', 'butter', 'cream'])) {
    return 'Dairy & Eggs';
  }
  if (has(['bread', 'bun', 'roll', 'cake', 'muffin', 'croissant', 'bagel'])) {
    return 'Bakery';
  }
  if (has(['chicken', 'beef', 'lamb', 'pork', 'sausage', 'bacon', 'mince',
      'steak', 'ham', 'fish', 'salmon', 'prawn', 'meat'])) {
    return 'Meat';
  }
  if (has(['rice', 'pasta', 'cereal', 'flour', 'sugar', 'tea', 'coffee',
      'tin', 'can', 'soup', 'sauce', 'oil', 'biscuit', 'cracker'])) {
    return 'Pantry';
  }
  return 'Other';
}

// Words ignored when matching safety rules.
const _fillerWords = {
  'fresh', 'whole', 'organic', 'grade', 'a', 'the', 'of', 'and', 'large',
  'small', 'free', 'range', 'sliced', 'white', 'red',
};

// "Greek Yogurts" -> [greek, yogurt]
List<String> _tokens(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z]+'), ' ')
    .split(' ')
    .where((w) => w.isNotEmpty && !_fillerWords.contains(w))
    .map((w) {
      if (w.length > 4 && w.endsWith('ies')) {
        return '${w.substring(0, w.length - 3)}y';
      }
      if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
        return w.substring(0, w.length - 1);
      }
      return w;
    })
    .toList();

// Same word, allowing one spelling difference ("yoghurt" / "yogurt").
bool _sameWord(String a, String b) {
  if (a == b) return true;
  if (a.length < 5 || b.length < 5 || (a.length - b.length).abs() > 1) {
    return false;
  }
  var i = 0, j = 0, misses = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
    } else {
      if (++misses > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (b.length > a.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
  }
  return misses + (a.length - i) + (b.length - j) <= 1;
}

// True when every word in [small] appears in [big].
bool _covers(List<String> big, List<String> small) =>
    small.every((s) => big.any((b) => _sameWord(b, s)));

class SafetyRule {
  const SafetyRule(this.maximum, {this.block = false});
  final int maximum;
  final bool block;
  Map<String, dynamic> toJson() => {'maximum': maximum, 'block': block};
}

// Buying pattern for one item: usually every N days.
class HabitHint {
  const HabitHint(this.name, this.everyDays, this.sinceDays);
  final String name;
  final double everyDays, sinceDays;
}

class WireframeModel extends ChangeNotifier {
  WireframeModel({LocalOperation? operation})
    : operation = operation ?? localCall;
  final LocalOperation operation;
  List<ShoppingItem> items = [];
  Map<String, SafetyRule> rules = {
    'Fresh Whole Milk': const SafetyRule(2),
    'Greek Yogurt': const SafetyRule(4),
  };
  int nextId = 1, revision = 0;
  // Multiple lists. `items` is the current list; the others are stored by name.
  String currentList = 'Shopping list';
  Map<String, List<ShoppingItem>> otherLists = {};
  List<String> get listNames => [currentList, ...otherLists.keys];
  bool listExists(String name) =>
      listNames.any((n) => n.toLowerCase() == name.trim().toLowerCase());
  int toBuyIn(String name) =>
      (name == currentList ? items : (otherLists[name] ?? const <ShoppingItem>[]))
          .where((i) => !i.purchased)
          .length;
  // Creates an empty list and opens it. False if the name is empty or taken.
  bool createList(String name) {
    final n = name.trim();
    if (n.isEmpty || listExists(n)) return false;
    otherLists[currentList] = items;
    currentList = n;
    items = [];
    save();
    return true;
  }

  // Household members, and who each item and list is for.
  List<String> household = [];
  Map<int, String> itemFor = {};
  Map<String, String> listFor = {};
  List<String> get people => [
    if (accountName.trim().isNotEmpty) accountName.trim(),
    ...household.where(
      (p) => p.toLowerCase() != accountName.trim().toLowerCase(),
    ),
  ];
  String assigneeOf(int id) => itemFor[id] ?? '';
  void setAssignee(int id, String who) {
    if (who.isEmpty) {
      itemFor.remove(id);
    } else {
      itemFor[id] = who;
    }
    save();
  }

  void addPerson(String name) {
    final n = name.trim();
    if (n.isEmpty || people.any((p) => p.toLowerCase() == n.toLowerCase())) {
      return;
    }
    household.add(n);
    save();
  }

  void removePerson(String name) {
    final n = name.trim().toLowerCase();
  household.removeWhere((p) => p.toLowerCase() == n);
    itemFor.removeWhere((_, who) => who.toLowerCase() == n);
    listFor.removeWhere((_, who) => who.toLowerCase() == n);
    save();
  }

  // Add/purchase times per item (milliseconds), used for habit suggestions.
  // Calculated on the device only.
  Map<String, List<int>> habits = {};
  Map<String, int> habitSnooze = {};
  static const _day = 86400000;

  String? _habitKey(String name) {
    for (final k in habits.keys) {
      if (k.toLowerCase() == name.trim().toLowerCase()) return k;
    }
    return null;
  }

  void logHabit(String name, {DateTime? at}) {
    final n = name.trim();
    if (n.isEmpty) return;
    final key = _habitKey(n) ?? n;
    final list = habits.putIfAbsent(key, () => []);
    final t = (at ?? DateTime.now()).millisecondsSinceEpoch;
    // Adding and buying on the same trip counts once.
    if (list.isNotEmpty && (t - list.last).abs() < 6 * 3600000) {
      list[list.length - 1] = t;
    } else {
      list.add(t);
    }
    if (list.length > 30) list.removeAt(0);
    save();
  }

  // True if the item is bought about weekly or more often.
  bool boughtWeekly(String name) {
    final key = _habitKey(name);
    if (key == null) return false;
    final times = [...habits[key]!]..sort();
    if (times.length < 3) return false;
    var total = 0.0;
    for (var i = 1; i < times.length; i++) {
      total += (times[i] - times[i - 1]) / _day;
    }
    return total / (times.length - 1) <= 9;
  }

  void snoozeHabit(String name) {
    habitSnooze[name] = DateTime.now().millisecondsSinceEpoch;
    save();
  }

  // Items due again, based on past purchase intervals.
  List<HabitHint> habitHints({int max = 3}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <HabitHint>[];
    habits.forEach((name, raw) {
      final times = [...raw]..sort();
      if (times.length < 3) return;
      if (existingOnList(name) != null) return;
      final snoozed = habitSnooze[name];
      if (snoozed != null && now - snoozed < 7 * _day) return;
      var total = 0.0;
      for (var i = 1; i < times.length; i++) {
        total += (times[i] - times[i - 1]) / _day;
      }
      final every = total / (times.length - 1);
      if (every < 1) return;
      final since = (now - times.last) / _day;
      if (since >= every * 0.8) out.add(HabitHint(name, every, since));
    });
    out.sort(
      (a, b) =>
          (b.sinceDays / b.everyDays).compareTo(a.sinceDays / a.everyDays),
    );
    return out.take(max).toList();
  }

  // Shop for each item, and the shops used so far.
  List<String> stores = [];
  Map<int, String> itemStore = {};
  String storeOf(int id) => itemStore[id] ?? '';
  void setStore(int id, String shop) {
    if (shop.isEmpty) {
      itemStore.remove(id);
    } else {
      itemStore[id] = shop;
      if (!stores.any((s) => s.toLowerCase() == shop.toLowerCase())) {
        stores.add(shop);
      }
    }
    save();
  }

  void addStore(String shop) {
    final n = shop.trim();
    if (n.isEmpty || stores.any((s) => s.toLowerCase() == n.toLowerCase())) {
      return;
    }
    stores.add(n);
    save();
  }

  void removeStore(String shop) {
  final n = shop.trim().toLowerCase();
  stores.removeWhere((s) => s.toLowerCase() == n);
  itemStore.removeWhere((_, s) => s.toLowerCase() == n);
  save();
}

  String listAssignee(String list) => listFor[list] ?? '';
  void setListAssignee(String list, String who) {
    if (who.isEmpty) {
      listFor.remove(list);
    } else {
      listFor[list] = who;
    }
    save();
  }

  // Renames a list. False if empty or the name is taken.
  bool renameList(String old, String name) {
    final n = name.trim();
    if (n.isEmpty) return false;
    if (n != old &&
        listNames.any(
          (x) => x != old && x.toLowerCase() == n.toLowerCase(),
        )) {
      return false;
    }
    if (n == old) return true;
    if (old == currentList) {
      currentList = n;
    } else {
      final fresh = <String, List<ShoppingItem>>{};
      otherLists.forEach((k, v) => fresh[k == old ? n : k] = v);
      otherLists = fresh;
    }
    if (listFor.containsKey(old)) listFor[n] = listFor.remove(old)!;
    save();
    return true;
  }

  // Deletes a list and its items. At least one list must remain.
  bool deleteList(String name) {
    if (listNames.length < 2 || !listNames.contains(name)) return false;
    final gone = name == currentList ? items : (otherLists[name] ?? []);
    for (final i in gone) {
      photos.remove(i.id);
      addedOn.remove(i.id);
      gotOn.remove(i.id);
      itemFor.remove(i.id);
      itemStore.remove(i.id);
    }
    if (name == currentList) {
      final next = otherLists.keys.first;
      items = otherLists.remove(next)!;
      currentList = next;
    } else {
      otherLists.remove(name);
    }
    listFor.remove(name);
    save();
    return true;
  }

  void openList(String name) {
    if (name == currentList || !otherLists.containsKey(name)) return;
    otherLists[currentList] = items;
    items = otherLists.remove(name)!;
    currentList = name;
    save();
  }

  // User photos keyed by item id (base64).
  Map<int, String> photos = {};
  // Date each item was added and date it was marked purchased.
  Map<int, String> addedOn = {}, gotOn = {};
  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
  // Formats a date as "15 Oct". Empty if missing.
  static String niceDate(String? iso) {
    if (iso == null || iso.length < 10) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${mo[d.month - 1]}';
  }

  // Item layout on the list page: picture tiles (false) or plain rows (true).
  bool plainList = false;

  void setPlainList(bool value) {
    plainList = value;
    save();
  }

  double textScale = 1.0;

  void setTextScale(double value) {
    textScale = value.clamp(1.0, 1.5);
    uiTextScale = textScale;
    save();
  }

  // Whether carer features are enabled.
  bool familyMode = true;
  // Signed-in role: '' (none), 'user' (person with MCI) or 'carer'.
  // Saved, so sign-in happens once.
  String accountRole = '', phone = '', accountName = '', linkedTo = '';
  bool get signedIn => accountRole.isNotEmpty;
  bool get isCarer => accountRole == 'carer';

  // 6 digit link code derived from the carer's phone number.
  String get linkCode => linkCodeFor(phone);

  String linkCodeFor(String number) {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    var h = 7;
    for (final c in digits.codeUnits) {
      h = (h * 31 + c) % 900000;
    }
    return '${h + 100000}';
  }

  void signIn({
    required String role,
    required String phone,
    required String name,
    String linkedTo = '',
  }) {
    accountRole = role;
    this.phone = phone;
    accountName = name;
    this.linkedTo = linkedTo;
    familyMode = role == 'carer';
    save();
  }

  void updateAccount({required String name, required String phone}) {
    accountName = name;
    this.phone = phone;
    save();
  }

  // Switches between the person with MCI ('user') and the carer.
  void switchRole(String role) {
    if (role == accountRole) return;
    accountRole = role;
    familyMode = role == 'carer';
    emit();
    save();
  }

  void signOut() {
    accountRole = '';
    phone = '';
    accountName = '';
    linkedTo = '';
    save();
  }
  // Favourite item names, and all previously added names (newest first).
  List<String> favourites = [], history = [];
  bool ready = false, saving = false, _disposed = false;
  String? error;
  Future<void> _tail = Future.value();
  void emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'nextId': nextId,
    'items': items.map((i) => i.toJson()).toList(),
    'currentList': currentList,
    'household': household,
    'habits': habits,
    'habitSnooze': habitSnooze,
    'stores': stores,
    'itemStore': itemStore.map((k, v) => MapEntry('$k', v)),
    'itemFor': itemFor.map((k, v) => MapEntry('$k', v)),
    'listFor': listFor,
    'textScale': textScale,
    'plainList': plainList,
    'otherLists': otherLists.map(
      (k, v) => MapEntry(k, v.map((i) => i.toJson()).toList()),
    ),
    'photos': photos.map((k, v) => MapEntry('$k', v)),
    'addedOn': addedOn.map((k, v) => MapEntry('$k', v)),
    'gotOn': gotOn.map((k, v) => MapEntry('$k', v)),
    'familyMode': familyMode,
    'account': {
      'role': accountRole,
      'phone': phone,
      'name': accountName,
      'linkedTo': linkedTo,
    },
    'favourites': favourites,
    'history': history,
    'rules': rules.map((k, v) => MapEntry(k, v.toJson())),
  };
  Future<void> load() async {
    try {
      final result = await operation('wireframeLoad', {});
      if (result['data'] != null) {
        final j = jsonDecode(result['data'] as String) as Map<String, dynamic>;
        if (j['version'] != 1) {
          throw const FormatException('Unsupported local list format');
        }
        final loaded = (j['items'] as List)
            .map((i) => ShoppingItem.fromJson(Map<String, dynamic>.from(i)))
            .toList();
        final limits = (j['rules'] as Map<String, dynamic>).map((k, v) {
          final max = v['maximum'] as int;
          if (max < 1 || max > 999) {
            throw const FormatException('Invalid saved limit');
          }
          return MapEntry(k, SafetyRule(max, block: v['block'] as bool));
        });
        final savedPhotos = <int, String>{};
        final rawPhotos = j['photos'];
        if (rawPhotos is Map) {
          rawPhotos.forEach((k, v) {
            final id = int.tryParse('$k');
            if (id != null && v is String) savedPhotos[id] = v;
          });
        }
        photos = savedPhotos;
        Map<int, String> readDates(Object? raw) {
          final out = <int, String>{};
          if (raw is Map) {
            raw.forEach((k, v) {
              final id = int.tryParse('$k');
              if (id != null && v is String) out[id] = v;
            });
          }
          return out;
        }
        addedOn = readDates(j['addedOn']);
        gotOn = readDates(j['gotOn']);
        familyMode = j['familyMode'] as bool? ?? true;
        final acct = j['account'];
        if (acct is Map) {
          accountRole = '${acct['role'] ?? ''}';
          phone = '${acct['phone'] ?? ''}';
          accountName = '${acct['name'] ?? ''}';
          linkedTo = '${acct['linkedTo'] ?? ''}';
        }

        textScale =
            ((j['textScale'] as num?)?.toDouble() ?? 1.0).clamp(1.0, 1.5);
        uiTextScale = textScale;
        plainList = j['plainList'] as bool? ?? false;

        final rawFavs = j['favourites'];
        favourites = rawFavs is List ? rawFavs.whereType<String>().toList() : [];
        final rawHistory = j['history'];
        history = rawHistory is List
            ? rawHistory.whereType<String>().toList()
            : loaded.reversed.map((i) => i.name).toSet().toList();
        items = loaded;
        currentList = '${j['currentList'] ?? 'Shopping list'}';
        final rawHouse = j['household'];
        household = rawHouse is List ? rawHouse.whereType<String>().toList() : [];
        final rawStores = j['stores'];
        stores = rawStores is List ? rawStores.whereType<String>().toList() : [];
        itemStore = {};
        final rawItemStore = j['itemStore'];
        if (rawItemStore is Map) {
          rawItemStore.forEach((k, v) {
            final id = int.tryParse('$k');
            if (id != null && v is String) itemStore[id] = v;
          });
        }
        habits = {};
        final rawHabits = j['habits'];
        if (rawHabits is Map) {
          rawHabits.forEach((k, v) {
            if (v is List) habits['$k'] = v.whereType<num>().map((e) => e.toInt()).toList();
          });
        }
        habitSnooze = {};
        final rawSnooze = j['habitSnooze'];
        if (rawSnooze is Map) {
          rawSnooze.forEach((k, v) {
            if (v is num) habitSnooze['$k'] = v.toInt();
          });
        }
        itemFor = {};
        final rawItemFor = j['itemFor'];
        if (rawItemFor is Map) {
          rawItemFor.forEach((k, v) {
            final id = int.tryParse('$k');
            if (id != null && v is String) itemFor[id] = v;
          });
        }
        listFor = {};
        final rawListFor = j['listFor'];
        if (rawListFor is Map) {
          rawListFor.forEach((k, v) {
            if (v is String) listFor['$k'] = v;
          });
        }
        final rawOthers = j['otherLists'];
        otherLists = {};
        if (rawOthers is Map) {
          rawOthers.forEach((k, v) {
            if (v is List) {
              otherLists['$k'] = v
                  .map((i) => ShoppingItem.fromJson(Map<String, dynamic>.from(i)))
                  .toList();
            }
          });
        }
        rules = limits;
        nextId = j['nextId'] as int;
      }
      revision = result['revision'] as int? ?? 0;
      ready = true;
      error = null;
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
    }
    emit();
  }

  Future<void> save() {
    final data = jsonEncode(toJson());
    saving = true;
    emit();
    final task = _tail.then((_) async {
      try {
        final result = await operation('wireframeSave', {
          'data': data,
          'revision': revision,
        });
        revision = result['revision'] as int;
        error = null;
      } catch (e) {
        error = e.toString().replaceFirst('Bad state: ', '');
      }
    });
    _tail = task.whenComplete(() {
      saving = false;
      emit();
    });
    return _tail;
  }

  // Finds the rule for an item name, allowing similar wording: a rule for
  // "Greek Yogurt" also covers "Yogurt" and vice versa. The last word must match.
  String? ruleKey(String name) {
    if (rules.containsKey(name)) return name;
    final lower = name.toLowerCase().trim();
    for (final k in rules.keys) {
      if (k.toLowerCase().trim() == lower) return k;
    }
    final t = _tokens(name);
    if (t.isEmpty) return null;
    for (final k in rules.keys) {
      final r = _tokens(k);
      if (r.isEmpty || !_sameWord(t.last, r.last)) continue;
      if (_covers(t, r) || _covers(r, t)) return k;
    }
    return null;
  }

  SafetyRule? ruleFor(String name) {
    final key = ruleKey(name);
    return key == null ? null : rules[key];
  }

  int existingQuantity(String name, {int? exceptId}) {
    final key = ruleKey(name);
    return items
        .where(
          (i) =>
              !i.purchased &&
              i.id != exceptId &&
              (key == null ? i.name == name : ruleKey(i.name) == key),
        )
        .fold(0, (n, i) => n + i.quantity);
  }

  bool exceeds(String name, int quantity, {int? exceptId}) {
    final rule = ruleFor(name);
    return rule != null &&
        existingQuantity(name, exceptId: exceptId) + quantity > rule.maximum;
  }
  bool put(
    String name,
    int quantity, {
    ShoppingItem? edit,
    bool confirmed = false,
  }) {
    if (quantity < 1 || quantity > 999) return false;
    final over = exceeds(name, quantity, exceptId: edit?.id);
    if (over && (ruleFor(name)!.block || !confirmed)) return false;
    final item = ShoppingItem(
      id: edit?.id ?? nextId++,
      name: name,
      quantity: quantity,
      category: edit?.category ?? guessCategory(name),
      purchased: edit?.purchased ?? false,
      notes: edit?.notes ?? '',
      favourite: edit?.favourite ?? false,
    );
    final index = edit == null ? -1 : items.indexWhere((i) => i.id == edit.id);
    if (index < 0) {
      items.add(item);
      addedOn[item.id] = _today();
      if (edit == null) _remember(name);
    } else {
      items[index] = item;
    }
    save();
    return true;
  }

  void _remember(String name) {
    history.removeWhere((h) => h.toLowerCase() == name.toLowerCase());
    history.insert(0, name);
    if (history.length > 100) history = history.sublist(0, 100);
  }

  bool isFavourite(String name) =>
      favourites.any((f) => f.toLowerCase() == name.toLowerCase());

  void toggleFavourite(String name) {
    if (isFavourite(name)) {
      favourites.removeWhere((f) => f.toLowerCase() == name.toLowerCase());
    } else {
      favourites.insert(0, name);
    }
    save();
  }

  // Item already on the to-buy list with the same name, so a re-add can
  // change the amount instead.
  ShoppingItem? existingOnList(String name, {int? exceptId}) {
    final t = _tokens(name).join(' ');
    if (t.isEmpty) return null;
    for (final i in items) {
      if (i.purchased || i.id == exceptId) continue;
      if (_tokens(i.name).join(' ') == t) return i;
    }
    return null;
  }

  // Sets the shop section and unit from the detailed add view.
  void setDetails(int id, {String? category, String? unit}) {
    final index = items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final o = items[index];
    items[index] = ShoppingItem(
      id: o.id,
      name: o.name,
      quantity: o.quantity,
      notes: o.notes,
      purchased: o.purchased,
      favourite: o.favourite,
      category: category ?? o.category,
      assignee: o.assignee,
      unit: unit ?? o.unit,
    );
    save();
  }

  // Removes all purchased items from the current list.
  void clearPurchased() {
    final gone = items.where((i) => i.purchased).map((i) => i.id).toList();
    items.removeWhere((i) => i.purchased);
    for (final id in gone) {
      photos.remove(id);
      addedOn.remove(id);
      gotOn.remove(id);
      itemFor.remove(id);
      itemStore.remove(id);
    }
    save();
  }

  // Removes an item and its stored data.
  void removeItem(int id) {
    items.removeWhere((i) => i.id == id);
    photos.remove(id);
    addedOn.remove(id);
    gotOn.remove(id);
    itemFor.remove(id);
    itemStore.remove(id);
    save();
  }

  // Sets the picture for an item (null clears it).
  void setPhoto(int id, String? photo) {
    if (photo == null) {
      photos.remove(id);
    } else {
      photos[id] = photo;
    }
    save();
  }

  bool toggle(ShoppingItem item) {
    // Un-purchasing must also respect a blocking limit.
    if (item.purchased &&
        ruleFor(item.name)?.block == true &&
        exceeds(item.name, item.quantity, exceptId: item.id)) {
      return false;
    }
    final index = items.indexWhere((i) => i.id == item.id);
    if (index < 0) return false;
    items[index] = item.withPurchased(!item.purchased);
    if (item.purchased) {
      gotOn.remove(item.id);
    } else {
      gotOn[item.id] = _today();
    }
    save();
    return true;
  }

  void setFamilyMode(bool value) {
    familyMode = value;
    save();
  }

  void setRule(String name, SafetyRule? rule) {
    if (rule == null) {
      rules.remove(name);
    } else {
      rules[name] = rule;
    }
    save();
  }
}