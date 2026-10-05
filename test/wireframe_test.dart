import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/wireframe/app.dart';
import 'package:shopping_list_app/wireframe/model.dart';

WireframeModel memory() => WireframeModel(
  operation: (a, p) async => {'revision': (p['revision'] as int? ?? 0) + 1},
)..ready = true;
void phone(WidgetTester t, {double width = 411, double height = 874}) {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Finder label(String text) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == text);

void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
  });
  test('warn and block limits enforce total unpurchased quantity', () async {
    final m = memory();
    expect(m.put('Fresh Whole Milk', 2), true);
    expect(m.put('Fresh Whole Milk', 1), false);
    expect(m.put('Fresh Whole Milk', 1, confirmed: true), true);
    await m.save();
    m.setRule('Fresh Whole Milk', const SafetyRule(2, block: true));
    expect(m.put('Fresh Whole Milk', 1, confirmed: true), false);
    m.toggle(m.items.first);
    expect(m.put('Fresh Whole Milk', 1), true);
    expect(m.toggle(m.items.first), false);
    await m.save();
    m.dispose();
  });
  test('editing replaces quantity and does not double-count itself', () async {
    final m = memory();
    m.put('Fresh Whole Milk', 2);
    final original = m.items.single;
    expect(m.put('Fresh Whole Milk', 2, edit: original), true);
    expect(m.items.length, 1);
    expect(m.items.single.id, original.id);
    expect(m.put('Fresh Whole Milk', 10, edit: original), false);
    expect(
      m.put('Fresh Whole Milk', 10, edit: original, confirmed: true),
      true,
    );
    expect(m.items.single.quantity, 10);
    await m.save();
    m.dispose();
  });
  test('local data and rules restore; deleting limit stays deleted', () async {
    String? saved;
    int rev = 0;
    final m = WireframeModel(
      operation: (a, p) async {
        saved = p['data'] as String;
        return {'revision': ++rev};
      },
    )..ready = true;
    m.put('Greek Yogurt', 4);
    m.setRule('Fresh Whole Milk', null);
    await m.save();
    final restored = WireframeModel(
      operation: (a, p) async => {'data': saved, 'revision': rev},
    );
    await restored.load();
    expect(restored.toJson(), m.toJson());
    expect(restored.rules.containsKey('Fresh Whole Milk'), false);
    expect(jsonDecode(saved!)['version'], 1);
    m.dispose();
    restored.dispose();
  });
  test('failed save is visible and does not claim a new revision', () async {
    final m = WireframeModel(
      operation: (a, p) async => throw StateError('Storage full'),
    )..ready = true;
    await m.save();
    expect(m.error, contains('Storage full'));
    expect(m.revision, 0);
    m.dispose();
  });
  testWidgets('empty list -> catalogue -> details -> saved and purchased', (
    t,
  ) async {
    phone(t);
    final m = memory();
    await t.pumpWidget(WireframeApp(model: m));
    expect(find.text('Your list is empty'), findsOneWidget);
    await t.tap(find.text('Add First Item'));
    await t.pumpAndSettle();
    expect(find.text('COMMONLY ADDED'), findsOneWidget);
    await t.tap(label('Add Fresh Whole Milk'));
    await t.pumpAndSettle();
    expect(find.text('Item Details'), findsOneWidget);
    await t.tap(find.text('Add to Shopping List'));
    await t.pumpAndSettle();
    expect(m.items.single.quantity, 2);
    await t.tap(label('Mark Fresh Whole Milk purchased'));
    await t.pumpAndSettle();
    expect(m.items.single.purchased, true);
    expect(find.text('PURCHASED'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('warning offers change amount or confirmed addition', (t) async {
    phone(t);
    final m = memory();
    await t.pumpWidget(WireframeApp(model: m, initialScreen: 'details'));
    await t.tap(label('Increase quantity'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add to Shopping List'));
    await t.pumpAndSettle();
    expect(find.text('Add 3 × Fresh Whole Milk?'), findsOneWidget);
    await t.tap(find.text('Change amount'));
    await t.pumpAndSettle();
    expect(m.items, isEmpty);
    await t.tap(find.text('Add to Shopping List'));
    await t.pumpAndSettle();
    await t.tap(find.text('Yes, add 3'));
    await t.pumpAndSettle();
    expect(m.items.single.quantity, 3);
    expect(t.takeException(), isNull);
  });
  testWidgets('caregiver block saves and prevents override', (t) async {
    phone(t, width: 402);
    final m = memory();
    await t.pumpWidget(WireframeApp(model: m));
    await t.tap(find.text('Caregiver Settings'));
    await t.pumpAndSettle();
    await t.tap(find.text('Block Addition'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save Safety Limit'));
    await t.pumpAndSettle();
    expect(m.rules['Fresh Whole Milk']!.block, true);
    await t.tap(find.text('Add First Item'));
    await t.pumpAndSettle();
    await t.tap(label('Add Fresh Whole Milk'));
    await t.pumpAndSettle();
    await t.tap(label('Increase quantity'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add to Shopping List'));
    await t.pumpAndSettle();
    expect(find.text('Yes, add 3'), findsNothing);
    expect(m.items, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets('search and category filters, plus safe unsupported voice', (
    t,
  ) async {
    phone(t);
    final m = WireframeModel(
      operation: (a, p) async {
        if (a == 'voice') throw StateError('Offline voice unavailable');
        return {'revision': 1};
      },
    )..ready = true;
    await t.pumpWidget(WireframeApp(model: m, initialScreen: 'catalogue'));
    await t.tap(find.text('Bakery').first);
    await t.pumpAndSettle();
    expect(find.text('White Sliced Bread'), findsOneWidget);
    expect(find.text('Fresh Whole Milk'), findsNothing);
    await t.tap(find.text('All'));
    await t.enterText(find.byType(TextField), 'Milk');
    await t.pumpAndSettle();
    expect(find.text('Fresh Whole Milk'), findsOneWidget);
    expect(find.text('Organic Bananas'), findsNothing);
    await t.tap(label('Voice search'));
    await t.pumpAndSettle();
    expect(find.text('Offline voice unavailable'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final screen in ['list', 'catalogue', 'details', 'safety']) {
    testWidgets('$screen fits iPhone viewport without layout errors', (
      t,
    ) async {
      phone(t, width: 440, height: 956);
      await t.pumpWidget(WireframeApp(model: memory(), initialScreen: screen));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
