// Separate visual-review entry point; never used by the normal app build.
import 'package:flutter/material.dart';

import 'shopping_item.dart';
import 'wireframe/model.dart';
import 'wireframe/app.dart';

void main() {
  final screen = Uri.base.queryParameters['screen'] ?? 'list';
  final model = WireframeModel(
    operation: (action, input) async => {
      'revision': (input['revision'] as int? ?? 0) + 1,
    },
  )..ready = true;
  if (screen == 'list' || screen == 'warning') {
    model.items = const [
      ShoppingItem(
        id: 1,
        name: 'Fresh Whole Milk',
        quantity: 2,
        category: 'Dairy & Eggs',
      ),
      ShoppingItem(id: 2, name: 'Bananas', quantity: 4, category: 'Produce'),
      ShoppingItem(
        id: 3,
        name: 'White Bread',
        quantity: 1,
        category: 'Bakery',
        purchased: true,
      ),
      ShoppingItem(
        id: 4,
        name: 'Eggs (Grade A)',
        quantity: 1,
        category: 'Dairy & Eggs',
        purchased: true,
      ),
    ];
    model.nextId = 5;
  }
  runApp(WireframeApp(model: model, initialScreen: screen));
}
