import 'dart:async';

import 'package:flutter/material.dart';

import 'app_model.dart';
import 'shopping_list_page.dart';
import 'theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.model});
  final AppModel? model;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppModel model = widget.model ?? AppModel();
  final navigator = GlobalKey<NavigatorState>();
  late final Timer timer;
  DateTime lastActivity = DateTime.now();
  bool locking = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (model.unlocked &&
          !locking &&
          DateTime.now().difference(lastActivity).inMinutes >=
              model.autoLockMinutes) {
        locking = true;
        try {
          await model.lock();
          navigator.currentState?.popUntil((r) => r.isFirst);
        } catch (_) {}
        locking = false;
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    if (widget.model == null) model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final base = AppTheme.light;
      final theme = model.highContrast
          ? base.copyWith(
              scaffoldBackgroundColor: Colors.white,
              colorScheme: base.colorScheme.copyWith(
                primary: const Color(0xFF17401F),
                onSurface: Colors.black,
                outline: Colors.black,
              ),
              textTheme: base.textTheme.apply(
                bodyColor: Colors.black,
                displayColor: Colors.black,
              ),
            )
          : base;
      return Listener(
        onPointerDown: (_) => lastActivity = DateTime.now(),
        onPointerSignal: (_) => lastActivity = DateTime.now(),
        child: Focus(
          onKeyEvent: (node, event) {
            lastActivity = DateTime.now();
            return KeyEventResult.ignored;
          },
          child: MaterialApp(
            navigatorKey: navigator,
            title: 'Stage 1',
            debugShowCheckedModeBanner: false,
            theme: theme,
            themeAnimationDuration: model.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  MediaQuery.textScalerOf(context).scale(1) * model.textScale,
                ),
                disableAnimations:
                    model.reduceMotion ||
                    MediaQuery.of(context).disableAnimations,
              ),
              child: child!,
            ),
            home: model.unlocked
                ? ShoppingListPage(model: model)
                : UnlockPage(model: model),
          ),
        ),
      );
    },
  );
}

class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key, required this.model});
  final AppModel model;
  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final password = TextEditingController(), confirm = TextEditingController();
  bool? exists;
  bool device = false, busy = false, show = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final status = await widget.model.operation('status', {});
      if (mounted) {
        setState(() {
          exists = status['exists'] == true;
          device = status['deviceUnlock'] == true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit({bool useDevice = false}) async {
    if (busy || exists == null) return;
    if (!useDevice &&
        (password.text.isEmpty ||
            !exists! &&
                (password.text.length < 12 || password.text != confirm.text))) {
      setState(
        () => error = exists!
            ? 'Enter your passphrase.'
            : 'Use at least 12 characters and enter the same passphrase twice.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.model.unlock(
        password.text,
        create: !exists!,
        device: useDevice,
      );
      password.clear();
      confirm.clear();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stage 1')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 64,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              exists == false ? 'Set up your local account' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your household lists stay encrypted in this browser on this device. No cloud account is needed.',
            ),
            const SizedBox(height: 24),
            if (exists == null && error == null)
              const LinearProgressIndicator(),
            if (exists != null) ...[
              TextField(
                controller: password,
                obscureText: !show,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => exists! ? submit() : null,
                decoration: InputDecoration(
                  labelText: exists! ? 'Passphrase' : 'Create passphrase',
                  suffixIcon: IconButton(
                    tooltip: show ? 'Hide passphrase' : 'Show passphrase',
                    onPressed: () => setState(() => show = !show),
                    icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              if (!exists!) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirm passphrase',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use at least 12 characters. Keep it safe: there is no online password reset. Clearing browser data removes these lists.',
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  busy
                      ? 'Please wait…'
                      : exists!
                      ? 'Unlock my lists'
                      : 'Create local account',
                ),
              ),
              if (device) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => submit(useDevice: true),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use device unlock'),
                ),
              ],
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Stage 1 • Offline edition',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
