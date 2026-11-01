import 'package:flutter/material.dart';

import 'app.dart';
import 'model.dart';

// The Settings screen: a "Family member features" switch and a list of
// settings sections. Safety limits (the old "Caregiver Settings") lives here.
class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.model,
    required this.onOpen,
    required this.onSafety,
  });
  final WireframeModel model;
  final void Function(String title) onOpen;
  final VoidCallback onSafety;

  @override
  Widget build(BuildContext context) {
    final on = model.isCarer;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Tap(
          label: 'Change my name or phone number',
          onTap: () => onOpen('My details'),
          child: Container(
          padding: const EdgeInsets.all(22),
          decoration: box(color: pale, radius: 20, border: line),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: box(color: Colors.white, radius: 30, border: null),
                child: Icon(
                  model.isCarer ? Icons.favorite_border : Icons.person_outline,
                  color: green,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    words(
                      model.accountName.isEmpty ? 'My account' : model.accountName,
                      18,
                      weight: 800,
                    ),
                    const SizedBox(height: 4),
                    words(
                      model.isCarer ? 'Carer account' : 'My own account',
                      15,
                      weight: 600,
                      color: muted,
                    ),
                    if (model.phone.isNotEmpty)
                      words(model.phone, 14, color: muted),
                    if (model.isCarer) ...[
                      const SizedBox(height: 8),
                      words('Link code: ${model.linkCode}', 16, weight: 800, color: green),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 28, color: muted),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        row(
          Icons.swap_horiz,
          model.isCarer
              ? 'Account type: Carer'
              : 'Account type: Person living with MCI',
          () async {
            final pick = await showDialog<String>(
              context: context,
              builder: (c) => SimpleDialog(
                title: const Text('Who is using this phone?'),
                children: [
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, 'user'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: words(
                        'The person living with MCI${model.isCarer ? '' : '  (now)'}',
                        18,
                        weight: 700,
                      ),
                    ),
                  ),
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, 'carer'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: words(
                        'Their carer${model.isCarer ? '  (now)' : ''}',
                        18,
                        weight: 700,
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (pick != null) model.switchRole(pick);
          },
        ),
        row(Icons.text_fields, 'Display', () => onOpen('Display')),
        if (on)
        row(
          Icons.notifications_none,
          'Notifications & reminders',
          () => onOpen('Notifications & reminders'),
          enabled: on,
        ),
        row(Icons.people_outline, 'Household', () => onOpen('Household')),
        if (on) row(Icons.lock_outline, 'Safety limits', onSafety),
        row(Icons.list_alt, 'Categories', () => onOpen('Categories')),
        row(Icons.storefront_outlined, 'Shops', () => onOpen('Shops')),
        row(Icons.logout, 'Log out', () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Log out?'),
              content: const Text(
                'Your lists are kept. '
                'You can sign in again with one tap.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Stay logged in'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Log out'),
                ),
              ],
            ),
          );
          if (ok == true) model.signOut();
        }),
      ],
    );
  }

  Widget row(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool enabled = true,
  }) => Tap(
    label: title,
    onTap: enabled ? onTap : null,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: const FrameDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: enabled ? ink : label),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(title, 16, weight: 500, color: enabled ? ink : label),
                if (!enabled)
                  words(
                    'Only your carer can change this',
                    12,
                    color: label,
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: enabled ? muted : line),
        ],
      ),
    ),
  );
}

// Placeholder for settings sections that are not built yet.
class SettingsComingSoon extends StatelessWidget {
  const SettingsComingSoon({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          words(title, 22, weight: 800, align: TextAlign.center),
          const SizedBox(height: 12),
          words(
            'This part of Settings has not been built yet.',
            16,
            weight: 500,
            color: muted,
            align: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// Household members: add, see and remove the people this account shops for.
class HouseholdSettings extends StatefulWidget {
  const HouseholdSettings({super.key, required this.model});
  final WireframeModel model;
  @override
  State<HouseholdSettings> createState() => _HouseholdSettingsState();
}

class _HouseholdSettingsState extends State<HouseholdSettings> {
  final name = TextEditingController();
  String? problem;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void add() {
    final n = name.text.trim();
    if (n.isEmpty) {
      setState(() => problem = 'Type a name first.');
      return;
    }
    if (widget.model.people.any((p) => p.toLowerCase() == n.toLowerCase())) {
      setState(() => problem = '$n is already here.');
      return;
    }
    widget.model.addPerson(n);
    name.clear();
    setState(() => problem = null);
  }

  Future<void> remove(String who) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove $who?'),
        content: const Text(
          'Anything set aside for them goes back to the whole household. '
          'Nothing is deleted from your lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep them'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => widget.model.removePerson(who));
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.model.accountName.trim();
    final others = widget.model.people.where((p) => p != me).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        words('The people you shop for', 20, weight: 800),
        const SizedBox(height: 8),
        words(
          'Add the people in your home so you can set items aside for them.',
          15,
          color: muted,
        ),
        const SizedBox(height: 20),
        if (me.isNotEmpty) person(me, isMe: true),
        for (final p in others) person(p),
        if (others.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: words('No one else added yet.', 15, color: muted),
          ),
        const SizedBox(height: 24),
        words('Add someone', 17, weight: 700),
        const SizedBox(height: 10),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => add(),
          decoration: const InputDecoration(
            labelText: 'Their name',
            border: OutlineInputBorder(),
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: words(problem!, 14, color: Colors.red),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: add,
            child: words('Add to my household', 17, weight: 700,
                color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget person(String who, {bool isMe = false}) => Container(
        constraints: const BoxConstraints(minHeight: 64),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: box(color: isMe ? pale : Colors.white, radius: 16),
        child: Row(
          children: [
            Icon(isMe ? Icons.person : Icons.person_outline,
                size: 26, color: green),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words(who, 17, weight: 700),
                  if (isMe) words('This is you', 14, color: muted),
                ],
              ),
            ),
            if (!isMe)
              Tap(
                label: 'Remove $who',
                onTap: () => remove(who),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, size: 24, color: muted),
                ),
              ),
          ],
        ),
      );
} 

// Shops: the places this household buys from.
class ShopSettings extends StatefulWidget {
  const ShopSettings({super.key, required this.model});
  final WireframeModel model;
  @override
  State<ShopSettings> createState() => _ShopSettingsState();
}

class _ShopSettingsState extends State<ShopSettings> {
  final shop = TextEditingController();
  String? problem;

