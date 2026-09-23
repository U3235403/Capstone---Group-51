import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'shopping_item.dart';
import 'local_platform.dart';

const categories = [
  'Other',
  'Produce',
  'Dairy & eggs',
  'Bakery',
  'Pantry',
  'Meat & fish',
  'Frozen',
  'Household',
];
const catalogue = <String, String>{
  'Apples': 'Produce',
  'Bananas': 'Produce',
  'Carrots': 'Produce',
  'Potatoes': 'Produce',
  'Tomatoes': 'Produce',
  'Milk': 'Dairy & eggs',
  'Eggs': 'Dairy & eggs',
  'Yoghurt': 'Dairy & eggs',
  'Cheese': 'Dairy & eggs',
  'Bread': 'Bakery',
  'Rice': 'Pantry',
  'Pasta': 'Pantry',
  'Oats': 'Pantry',
  'Coffee': 'Pantry',
  'Chicken': 'Meat & fish',
  'Fish': 'Meat & fish',
  'Frozen peas': 'Frozen',
  'Soap': 'Household',
  'Toilet paper': 'Household',
};

class ShoppingList {
  ShoppingList({
    required this.id,
    required this.name,
    List<ShoppingItem>? items,
    this.reminder,
  }) : items = items ?? [];
  final int id;
  String name;
  List<ShoppingItem> items;
  DateTime? reminder;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
    'reminder': reminder?.toIso8601String(),
  };
  factory ShoppingList.fromJson(Map<String, dynamic> json) => ShoppingList(
    id: json['id'] as int,
    name: json['name'] as String,
    items: (json['items'] as List)
        .map((i) => ShoppingItem.fromJson(Map<String, dynamic>.from(i)))
        .toList(),
    reminder: DateTime.tryParse(json['reminder'] as String? ?? ''),
  );
}

typedef LocalOperation = Future<Map<String, dynamic>> Function(
  String,
  Map<String, dynamic>,
);

