import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/app_model.dart';
import 'package:shopping_list_app/main.dart';
import 'package:shopping_list_app/shopping_item.dart';

AppModel localModel() =>
    AppModel(operation: (action, input) async => {'ok': true})..unlocked = true;
Finder field(String name) => find.widgetWithText(TextFormField, name);
Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Future<void> addMilk(WidgetTester t) async {
  await t.tap(find.text('Add item'));
  await t.pumpAndSettle();
  await t.enterText(field('Item name'), 'Milk');
  await reveal(t, field('Quantity'));
  await t.enterText(field('Quantity'), '2');
  await reveal(t, field('Notes (optional)'));
  await t.enterText(field('Notes (optional)'), 'Lactose-free');
  await reveal(t, find.text('Add to shopping list'));
  await t.tap(find.text('Add to shopping list'));
  await t.pumpAndSettle();
  await reveal(t, find.text('Milk'));
}

void main() {
  testWidgets('household setup and member addition save locally', (t) async {
    final model = localModel();
    await t.pumpWidget(MyApp(model: model));
    await t.tap(find.byTooltip('Household & settings'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Household name'),
      'Our home',
    );
    await t.tap(find.text('Save household name'));
    await t.pumpAndSettle();
    await reveal(t, find.widgetWithText(TextField, 'New member name'));
    await t.enterText(find.widgetWithText(TextField, 'New member name'), 'Sam');
    await reveal(t, find.text('Add member'));
    await t.tap(find.text('Add member'));
    await t.pumpAndSettle();
    expect(model.household, 'Our home');
    expect(model.members, contains('Sam'));
    await reveal(t, find.text('Higher contrast'));
    await t.tap(find.text('Higher contrast'));
    await t.pumpAndSettle();
    expect(model.highContrast, isTrue);
  });
  testWidgets('copy list UI creates a separate list', (t) async {
    final model = localModel();
    model.selected.items.add(
      const ShoppingItem(id: 1, name: 'Bread', purchased: true),
    );
    model.nextId = 2;
    await t.pumpWidget(MyApp(model: model));
    await t.tap(find.text('Copy list'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'List name'), 'Weekend');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(model.selected.name, 'Weekend');
    expect(model.lists.length, 2);
    expect(model.selected.items.single.purchased, isFalse);
    await t.pump(const Duration(seconds: 1));
  });
  testWidgets('add, edit, purchase, favourite and unpurchase persist', (
    t,
  ) async {
    final model = localModel();
    await t.pumpWidget(MyApp(model: model));
    await addMilk(t);
    expect(find.text('Quantity: 2 items'), findsOneWidget);
    await t.tap(find.byType(Checkbox));
    await t.pumpAndSettle();
    expect(model.selected.items.single.purchased, isTrue);
    await t.tap(find.byTooltip('Favourite Milk'));
    await t.pumpAndSettle();
    expect(model.selected.items.single.favourite, isTrue);
    await reveal(t, find.text('Edit'));
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    await t.enterText(field('Item name'), 'Oat milk');
    await reveal(t, find.text('Save changes'));
    await t.tap(find.text('Save changes'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Oat milk'));
    expect(model.selected.items.single.notes, 'Lactose-free');
    expect(model.selected.items.single.purchased, isTrue);
    await t.tap(find.byType(Checkbox));
    await t.pumpAndSettle();
    expect(model.selected.items.single.purchased, isFalse);
  });
  testWidgets('invalid values stay in draft; cancel protects changes', (
    t,
  ) async {
    await t.pumpWidget(MyApp(model: localModel()));
    await t.tap(find.text('Add item'));
    await t.pumpAndSettle();
    await t.enterText(field('Quantity'), '0');
    await reveal(t, find.text('Add to shopping list'));
    await t.tap(find.text('Add to shopping list'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Cancel'));
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Discard these changes?'), findsOneWidget);
    await t.tap(find.text('Keep editing'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Back to shopping list'));
    await t.pumpAndSettle();
    await t.tap(find.text('Discard changes'));
    await t.pumpAndSettle();
    expect(find.text('My Shopping List'), findsOneWidget);
  });
  testWidgets('delete confirmation and Undo restore complete item', (t) async {
    final model = localModel();
    await t.pumpWidget(MyApp(model: model));
    await addMilk(t);
    await reveal(t, find.text('Remove'));
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    await t.tap(find.text('Keep item'));
    await t.pumpAndSettle();
    expect(model.selected.items.length, 1);
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove item'));
    await t.pumpAndSettle();
    expect(model.selected.items, isEmpty);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(model.selected.items.single.notes, 'Lactose-free');
    expect(model.selected.items.single.quantity, 2);
  });
  testWidgets('phone with doubled text has usable item form', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final model = localModel();
    await t.pumpWidget(MyApp(model: model));
    await addMilk(t);
    expect(model.selected.items.single.name, 'Milk');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'autocomplete fills a category and offline voice failure remains usable',
    (t) async {
      final model = AppModel(
        operation: (action, input) async {
          if (action == 'voice') throw StateError('Offline voice unavailable');
          return {};
        },
      )..unlocked = true;
      await t.pumpWidget(MyApp(model: model));
      await t.tap(find.text('Add item'));
      await t.pumpAndSettle();
      await t.enterText(field('Item name'), 'Ban');
      await t.pumpAndSettle();
      await t.tap(find.text('Bananas'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('category-Produce')),
            )
            .initialValue,
        'Produce',
      );
      await t.tap(find.text('Use offline voice entry'));
      await t.pumpAndSettle();
      expect(find.text('Offline voice unavailable'), findsOneWidget);
      await reveal(t, find.text('Add to shopping list'));
      await t.tap(find.text('Add to shopping list'));
      await t.pumpAndSettle();
      expect(model.selected.items.single.category, 'Produce');
    },
  );
  testWidgets('due reminders can be dismissed and saved', (t) async {
    final model = localModel();
    model.selected.reminder = DateTime(2020);
    await t.pumpWidget(MyApp(model: model));
    await t.tap(find.text('Dismiss reminder'));
    await t.pumpAndSettle();
    expect(model.selected.reminder, isNull);
  });
  testWidgets('lock removes list data and shows unlock screen', (t) async {
    final data = localModel().toJson();
    final model = AppModel(
      operation: (action, input) async =>
          action == 'status' ? {'exists': true} : {'data': jsonEncode(data)},
    )..unlocked = true;
    model.selected.items.add(const ShoppingItem(id: 1, name: 'Private item'));
    await t.pumpWidget(MyApp(model: model));
    await t.tap(find.byTooltip('Lock app'));
    await t.pumpAndSettle();
    expect(model.unlocked, isFalse);
    expect(model.selected.items, isEmpty);
    expect(find.text('Unlock my lists'), findsOneWidget);
  });
}