  @override
  void dispose() {
    shop.dispose();
    super.dispose();
  }

  void add() {
    final n = shop.text.trim();
    if (n.isEmpty) {
      setState(() => problem = 'Type a shop name first.');
      return;
    }
    if (widget.model.stores.any((s) => s.toLowerCase() == n.toLowerCase())) {
      setState(() => problem = '$n is already on your list.');
      return;
    }
    widget.model.addStore(n);
    shop.clear();
    setState(() => problem = null);
  }

  Future<void> remove(String s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove $s?'),
        content: const Text(
          'Items set for this shop go back to no shop in particular. '
          'Nothing is deleted from your lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => widget.model.removeStore(s));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          words('Where you shop', 20, weight: 800),
          const SizedBox(height: 8),
          words(
            'Add the shops you use so items can be grouped by where to buy them.',
            15,
            color: muted,
          ),
          const SizedBox(height: 20),
          for (final s in widget.model.stores) tile(s),
          if (widget.model.stores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: words('No shops added yet.', 15, color: muted),
            ),
          const SizedBox(height: 24),
          words('Add a shop', 17, weight: 700),
          const SizedBox(height: 10),
          TextField(
            controller: shop,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => add(),
            decoration: const InputDecoration(
              labelText: 'Shop name',
              border: OutlineInputBorder(),
            ),
          ),
          if (problem != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: words(problem!, 14, color: Colors.red),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: add,
              child: words('Add this shop', 17, weight: 700,
                  color: Colors.white),
            ),
          ),
        ],
      );

  Widget tile(String s) => Container(
        constraints: const BoxConstraints(minHeight: 64),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: box(radius: 16),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 26, color: green),
            const SizedBox(width: 14),
            Expanded(child: words(s, 17, weight: 700)),
            Tap(
              label: 'Remove $s',
              onTap: () => remove(s),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close, size: 24, color: muted),
              ),
            ),
          ],
        ),
      );
}

class DisplaySettings extends StatefulWidget {
  const DisplaySettings({super.key, required this.model});
  final WireframeModel model;
  @override
  State<DisplaySettings> createState() => _DisplaySettingsState();
}

class _DisplaySettingsState extends State<DisplaySettings> {
  static const options = [
    (1.0, 'Normal'),
    (1.2, 'Large'),
    (1.35, 'Larger'),
    (1.5, 'Largest'),
  ];

