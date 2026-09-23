import 'dart:async';

import 'package:flutter/material.dart';

import 'app_model.dart';
import 'item_editor.dart';
import 'settings_page.dart';
import 'shopping_item.dart';
import 'theme.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key, required this.model});
  final AppModel model;
  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final search = TextEditingController();
  String category = 'All', status = 'All', assignee = 'All', sort = 'Added';
  late final Timer reminderTimer;
  AppModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    reminderTimer.cancel();
    search.dispose();
    super.dispose();
  }

  void resetFilters() {
    search.clear();
    category = 'All';
    status = 'All';
    assignee = 'All';
    sort = 'Added';
  }

  void tell(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<String?> askName(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLength: 60,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'List name',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  update(() => error = 'Enter a list name.');
                  return;
                }
                Navigator.pop(c, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // The dialog route may still animate after completing its result.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    return result;
  }

  Future<void> newList({bool copy = false}) async {
    final source = model.selected;
    final name = await askName(
      copy ? 'Copy list' : 'Create list',
      copy ? '${source.name} copy' : '',
    );
    if (name != null && mounted) {
      model.addList(name, copy: copy ? source : null);
      setState(resetFilters);
    }
  }

  Future<void> edit([ShoppingItem? item]) async {
    final list = model.selected;
    final result = await Navigator.push<ShoppingItem>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ItemEditor(id: item?.id ?? model.newId(), model: model, item: item),
      ),
    );
    if (result == null || !mounted || !model.unlocked) return;
    final index = list.items.indexWhere((i) => i.id == result.id);
    if (index == -1) {
      list.items.add(result);
    } else {
      list.items[index] = result;
    }
    model.changed();
  }

  Future<void> remove(ShoppingItem item) async {
    final list = model.selected;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${item.name}?'),
        content: const Text(
          'This item will be removed from your shopping list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep item'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove item'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final index = list.items.indexWhere((i) => i.id == item.id);
    list.items.removeAt(index);
    model.changed();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} removed'),
        duration: const Duration(seconds: 15),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!list.items.any((i) => i.id == item.id)) {
              list.items.insert(index.clamp(0, list.items.length), item);
              model.changed();
            }
          },
        ),
      ),
    );
  }

  Future<void> reminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!value.isAfter(DateTime.now())) {
      tell('Choose a future time.');
      return;
    }
    model.selected.reminder = value;
    model.changed();
  }

  String dateLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  Widget dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChange,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: (v) => setState(() => onChange(v!)),
  );
  Widget row(ShoppingItem item) => Card(
    key: ValueKey(item.id),
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: model.highContrast ? Colors.black : AppTheme.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: item.purchased,
                  semanticLabel: item.purchased
                      ? 'Mark ${item.name} as still to buy'
                      : 'Mark ${item.name} as purchased',
                  onChanged: (v) {
                    final list = model.selected;
                    final i = list.items.indexWhere((n) => n.id == item.id);
                    list.items[i] = item.withPurchased(v ?? false);
                    model.changed();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Quantity: ${item.quantity} ${item.unit}'),
                    Text(item.category),
                    if (item.assignee.isNotEmpty)
                      Text('Responsible: ${item.assignee}'),
                    if (item.notes.isNotEmpty) Text(item.notes),
                    if (item.purchased)
                      const Text(
                        'Purchased',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: item.favourite
                    ? 'Remove ${item.name} from favourites'
                    : 'Favourite ${item.name}',
                onPressed: () {
                  final list = model.selected;
                  final i = list.items.indexWhere((n) => n.id == item.id);
                  list.items[i] = item.copyWith(favourite: !item.favourite);
                  model.changed();
                },
                icon: Icon(
                  item.favourite ? Icons.star : Icons.star_border,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => edit(item),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => remove(item),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (!model.members.contains(assignee) &&
          assignee != 'All' &&
          assignee != 'Unassigned') {
        assignee = 'All';
      }
      final list = model.selected;
      final items = model.visibleItems(
        query: search.text,
        category: category,
        status: status,
        assignee: assignee,
        sort: sort,
      );
      final remaining = list.items.where((i) => !i.purchased).length;
      final due = model.lists
          .where(
            (l) => l.reminder != null && !l.reminder!.isAfter(DateTime.now()),
          )
          .toList();
      final suggestions = model.recommendations();
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Shopping List'),
          actions: [
            IconButton(
              tooltip: 'Household & settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage(model: model)),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: 'Lock app',
              onPressed: () async {
                try {
                  await model.lock();
                } catch (e) {
                  if (mounted) tell(e.toString());
                }
              },
              icon: const Icon(Icons.lock_outline),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          model.household,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            model.saveError != null
                                ? 'Changes not saved'
                                : model.saving
                                ? 'Saving on this device…'
                                : 'Saved on this device • offline',
                          ),
                        ),
                        if (model.saveError != null) ...[
                          Text(
                            model.saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton(
                            onPressed: model.persist,
                            child: const Text('Retry saving'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final discard = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text(
                                    'Discard unsaved changes and lock?',
                                  ),
                                  content: const Text(
                                    'Only changes that failed to save will be lost. Unlock again to load the latest saved lists.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Keep editing'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Discard and lock'),
                                    ),
                                  ],
                                ),
                              );
                              if (discard == true) {
                                await model.lock(discardUnsaved: true);
                              }
                            },
                            child: const Text(
                              'Discard unsaved changes and lock',
                            ),
                          ),
                        ],
                        for (final d in due)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shopping reminder: ${d.name}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text('Due ${dateLabel(d.reminder!)}'),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          model.selectedId = d.id;
                                          setState(resetFilters);
                                          model.changed();
                                        },
                                        child: const Text('Open list'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          d.reminder = DateTime.now().add(
                                            const Duration(hours: 1),
                                          );
                                          model.changed();
                                        },
                                        child: const Text('Remind in 1 hour'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          d.reminder = null;
                                          model.changed();
                                        },
                                        child: const Text('Dismiss reminder'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<int>(
                          key: ValueKey(list.id),
                          initialValue: list.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Shopping list',
                          ),
                          items: model.lists
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l.id,
                                  child: Text(l.name),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            model.selectedId = id!;
                            setState(resetFilters);
                            model.changed();
                          },
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: newList,
                              icon: const Icon(Icons.add),
                              label: const Text('New list'),
                            ),
                            TextButton.icon(
                              onPressed: () => newList(copy: true),
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy list'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final name = await askName(
                                  'Rename list',
                                  list.name,
                                );
                                if (name != null && mounted) {
                                  list.name = name;
                                  model.changed();
                                }
                              },
                              child: const Text('Rename'),
                            ),
                            TextButton.icon(
                              onPressed: reminder,
                              icon: const Icon(Icons.alarm),
                              label: const Text('Set reminder'),
                            ),
                          ],
                        ),
                        if (list.reminder != null)
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Reminder: ${dateLabel(list.reminder!)}'),
                              TextButton(
                                onPressed: () {
                                  list.reminder = null;
                                  model.changed();
                                },
                                child: const Text('Cancel reminder'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Search items or notes',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: const Text('Filter & sort'),
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 16),
                          children: [
                            dropdown('Category', category, [
                              'All',
                              ...categories,
                            ], (v) => category = v),
                            const SizedBox(height: 12),
                            dropdown('Show', status, [
                              'All',
                              'To buy',
                              'Purchased',
                              'Favourites',
                            ], (v) => status = v),
                            const SizedBox(height: 12),
                            dropdown('Assigned to', assignee, [
                              'All',
                              'Unassigned',
                              ...model.members,
                            ], (v) => assignee = v),
                            const SizedBox(height: 12),
                            dropdown('Sort by', sort, [
                              'Added',
                              'Name',
                              'Category',
                              'Quantity',
                            ], (v) => sort = v),
                          ],
                        ),
                        if (search.text.isNotEmpty ||
                            category != 'All' ||
                            status != 'All' ||
                            assignee != 'All' ||
                            sort != 'Added')
                          TextButton(
                            onPressed: () => setState(resetFilters),
                            child: const Text(
                              'Clear search, filters and sorting',
                            ),
                          ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            '$remaining to buy · ${list.items.length - remaining} purchased',
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (list.items.isEmpty) ...[
                          const Icon(
                            Icons.shopping_basket_outlined,
                            size: 56,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your list is empty',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add an item to start your shopping list.',
                            textAlign: TextAlign.center,
                          ),
                        ] else if (items.isEmpty)
                          const Text(
                            'No matching items. Clear the filters or try another search.',
                          )
                        else
                          ...items.map(row),
                        const SizedBox(height: 24),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Smart suggestions'),
                          children: [
                            const Text(
                              'Private recommendations from your saved lists and favourites. Nothing is sent to an AI service.',
                            ),
                            if (suggestions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'Create another list or copy this one to get suggestions from your history.',
                                ),
                              ),
                            ...suggestions.map(
                              (s) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.name),
                                subtitle: Text(s.reason),
                                trailing: IconButton(
                                  tooltip: 'Add ${s.name}',
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    list.items.add(
                                      ShoppingItem(
                                        id: model.newId(),
                                        name: s.name,
                                        category: s.category,
                                      ),
                                    );
                                    model.changed();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
