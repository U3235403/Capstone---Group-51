import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/app_model.dart';
import 'package:shopping_list_app/shopping_item.dart';

void main() {
  test('round trip retains household, preferences, lists, assignments and reminders', () async {
    String? stored;
    final model = AppModel(
      operation: (a, p) async {
        stored = p['data'] as String?;
        return {};
      },
    )..unlocked = true;
    model.household = 'Home';
    model.members = ['Me', 'Sam'];
    model.highContrast = true;
    model.textScale = 1.5;
    model.selected.reminder = DateTime(2030, 1, 2, 10, 30);
    model.selected.items.add(
      const ShoppingItem(
        id: 1,
        name: 'Milk',
        assignee: 'Sam',
        category: 'Dairy & eggs',
        favourite: true,
        notes: 'Cold',
      ),
    );
    model.nextId = 2;
    await model.persist();
    final restored = AppModel();
    restored.restore(stored!);
    expect(restored.toJson(), model.toJson());
    model.dispose();
    restored.dispose();
  });
  test(
    'copy resets purchase state with independent item IDs and no reminder',
    () async {
      final model = AppModel(operation: (a, p) async => {})..unlocked = true;
      final original = model.selected;
      original.items.add(
        ShoppingItem(
          id: model.newId(),
          name: 'Bread',
          purchased: true,
          favourite: true,
          notes: 'Wholemeal',
        ),
      );
      original.reminder = DateTime(2030);
      model.addList('Next week', copy: original);
      await model.persist();
      expect(model.selected.items.single.purchased, isFalse);
      expect(model.selected.items.single.id, isNot(original.items.single.id));
      expect(model.selected.reminder, isNull);
      expect(model.selected.items.single.notes, 'Wholemeal');
      model.dispose();
    },
  );
  test(
    'search, combined filters and sorting work without changing saved order',
    () {
      final m = AppModel();
      m.selected.items.addAll([
        const ShoppingItem(
          id: 1,
          name: 'Milk',
          category: 'Dairy & eggs',
          assignee: 'Sam',
          favourite: true,
          quantity: 2,
        ),
        const ShoppingItem(
          id: 2,
          name: 'Apples',
          category: 'Produce',
          notes: 'Green',
          quantity: 5,
        ),
        const ShoppingItem(
          id: 3,
          name: 'Bread',
          category: 'Bakery',
          purchased: true,
        ),
      ]);
      expect(m.visibleItems(query: 'green').single.name, 'Apples');
      expect(
        m
            .visibleItems(
              category: 'Dairy & eggs',
              status: 'Favourites',
              assignee: 'Sam',
            )
            .single
            .name,
        'Milk',
      );
      expect(m.visibleItems(status: 'Purchased').single.name, 'Bread');
      expect(m.visibleItems(sort: 'Name').first.name, 'Apples');
      expect(m.visibleItems(sort: 'Quantity').first.quantity, 5);
      expect(m.selected.items.first.name, 'Milk');
      m.dispose();
    },
  );
  test('member removal unassigns items across all lists', () async {
    final m = AppModel(operation: (a, p) async => {})..unlocked = true;
    m.members = ['Me', 'Sam'];
    m.selected.items.add(
      const ShoppingItem(id: 1, name: 'Milk', assignee: 'Sam'),
    );
    m.removeMember('Sam');
    await m.persist();
    expect(m.selected.items.single.assignee, '');
    expect(m.members, ['Me']);
    m.dispose();
  });
  test('recommendations exclude current items and favour favourites', () async {
    final m = AppModel(operation: (a, p) async => {})..unlocked = true;
    m.selected.items.addAll([
      const ShoppingItem(id: 1, name: 'Milk', purchased: true),
      const ShoppingItem(id: 2, name: 'Apples', favourite: true),
    ]);
    m.nextId = 3;
    m.addList('New');
    await m.persist();
    expect(m.recommendations().first.name, 'Apples');
    m.selected.items.add(const ShoppingItem(id: 4, name: 'Apples'));
    expect(m.recommendations().single.name, 'Milk');
    m.dispose();
  });
  test('failed save blocks lock, retry clears error', () async {
    bool fail = true;
    final m = AppModel(
      operation: (a, p) async {
        if (a == 'save' && fail) throw StateError('Disk full');
        return {};
      },
    )..unlocked = true;
    await m.persist();
    expect(m.saveError, isNotNull);
    await expectLater(m.lock(), throwsStateError);
    expect(m.unlocked, isTrue);
    fail = false;
    await m.persist();
    await m.lock();
    expect(m.unlocked, isFalse);
    m.dispose();
  });
  test(
    'explicit discard recovers from a stale vault and clears memory',
    () async {
      final m = AppModel(
        operation: (a, p) async {
          if (a == 'save') throw StateError('Another tab changed the vault');
          return {};
        },
      )..unlocked = true;
      m.household = 'Unsaved';
      await m.persist();
      await m.lock(discardUnsaved: true);
      expect(m.unlocked, isFalse);
      expect(m.saveError, isNull);
      expect(m.household, 'My household');
      m.dispose();
    },
  );
  test('device settings wait for saves and reject failed saves', () async {
    final actions = <String>[];
    final m = AppModel(
      operation: (a, p) async {
        actions.add(a);
        if (a == 'save') throw StateError('Storage full');
        return {};
      },
    )..unlocked = true;
    m.persist();
    await expectLater(m.setDeviceUnlock(true), throwsStateError);
    expect(actions, ['save']);
    expect(m.deviceUnlock, isFalse);
    m.dispose();
  });
  test('queued writes preserve latest snapshot', () async {
    final names = <String>[];
    final m = AppModel(
      operation: (a, p) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        names.add(
          (jsonDecode(p['data'] as String) as Map)['household'] as String,
        );
        return {};
      },
    )..unlocked = true;
    m.household = 'First';
    final a = m.persist();
    m.household = 'Second';
    final b = m.persist();
    await Future.wait([a, b]);
    expect(names, ['First', 'Second']);
    expect(m.saving, isFalse);
    m.dispose();
  });
}
