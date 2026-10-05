import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_model.dart' show LocalOperation;
import '../local_platform.dart';
import '../shopping_item.dart';

const groceries = <String, String>{
  'Organic Bananas': 'Produce',
  'Fresh Whole Milk': 'Dairy & Eggs',
  'Eggs (Grade A)': 'Dairy & Eggs',
  'White Sliced Bread': 'Bakery',
  'Greek Yogurt': 'Dairy & Eggs',
  'Fresh Red Apples': 'Produce',
};

class SafetyRule {
  const SafetyRule(this.maximum, {this.block = false});
  final int maximum;
  final bool block;
  Map<String, dynamic> toJson() => {'maximum': maximum, 'block': block};
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
        items = loaded;
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

  int existingQuantity(String name, {int? exceptId}) => items
      .where((i) => i.name == name && !i.purchased && i.id != exceptId)
      .fold(0, (n, i) => n + i.quantity);
  bool exceeds(String name, int quantity, {int? exceptId}) =>
      rules[name] != null &&
      existingQuantity(name, exceptId: exceptId) + quantity >
          rules[name]!.maximum;
  bool put(
    String name,
    int quantity, {
    ShoppingItem? edit,
    bool confirmed = false,
  }) {
    if (quantity < 1 || quantity > 999) return false;
    final over = exceeds(name, quantity, exceptId: edit?.id);
    if (over && (rules[name]!.block || !confirmed)) return false;
    final item = ShoppingItem(
      id: edit?.id ?? nextId++,
      name: name,
      quantity: quantity,
      category: edit?.category ?? groceries[name] ?? 'Produce',
      purchased: edit?.purchased ?? false,
      notes: edit?.notes ?? '',
      favourite: edit?.favourite ?? false,
    );
    final index = edit == null ? -1 : items.indexWhere((i) => i.id == edit.id);
    if (index < 0) {
      items.add(item);
    } else {
      items[index] = item;
    }
    save();
    return true;
  }

  bool toggle(ShoppingItem item) {
    // Returning a purchased item must respect a blocking aggregate limit too.
    if (item.purchased &&
        rules[item.name]?.block == true &&
        exceeds(item.name, item.quantity, exceptId: item.id)) {
      return false;
    }
    final index = items.indexWhere((i) => i.id == item.id);
    if (index < 0) return false;
    items[index] = item.withPurchased(!item.purchased);
    save();
    return true;
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
