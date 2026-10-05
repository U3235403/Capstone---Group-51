import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shopping_item.dart';
import 'model.dart';

const paper = Color(0xfff9f8f6),
    ink = Color(0xff1a1917),
    green = Color(0xff4f6f52);
const line = Color(0xffe6e3df),
    muted = Color(0xff6b6661),
    pale = Color(0xffecefe6);
const label = Color(0xff9ca3af),
    amber = Color(0xffd97706),
    yellow = Color(0xfffef3c7);
TextStyle type(double size, [int weight = 400, Color color = ink]) => TextStyle(
  fontFamily: 'Inter',
  letterSpacing: 0,
  fontSize: size,
  fontWeight: FontWeight.values[weight ~/ 100 - 1],
  color: color,
  height: 1.21,
  fontVariations: const [FontVariation('opsz', 14)],
);
Widget words(
  String value,
  double size, {
  int weight = 400,
  Color color = ink,
  TextAlign? align,
  bool strike = false,
}) => Text(
  value,
  textAlign: align,
  style: type(
    size,
    weight,
    color,
  ).copyWith(decoration: strike ? TextDecoration.lineThrough : null),
);
Widget asset(String screen, String name, double w, [double? h]) =>
    ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/figma/$screen-img$name.svg',
        width: w,
        height: h ?? w,
        fit: BoxFit.contain,
      ),
    );

class FrameDecoration extends BoxDecoration {
  const FrameDecoration({super.color, super.border, super.borderRadius});
  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;
}

BoxDecoration box({
  Color color = Colors.white,
  double radius = 16,
  Color? border = line,
  double thickness = 1,
}) => FrameDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: border == null ? null : Border.all(color: border, width: thickness),
);

class Tap extends StatelessWidget {
  const Tap({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.checked,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? checked;
  @override
  Widget build(BuildContext context) => Semantics(
    button: checked == null,
    checked: checked,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    ),
  );
}

class WireframeApp extends StatelessWidget {
  const WireframeApp({super.key, this.model, this.initialScreen = 'list'});
  final WireframeModel? model;
  final String initialScreen;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Stage 1',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Inter',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Inter'),
      splashFactory: NoSplash.splashFactory,
    ),
    home: WireframeHome(model: model, initialScreen: initialScreen),
  );
}

class WireframeHome extends StatefulWidget {
  const WireframeHome({super.key, this.model, required this.initialScreen});
  final WireframeModel? model;
  final String initialScreen;
  @override
  State<WireframeHome> createState() => _WireframeHomeState();
}

class _WireframeHomeState extends State<WireframeHome> {
  late final WireframeModel model = widget.model ?? WireframeModel();
  late String screen = widget.initialScreen;
  String selected = 'Fresh Whole Milk', category = 'All';
  final search = TextEditingController();
  ShoppingItem? editing;
  int quantity = 2, maximum = 2;
  bool block = false, warning = false, listening = false;
  String? voiceError, notice;
  @override
  void initState() {
    super.initState();
    if (screen == 'warning') {
      screen = 'list';
      warning = true;
      quantity = 10;
    }
    model.addListener(changed);
    if (!model.ready) model.load();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(changed);
    if (widget.model == null) model.dispose();
    search.dispose();
    super.dispose();
  }

  void go(String next) {
    setState(() {
      screen = next;
      notice = null;
    });
  }

  void details(String name, [ShoppingItem? item]) {
    setState(() {
      selected = name;
      editing = item;
      quantity = item?.quantity ?? (name == 'Fresh Whole Milk' ? 2 : 1);
      screen = 'details';
      notice = null;
    });
  }

  void settings() {
    setState(() {
      selected = 'Fresh Whole Milk';
      maximum = model.rules[selected]?.maximum ?? 2;
      block = model.rules[selected]?.block ?? false;
      screen = 'safety';
    });
  }

  void add({bool confirmed = false}) {
    if (model.exceeds(selected, quantity, exceptId: editing?.id) &&
        !confirmed) {
      setState(() {
        warning = true;
        screen = 'list';
      });
      return;
    }
    if (model.put(selected, quantity, edit: editing, confirmed: confirmed)) {
      setState(() {
        warning = false;
        screen = 'list';
      });
    }
  }

  Future<void> voice() async {
    setState(() {
      listening = true;
      voiceError = null;
    });
    try {
      final result = await model.operation('voice', {});
      if (mounted && screen == 'catalogue') {
        setState(() {
          search.text = result['text'] as String;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          voiceError = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          listening = false;
        });
      }
    }
  }

