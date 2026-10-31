import 'dart:async';

import '../pilot_bridge.dart';
import '../shopping_item.dart';
import 'model.dart';

class RemoteWireframeModel extends WireframeModel {
  Timer? _timer;
  String role = 'viewer';
  bool _closed = false;
  RemoteWireframeModel() {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!saving && error == null) load();
    });
  }
  void accept(Map<String, dynamic> data) {
    items = (data['items'] as List)
        .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    rules = (data['rules'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(
        k,
        SafetyRule(v['maximum'] as int, block: v['block'] as bool),
      ),
    );
    revision = data['revision'] as int;
    role = data['role'] as String;
    ready = true;
  }

  Future<void> run(String action, Map<String, dynamic> input) async {
    if (saving || _closed) return;
    saving = true;
    emit();
    try {
      final data = await pilotCall(action, input);
      if (!_closed) {
        accept(data);
        error = null;
      }
    } catch (e) {
      if (!_closed) error = e.toString().replaceFirst('Bad state: ', '');
    } finally {
      saving = false;
      if (!_closed) emit();
    }
  }

  @override
  Future<void> load() => run('load', {});
  @override
  Future<void> save() => run('retry', {});
  bool writable() {
    if (saving || error != null || role == 'viewer') {
      error =
          error ??
          (saving
              ? 'A save is in progress.'
              : 'This household role is read-only.');
      emit();
      return false;
    }
    return true;
  }

  @override
  bool put(
    String name,
    int quantity, {
    ShoppingItem? edit,
    bool confirmed = false,
  }) {
    if (!writable() || quantity < 1 || quantity > 999) return false;
    if (exceeds(name, quantity, exceptId: edit?.id) &&
        (rules[name]!.block || !confirmed)) {
      return false;
    }
    unawaited(
      run('put', {
        'name': name,
        'quantity': quantity,
        'confirmed': confirmed,
        if (edit != null) 'id': edit.id,
      }),
    );
    return true;
  }

  @override
  void removeItem(int id) {
    if (!writable()) return;
    unawaited(run('delete', {'id': id}));
  }

  @override
  bool toggle(ShoppingItem item) {
    if (!writable()) return false;
    unawaited(run('toggle', {'id': item.id}));
    return true;
  }

  @override
  void setRule(String name, SafetyRule? rule) {
    if (!writable()) return;
    if (!['owner', 'caregiver'].contains(role)) {
      error = 'A caregiver or owner must change safety limits.';
      emit();
      return;
    }
    unawaited(
      run('rule', {
        'name': name,
        'remove': rule == null,
        if (rule != null) ...{'maximum': rule.maximum, 'block': rule.block},
      }),
    );
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    super.dispose();
  }
}
