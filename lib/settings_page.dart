import 'package:flutter/material.dart';

import 'app_model.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.model});
  final AppModel model;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final household = TextEditingController(text: widget.model.household);
  final member = TextEditingController();
  String? message;
  bool busy = false;
  @override
  void dispose() {
    household.dispose();
    member.dispose();
    super.dispose();
  }

  Future<void> device(bool enable) async {
    setState(() => busy = true);
    try {
      await widget.model.setDeviceUnlock(enable);
      if (mounted) {
        setState(
          () => message = enable
              ? 'Device unlock enabled. Keep your passphrase as a fallback.'
              : 'Device unlock disabled.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      return Scaffold(
        appBar: AppBar(title: const Text('Household & settings')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Your household',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Members are names for assigning shopping on this device. No invitations or data are sent online. Everyone using this unlocked account can see its lists.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: household,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Household name',
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (household.text.trim().isEmpty) {
                        setState(() => message = 'Enter a household name.');
                        return;
                      }
                      model.household = household.text.trim();
                      model.changed();
                      setState(() => message = 'Household name updated.');
                    },
                    child: const Text('Save household name'),
                  ),
                  const SizedBox(height: 20),
                  ...model.members.map(
                    (m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m),
                      trailing: IconButton(
                        tooltip: 'Remove $m',
                        onPressed: model.members.length <= 1
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: Text('Remove $m?'),
                                    content: const Text(
                                      'Their assigned items will become unassigned.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Keep member'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Remove member'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) model.removeMember(m);
                              },
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ),
                  ),
                  TextField(
                    controller: member,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'New member name',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final name = member.text.trim();
                      if (name.isEmpty ||
                          ['All', 'Unassigned'].contains(name) ||
                          model.members.any(
                            (m) => m.toLowerCase() == name.toLowerCase(),
                          )) {
                        setState(
                          () => message = 'Enter a unique member name (not All or Unassigned).',
                        );
                        return;
                      }
                      model.members.add(name);
                      member.clear();
                      model.changed();
                      setState(() => message = 'Member added.');
                    },
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Add member'),
                  ),
                  const Divider(height: 40),
                  Text(
                    'Accessible display',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<double>(
                    initialValue: model.textScale,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Text size'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Standard')),
                      DropdownMenuItem(value: 1.25, child: Text('Large')),
                      DropdownMenuItem(value: 1.5, child: Text('Extra large')),
                    ],
                    onChanged: (v) {
                      model.textScale = v!;
                      model.changed();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Higher contrast'),
                    value: model.highContrast,
                    onChanged: (v) {
                      model.highContrast = v;
                      model.changed();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce motion'),
                    value: model.reduceMotion,
                    onChanged: (v) {
                      model.reduceMotion = v;
                      model.changed();
                    },
                  ),
                  const Divider(height: 40),
                  Text(
                    'Local security',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: model.autoLockMinutes,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lock after inactivity',
                    ),
                    items: [2, 5, 10, 30]
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text('$m minutes'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      model.autoLockMinutes = v!;
                      model.changed();
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Device unlock uses your platform authenticator, which may use a fingerprint, face or device PIN. It requires offline encrypted-key support (WebAuthn PRF). Availability depends on your browser and device.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => device(!model.deviceUnlock),
                    icon: const Icon(Icons.fingerprint),
                    label: Text(
                      busy
                          ? 'Waiting for device…'
                          : model.deviceUnlock
                          ? 'Disable device unlock'
                          : 'Enable device unlock',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Voice entry only uses an installed on-device English speech model. No cloud fallback or model download is performed.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reminders appear while the app is open and unlocked, including overdue reminders after you return. They do not send notifications when the app is closed.',
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(liveRegion: true, child: Text(message!)),
                    ),
                  if (model.saveError != null)
                    Text('Not saved: ${model.saveError}'),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