  void pick(double value) {
    widget.model.setTextScale(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.model.textScale;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        words('Text size', 20, weight: 800),
        const SizedBox(height: 8),
        words(
          'Pick the size that is easiest for you to read. '
          'The whole app changes straight away.',
          15,
          color: muted,
        ),
        const SizedBox(height: 20),
        for (final (value, label) in options) choice(value, label, current),
        const SizedBox(height: 24),
        words('List layout', 20, weight: 800),
        const SizedBox(height: 8),
        words(
          'Choose how the items on your list look. '
          'You can also change this on the list page.',
          15,
          color: muted,
        ),
        const SizedBox(height: 20),
        layoutChoice(false, 'Pictures', 'A big picture for each item'),
        layoutChoice(true, 'Plain list', 'Simple rows with no pictures'),
        const SizedBox(height: 24),
        words('Colours', 20, weight: 800),
        const SizedBox(height: 8),
        words(
          'Changes the colours of the whole app, so greens become blues '
          'and are easier to tell apart from reds.',
          15,
          color: muted,
        ),
        const SizedBox(height: 20),
        colourChoice(false, 'Normal colours', 'Green, blue, gold, red'),
        colourChoice(true, 'Colour-blind friendly', 'Blue, orange, pink, yellow'),
        const SizedBox(height: 24),
        words('High contrast', 20, weight: 800),
        const SizedBox(height: 8),
        words(
          'Makes text, borders and colours darker so they stand out more.',
          15,
          color: muted,
        ),
        const SizedBox(height: 20),
        onOff(!widget.model.highContrast, 'Off', '',
            () => widget.model.setHighContrast(false)),
        onOff(widget.model.highContrast, 'On', '',
            () => widget.model.setHighContrast(true)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: box(color: pale, radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              words('Example', 14, weight: 700, color: muted),
              const SizedBox(height: 8),
              words('2 litres of milk', 17, weight: 700),
              words('Dairy & Eggs', 15, color: muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget onOff(bool on, String title, String hint, VoidCallback act) => Tap(
        label: title,
        checked: on,
        onTap: () {
          act();
          setState(() {});
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: box(
            color: on ? pale : Colors.white,
            radius: 16,
            border: on ? green : line,
            thickness: on ? 2 : 1,
          ),
          child: Row(
            children: [
              Icon(
                on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 26,
                color: on ? green : muted,
              ),
              const SizedBox(width: 14),
              Expanded(child: words(title, 17, weight: on ? 800 : 500)),
            ],
          ),
        ),
      );

  void pickColours(bool blind) {
    widget.model.setColourBlind(blind);
    setState(() {});
  }

  Widget colourChoice(bool blind, String title, String hint) {
    final on = widget.model.colourBlind == blind;
    final colours = blind
        ? const [Color(0xff0072b2), Color(0xff56b4e9), Color(0xffe69f00), Color(0xffcc79a7)]
        : const [Color(0xff5d9a62), Color(0xff4f8fa8), Color(0xffc79a4a), Color(0xffb8665d)];
    return Tap(
      label: title,
      checked: on,
      onTap: () => pickColours(blind),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: box(
          color: on ? pale : Colors.white,
          radius: 16,
          border: on ? green : line,
          thickness: on ? 2 : 1,
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 26,
              color: on ? green : muted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words(title, 17, weight: on ? 800 : 500),
                  words(hint, 14, color: muted),
                ],
              ),
            ),
            restoreColours(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in colours)
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(left: 4),
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void pickLayout(bool plain) {
    widget.model.setPlainList(plain);
    setState(() {});
  }

  Widget layoutChoice(bool plain, String title, String hint) {
    final on = widget.model.plainList == plain;
    return Tap(
      label: '$title layout',
      checked: on,
      onTap: () => pickLayout(plain),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: box(
          color: on ? pale : Colors.white,
          radius: 16,
          border: on ? green : line,
          thickness: on ? 2 : 1,
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 26,
              color: on ? green : muted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words(title, 17, weight: on ? 800 : 500),
                  words(hint, 14, color: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget choice(double value, String label, double current) {
    final on = (current - value).abs() < 0.01;
    return Tap(
      label: '$label text size',
      checked: on,
      onTap: () => pick(value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: box(
          color: on ? pale : Colors.white,
          radius: 16,
          border: on ? green : line,
          thickness: on ? 2 : 1,
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 26,
              color: on ? green : muted,
            ),
            const SizedBox(width: 14),
            Expanded(child: words(label, 17, weight: on ? 800 : 500)),
          ],
        ),
      ),
    );
  }
}

// Categories: the shop sections items are grouped into.
class CategorySettings extends StatefulWidget {
  const CategorySettings({super.key, required this.model});
  final WireframeModel model;
  @override
  State<CategorySettings> createState() => _CategorySettingsState();
}

class _CategorySettingsState extends State<CategorySettings> {
  final text = TextEditingController();
  String? problem;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void add() {
    final p = widget.model.addCategory(text.text);
    setState(() => problem = p);
    if (p == null) text.clear();
  }

  Future<void> remove(String c) async {
    final n = widget.model.itemsIn(c);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Remove $c?'),
        content: Text(
          n == 0
              ? 'No items use this category.'
              : 'Items in $c move to Other. Nothing is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => widget.model.removeCategory(c));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          words('Categories', 20, weight: 800),
          const SizedBox(height: 8),
          words(
            'Items are grouped by category on your list. '
            'Add your own, for example Cleaning.',
            15,
            color: muted,
          ),
          const SizedBox(height: 20),
          for (final c in widget.model.categories) tile(c),
          const SizedBox(height: 24),
          words('Add a category', 17, weight: 700),
          const SizedBox(height: 10),
          TextField(
            controller: text,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => add(),
            decoration: const InputDecoration(
              labelText: 'Category name',
              border: OutlineInputBorder(),
            ),
          ),
          if (problem != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: words(problem!, 14, color: Colors.red),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: add,
              child: words('Add this category', 17, weight: 700,
                  color: Colors.white),
            ),
          ),
        ],
      );

  Widget tile(String c) {
    final custom = widget.model.customCategories.contains(c);
    final count = widget.model.itemsIn(c);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: box(radius: 16),
      child: Row(
        children: [
          const Icon(Icons.list_alt, size: 26, color: green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(c, 17, weight: 700),
                words(count == 1 ? '1 item' : '$count items', 14, color: muted),
              ],
            ),
          ),
          if (custom)
            Tap(
              label: 'Remove $c',
              onTap: () => remove(c),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close, size: 24, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}