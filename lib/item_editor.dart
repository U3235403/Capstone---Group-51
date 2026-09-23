import 'package:flutter/material.dart';

import 'app_model.dart';
import 'shopping_item.dart';

class ItemEditor extends StatefulWidget {
  const ItemEditor({
    super.key,
    required this.id,
    required this.model,
    this.item,
  });
  final int id;
  final AppModel model;
  final ShoppingItem? item;
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.item?.name ?? '');
  late final quantity = TextEditingController(
    text: '${widget.item?.quantity ?? 1}',
  );
  late final notes = TextEditingController(text: widget.item?.notes ?? '');
  late String category = widget.item?.category ?? 'Other';
  late String assignee = widget.item?.assignee ?? '';
  late String unit = widget.item?.unit ?? 'items';
  late bool favourite = widget.item?.favourite ?? false;
  bool listening = false;
  String? voiceMessage;
  @override
  void initState() {
    super.initState();
    name.addListener(refresh);
  }

  void refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    if (listening) {
      widget.model
          .operation('cancelVoice', {})
          .catchError((_) => <String, dynamic>{});
    }
    name.removeListener(refresh);
    name.dispose();
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  bool get dirty =>
      name.text != (widget.item?.name ?? '') ||
      quantity.text != '${widget.item?.quantity ?? 1}' ||
      notes.text != (widget.item?.notes ?? '') ||
      category != (widget.item?.category ?? 'Other') ||
      assignee != (widget.item?.assignee ?? '') ||
      unit != (widget.item?.unit ?? 'items') ||
      favourite != (widget.item?.favourite ?? false);
  Future<void> cancel() async {
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard these changes?'),
        content: const Text('Your changes to this item have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> voice() async {
    setState(() {
      listening = true;
      voiceMessage = 'Checking on-device speech support…';
    });
    try {
      final result = await widget.model.operation('voice', {});
      if (mounted) {
        name.text = result['text'] as String;
        setState(
          () => voiceMessage = 'Review the recognised name before adding it.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => voiceMessage = e.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      ShoppingItem(
        id: widget.id,
        name: name.text.trim(),
        quantity: int.parse(quantity.text.trim()),
        notes: notes.text.trim(),
        category: category,
        assignee: assignee,
        unit: unit,
        favourite: favourite,
        purchased: widget.item?.purchased ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = <String, String>{...catalogue};
    for (final list in widget.model.lists) {
      for (final i in list.items) {
        options[i.name] = i.category;
      }
    }
    final suggestions = name.text.trim().isEmpty
        ? <String>[]
        : options.keys
              .where(
                (n) =>
                    n.toLowerCase().contains(name.text.trim().toLowerCase()) &&
                    n.toLowerCase() != name.text.trim().toLowerCase(),
              )
              .take(5)
              .toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.item == null ? 'Add item' : 'Edit item'),
          leading: IconButton(
            tooltip: 'Back to shopping list',
            onPressed: cancel,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextFormField(
                      controller: name,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        hintText: 'For example, milk',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter an item name, such as milk.'
                          : null,
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const Text('Suggestions — choose one or keep typing'),
                      Wrap(
                        spacing: 8,
                        children: suggestions
                            .map(
                              (s) => ActionChip(
                                label: Text(s),
                                onPressed: () {
                                  name.text = s;
                                  setState(() => category = options[s]!);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: listening ? null : voice,
                      icon: const Icon(Icons.mic_none),
                      label: Text(
                        listening ? 'Listening…' : 'Use offline voice entry',
                      ),
                    ),
                    if (listening)
                      TextButton(
                        onPressed: () =>
                            widget.model.operation('cancelVoice', {}),
                        child: const Text('Stop listening'),
                      ),
                    if (voiceMessage != null)
                      Semantics(liveRegion: true, child: Text(voiceMessage!)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        return n == null || n < 1 || n > 999
                            ? 'Enter a whole number from 1 to 999.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: ['items', 'packs', 'bottles', 'kg', 'g', 'litres']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => unit = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('category-$category'),
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => category = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: assignee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Responsible person',
                      ),
                      items: ['', ...widget.model.members]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.isEmpty ? 'Unassigned' : v),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => assignee = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'For example, lactose-free',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Favourite item'),
                      value: favourite,
                      onChanged: (v) => setState(() => favourite = v),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: listening ? null : submit,
                      icon: const Icon(Icons.check),
                      label: Text(
                        widget.item == null
                            ? 'Add to shopping list'
                            : 'Save changes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