class AppModel extends ChangeNotifier {
  AppModel({LocalOperation? operation}) : operation = operation ?? localCall;
  final LocalOperation operation;
  String household = 'My household';
  List<String> members = ['Me'];
  List<ShoppingList> lists = [ShoppingList(id: 0, name: 'Weekly shopping')];
  int selectedId = 0;
  int nextId = 1;
  double textScale = 1;
  bool highContrast = false;
  bool reduceMotion = false;
  int autoLockMinutes = 10;
  bool deviceUnlock = false;
  bool unlocked = false;
  bool saving = false;
  int _pendingSaves = 0;
  String? saveError;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ShoppingList get selected =>
      lists.firstWhere((l) => l.id == selectedId, orElse: () => lists.first);
  int newId() => nextId++;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'household': household,
    'members': members,
    'lists': lists.map((l) => l.toJson()).toList(),
    'selectedId': selectedId,
    'nextId': nextId,
    'textScale': textScale,
    'highContrast': highContrast,
    'reduceMotion': reduceMotion,
    'autoLockMinutes': autoLockMinutes,
  };
  void restore(String value) {
    final j = jsonDecode(value) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Unsupported saved data version');
    }
    household = j['household'] as String;
    members = (j['members'] as List).cast<String>();
    lists = (j['lists'] as List)
        .map((l) => ShoppingList.fromJson(Map<String, dynamic>.from(l)))
        .toList();
    if (lists.isEmpty) throw const FormatException('Saved data has no lists');
    selectedId = j['selectedId'] as int;
    nextId = j['nextId'] as int;
    textScale = (j['textScale'] as num).toDouble();
    highContrast = j['highContrast'] as bool;
    reduceMotion = j['reduceMotion'] as bool;
    autoLockMinutes = j['autoLockMinutes'] as int;
  }

  Future<void> unlock(
    String password, {
    bool create = false,
    bool device = false,
  }) async {
    final result = await operation(
      device
          ? 'deviceLogin'
          : create
          ? 'create'
          : 'login',
      {'password': password, 'data': jsonEncode(toJson())},
    );
    restore(result['data'] as String);
    final status = await operation('status', {});
    deviceUnlock = status['deviceUnlock'] == true;
    unlocked = true;
    saveError = null;
    notifyListeners();
  }

  Future<void> persist() {
    if (!unlocked) return Future.value();
    final snapshot = jsonEncode(toJson());
    _pendingSaves++;
    saving = true;
    notifyListeners();
    final task = _tail.then((_) => operation('save', {'data': snapshot}));
    final completion = task
        .then<void>(
          (_) {
            saveError = null;
          },
          onError: (Object e, StackTrace s) {
            saveError = e.toString();
          },
        )
        .whenComplete(() {
          _pendingSaves--;
          saving = _pendingSaves > 0;
          notifyListeners();
        });
    _tail = completion;
    return completion;
  }

  void changed() {
    persist();
  }

  Future<void> setDeviceUnlock(bool enable) async {
    await _tail;
    if (saveError != null) {
      throw StateError('Save your changes before changing device unlock.');
    }
    await operation(enable ? 'enableDevice' : 'disableDevice', {});
    deviceUnlock = enable;
    notifyListeners();
  }

  Future<void> lock({bool discardUnsaved = false}) async {
    await _tail;
    if (saveError != null && !discardUnsaved) {
      throw StateError('Changes are not saved. Retry saving before locking.');
    }
    await operation('lock', {});
    unlocked = false;
    // Drop household data from memory as well as the encryption key.
    household = 'My household';
    members = ['Me'];
    lists = [ShoppingList(id: 0, name: 'Weekly shopping')];
    selectedId = 0;
    nextId = 1;
    textScale = 1;
    highContrast = false;
    reduceMotion = false;
    saveError = null;
    notifyListeners();
  }

  void addList(String name, {ShoppingList? copy}) {
    final list = ShoppingList(
      id: newId(),
      name: name,
      items: copy?.items
          .map((i) => i.copyWith(id: newId(), purchased: false))
          .toList(),
    );
    lists.add(list);
    selectedId = list.id;
    changed();
  }

  void removeMember(String member) {
    members.remove(member);
    for (final list in lists) {
      list.items = list.items
          .map((i) => i.assignee == member ? i.copyWith(assignee: '') : i)
          .toList();
    }
    changed();
  }

  List<ShoppingItem> visibleItems({
    String query = '',
    String category = 'All',
    String status = 'All',
    String assignee = 'All',
    String sort = 'Added',
  }) {
    final items = selected.items
        .where(
          (i) =>
              ('${i.name} ${i.notes}').toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (category == 'All' || i.category == category) &&
              (status == 'All' ||
                  status == 'To buy' && !i.purchased ||
                  status == 'Purchased' && i.purchased ||
                  status == 'Favourites' && i.favourite) &&
              (assignee == 'All' ||
                  (assignee == 'Unassigned'
                      ? i.assignee.isEmpty
                      : i.assignee == assignee)),
        )
        .toList();
    if (sort == 'Name') {
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    if (sort == 'Category') {
      items.sort((a, b) => a.category.compareTo(b.category));
    }
    if (sort == 'Quantity') {
      items.sort((a, b) => b.quantity.compareTo(a.quantity));
    }
    return items;
  }

  List<({String name, String category, String reason})> recommendations() {
    final counts = <String, int>{},
        names = <String, String>{},
        cats = <String, String>{},
        favourites = <String>{};
    for (final list in lists) {
      for (final item in list.items) {
        final key = item.name.toLowerCase();
        names[key] = item.name;
        cats[key] = item.category;
        counts[key] = (counts[key] ?? 0) + (item.purchased ? 2 : 1);
        if (item.favourite) favourites.add(key);
      }
    }
    final existing = selected.items.map((i) => i.name.toLowerCase()).toSet();
    final ranked = counts.keys.where((k) => !existing.contains(k)).toList()
      ..sort(
        (a, b) => ((counts[b] ?? 0) + (favourites.contains(b) ? 5 : 0))
            .compareTo((counts[a] ?? 0) + (favourites.contains(a) ? 5 : 0)),
      );
    return ranked
        .take(5)
        .map(
          (k) => (
            name: names[k]!,
            category: cats[k]!,
            reason: favourites.contains(k)
                ? 'A favourite from your saved lists'
                : 'Previously used in your saved lists',
          ),
        )
        .toList();
  }
}