  String get source => switch (screen) {
    'catalogue' => 'addContext',
    'details' => '28-111',
    'safety' => '2-348',
    _ => model.items.isEmpty ? '2-126' : '2-63',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ink,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 411),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: ColoredBox(
            color: paper,
            child: Stack(
              children: [
                Opacity(
                  opacity: warning ? .55 : 1,
                  child: AbsorbPointer(
                    absorbing: warning,
                    child: Column(
                      children: [
                        statusBar(),
                        header(),
                        if (model.error != null || notice != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Semantics(
                              liveRegion: true,
                              child: Column(
                                children: [
                                  words(
                                    model.error ?? notice!,
                                    14,
                                    color: const Color(0xffb91c1c),
                                  ),
                                  if (model.error != null)
                                    TextButton(
                                      onPressed: () {
                                        if (model.ready) {
                                          model.save();
                                        } else {
                                          model.load();
                                        }
                                      },
                                      child: const Text('Retry'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: !model.ready
                              ? Center(
                                  child: model.error == null
                                      ? const CircularProgressIndicator()
                                      : const SizedBox(),
                                )
                              : switch (screen) {
                                  'catalogue' => catalogueBody(),
                                  'details' => detailBody(),
                                  'safety' => safetyBody(),
                                  _ => listBody(),
                                },
                        ),
                        if (model.ready && screen == 'list') listFooter(),
                        if (model.ready && screen == 'safety') safetyFooter(),
                        ExcludeSemantics(
                          child: SizedBox(
                            height: 29,
                            child: Center(
                              child: Container(
                                width: 140,
                                height: 5,
                                decoration: box(
                                  color: ink,
                                  radius: 100,
                                  border: null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (warning) warningCard(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget statusBar() => ExcludeSemantics(
    child: SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            words('9:41', 15, weight: 600),
            Row(
              children: [
                asset(source, 'IosSignal', 20),
                const SizedBox(width: 6),
                asset(source, 'IosWifiSignal', 20),
                const SizedBox(width: 6),
                asset(source, 'IosBatteryFull', 28, 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    decoration: const FrameDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (screen == 'safety') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: box(color: yellow, radius: 8, border: null),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                asset(source, 'Lock', 16),
                const SizedBox(width: 6),
                words('CAREGIVER MODE', 14, weight: 700, color: amber),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: words(
                switch (screen) {
                  'catalogue' => 'Add New Item',
                  'details' => 'Item Details',
                  'safety' => 'Set Safety Limit',
                  _ => 'My Shopping List',
                },
                28,
                weight: 800,
              ),
            ),
            if (screen != 'list')
              Tap(
                onTap: () {
                  if (screen == 'catalogue') {
                    model.operation('cancelVoice', {});
                  }
                  go('list');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: box(
                    radius: 8,
                    color: screen == 'safety' ? paper : Colors.white,
                  ),
                  child: Row(
                    children: [
                      asset(source, 'ArrowLeft', 16),
                      const SizedBox(width: 6),
                      words('Go Back', 16, weight: 700),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
  Widget action(
    String text,
    VoidCallback onTap, {
    Color color = green,
    Color textColor = Colors.white,
    String? icon,
    String? assetSource,
    bool outline = false,
    double height = 56,
    double radius = 28,
    double size = 18,
  }) => Tap(
    onTap: onTap,
    child: Container(
      height: height,
      width: double.infinity,
      decoration: box(
        color: color,
        radius: radius,
        border: outline ? line : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            asset(assetSource ?? source, icon, 20),
            const SizedBox(width: 8),
          ],
          words(text, size, weight: 800, color: textColor),
        ],
      ),
    ),
  );
  Widget listFooter() => Container(
    padding: const EdgeInsets.all(20),
    decoration: const FrameDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: Column(
      children: [
        action(model.items.isEmpty ? 'Add First Item' : 'Add New Item', () {
          search.clear();
          category = 'All';
          go('catalogue');
        }, icon: 'Plus'),
        const SizedBox(height: 16),
        Tap(
          onTap: settings,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                asset(source, 'Settings', 18),
                const SizedBox(width: 6),
                words('Caregiver Settings', 16, weight: 700, color: muted),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Widget listBody() {
    if (model.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              words(
                'Your list is empty',
                22,
                weight: 800,
                align: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 280,
                child: words(
                  'Tap the big green button below to start adding things to buy.',
                  16,
                  weight: 500,
                  color: muted,
                  align: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final buying = model.items.where((i) => !i.purchased).toList(),
        purchased = model.items.where((i) => i.purchased).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (buying.isNotEmpty) ...[
          words('TO BUY', 12, weight: 700, color: label),
          const SizedBox(height: 16),
          for (final i in buying) ...[itemRow(i), const SizedBox(height: 16)],
        ],
        if (purchased.isNotEmpty) ...[
          words('PURCHASED', 12, weight: 700, color: label),
          const SizedBox(height: 12),
          for (final i in purchased) ...[
            itemRow(i),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  Widget limitBadge(int limit, {bool small = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: box(color: yellow, radius: 6, border: null),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        asset(small ? 'addContext' : '2-63', 'Lock', small ? 12 : 14),
        const SizedBox(width: 4),
        words('Limit: $limit', small ? 11 : 13, weight: 700, color: amber),
      ],
    ),
  );
  Widget itemRow(ShoppingItem item) => Container(
    padding: const EdgeInsets.all(18),
    decoration: box(),
    child: Row(
      children: [
        Tap(
          label: 'Mark ${item.name} ${item.purchased ? 'to buy' : 'purchased'}',
          checked: item.purchased,
          onTap: () {
            if (!model.toggle(item)) {
              setState(
                () => notice = 'The quantity limit prevents returning this item to your list.',
              );
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: box(
              color: item.purchased ? green : pale,
              radius: 12,
              border: green,
              thickness: item.purchased ? 0 : 3,
            ),
            child: item.purchased
                ? Center(child: asset('2-63', 'Check', 24))
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              words(
                item.name,
                20,
                weight: 700,
                color: item.purchased ? muted : ink,
                strike: item.purchased,
              ),
              const SizedBox(height: 2),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  words('Qty: ${item.quantity}', 16, weight: 600, color: muted),
                  if (!item.purchased && model.rules[item.name] != null)
                    limitBadge(model.rules[item.name]!.maximum),
                ],
              ),
            ],
          ),
        ),
        Tap(
          label: 'Edit ${item.name}',
          onTap: () => details(item.name, item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: words('Edit', 16, weight: 700, color: green),
          ),
        ),
      ],
    ),
  );
  Widget catalogueBody() {
    final entries = groceries.entries
        .where(
          (e) =>
              (category == 'All' || category == e.value) &&
              e.key.toLowerCase().contains(search.text.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          height: 54,
          decoration: box(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Figma's search artwork is 100x100 clipped into its 20x20 slot.
              SizedBox(
                width: 20,
                height: 20,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: 100,
                    maxWidth: 100,
                    minHeight: 100,
                    maxHeight: 100,
                    child: asset('addContext', 'Search', 100),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  style: type(18, 500),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search for groceries (e.g. Milk)',
                    hintStyle: type(18, 500, label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Tap(
                label: 'Voice search',
                onTap: listening ? null : voice,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(child: asset('addContext', 'Mic', 16)),
                ),
              ),
            ],
          ),
        ),
        if (voiceError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: words(voiceError!, 14, color: muted),
            ),
          ),
        if (listening) words('Listening…', 14, color: muted),
        const SizedBox(height: 16),
        words('CATEGORIES', 12, weight: 700, color: label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in [
              'All',
              'Produce',
              'Dairy & Eggs',
              'Bakery',
              'Pantry',
            ])
              Tap(
                onTap: () => setState(() => category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: box(
                    color: category == c ? green : Colors.white,
                    radius: 12,
                    border: category == c ? null : line,
                  ),
                  child: words(
                    c,
                    14,
                    weight: 700,
                    color: category == c ? Colors.white : muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        words('COMMONLY ADDED', 12, weight: 700, color: label),
        const SizedBox(height: 12),
        for (final e in entries) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: box(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      words(e.key, 18, weight: 700),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          words(e.value, 14, weight: 600, color: muted),
                          if (model.rules[e.key] != null)
                            limitBadge(
                              model.rules[e.key]!.maximum,
                              small: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Tap(
                  label: 'Add ${e.key}',
                  onTap: () => details(e.key),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: box(color: pale, radius: 8, border: null),
                    child: Center(child: asset('addContext', 'Plus', 18)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (entries.isEmpty) words('No matching items', 16, color: muted),
      ],
    );
  }

  Widget stepper(int value, ValueChanged<int> update, {bool safety = false}) =>
      Container(
        padding: EdgeInsets.all(safety ? 12 : 16),
        decoration: box(radius: safety ? 16 : 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            stepButton('Minus', () => update(math.max(1, value - 1)), safety),
            words('$value', safety ? 28 : 36, weight: 800),
            stepButton('Plus', () => update(math.min(999, value + 1)), safety),
          ],
        ),
      );
  Widget stepButton(String icon, VoidCallback press, bool safety) => Tap(
    label: icon == 'Minus' ? 'Decrease quantity' : 'Increase quantity',
    onTap: press,
    child: Container(
      width: 56,
      height: 56,
      decoration: box(color: pale, radius: 28, border: green, thickness: 2),
      child: Center(child: asset(safety ? '2-348' : '28-111', icon, 24)),
    ),
  );
  Widget detailBody() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: box(radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            words('SELECTED ITEM', 14, weight: 700, color: label),
            const SizedBox(height: 12),
            words(selected, 22, weight: 800),
            const SizedBox(height: 4),
            words(
              '${editing?.category ?? groceries[selected] ?? 'Produce'} Section',
              15,
              weight: 600,
              color: muted,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      words('QUANTITY TO ADD', 16, weight: 700, color: muted),
      const SizedBox(height: 12),
      stepper(quantity, (n) => setState(() => quantity = n)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: box(color: yellow, border: null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            words('HEADS UP...', 15, weight: 800, color: amber),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: type(15, 400, amber).copyWith(height: 1.4),
                children: [
                  const TextSpan(text: 'You usually buy '),
                  TextSpan(
                    text:
                        '${model.rules[selected]?.maximum ?? editing?.quantity ?? 1} $selected',
                    style: type(15, 700, amber).copyWith(height: 1.4),
                  ),
                  const TextSpan(text: '. '),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 44),
      action('Add to Shopping List', () => add(), icon: 'Check'),
      const SizedBox(height: 12),
      action(
        'Cancel',
        () => go('list'),
        color: Colors.white,
        textColor: muted,
        outline: true,
      ),
    ],
  );
  Widget safetyBody() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      words('CONFIGURE LIMITS FOR', 16, weight: 700, color: muted),
      const SizedBox(height: 6),
      words(selected, 22, weight: 800),
      const SizedBox(height: 24),
      words('MAXIMUM QUANTITY ALLOWED', 16, weight: 700, color: muted),
      const SizedBox(height: 10),
      stepper(maximum, (n) => setState(() => maximum = n), safety: true),
      const SizedBox(height: 24),
      words('WHEN THE LIMIT IS EXCEEDED', 16, weight: 700, color: muted),
      const SizedBox(height: 10),
      ruleChoice(
        false,
        'Warn Only',
        'Show a friendly notice but allow addition',
      ),
      const SizedBox(height: 10),
      ruleChoice(
        true,
        'Block Addition',
        'Do not allow adding past this amount',
      ),
    ],
  );
  Widget ruleChoice(bool value, String title, String subtitle) => Tap(
    label: title,
    checked: block == value,
    onTap: () => setState(() => block = value),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: box(
        color: block == value ? pale : Colors.white,
        border: block == value ? green : line,
        thickness: block == value ? 2 : 1,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: box(
              color: block == value ? green : Colors.white,
              radius: 12,
              border: block == value ? null : line,
            ),
            child: block == value
                ? Center(child: asset('2-348', 'Check', 14))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(title, 16, weight: 800),
                const SizedBox(height: 2),
                words(subtitle, 14, color: muted),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget safetyFooter() => Container(
    padding: const EdgeInsets.all(20),
    decoration: const FrameDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: Column(
      children: [
        action('Save Safety Limit', () {
          model.setRule(selected, SafetyRule(maximum, block: block));
          go('list');
        }, icon: 'Check1'),
        const SizedBox(height: 12),
        action('Delete Limit Rule', () {
          model.setRule(selected, null);
          go('list');
        }, color: const Color(0xffdc2626)),
      ],
    ),
  );
  Widget warningCard() {
    final blocked = model.rules[selected]?.block ?? false;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Colors.transparent),
            Align(
              alignment: const Alignment(0, -.081),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(20),
                  decoration: box(radius: 24).copyWith(
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x1a000000),
                        offset: Offset(0, 12),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: box(
                          color: const Color(0xfff3f4f6),
                          radius: 24,
                          border: null,
                        ),
                        child: Center(
                          child: asset('17-206', 'AlertTriangle', 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                      words('Add $quantity × $selected?', 16, weight: 700),
                      const SizedBox(height: 6),
                      Text(
                        blocked
                            ? 'The quantity limit is ${model.rules[selected]!.maximum}. Change the amount to stay within the limit.'
                            : 'The quantity limit is ${model.rules[selected]!.maximum}. You can change the amount or add $quantity.',
                        style: type(14, 400, muted).copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Tap(
                              onTap: () => setState(() {
                                warning = false;
                                screen = 'details';
                              }),
                              child: Container(
                                height: 52,
                                decoration: box(
                                  radius: 16,
                                  border: green,
                                  thickness: 2,
                                ),
                                child: Center(
                                  child: words(
                                    'Change amount',
                                    16,
                                    weight: 800,
                                    color: green,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!blocked) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: action(
                                'Yes, add $quantity',
                                () => add(confirmed: true),
                                height: 52,
                                radius: 16,
                                size: 16,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
