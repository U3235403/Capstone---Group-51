import 'package:flutter/material.dart';

import 'pilot_bridge.dart';
import 'wireframe/app.dart';
import 'wireframe/remote_model.dart';

class PilotApp extends StatelessWidget {
  const PilotApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Stage 1',
    theme: ThemeData(
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(seedColor: green),
    ),
    home: const PilotGate(),
  );
}

class PilotGate extends StatefulWidget {
  const PilotGate({super.key});
  @override
  State<PilotGate> createState() => _PilotGateState();
}

class _PilotGateState extends State<PilotGate> {
  final username = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      householdName = TextEditingController(),
      listName = TextEditingController(),
      invitation = TextEditingController();
  Map<String, dynamic>? profile;
  List<dynamic> lists = [], catalogue = [];
  String? householdId, error;
  bool busy = false, changePassword = false, local = false;
  RemoteWireframeModel? remote;
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic> body = const {},
  ]) => pilotCall('request', {'path': path, 'body': body});
  Future<void> work(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    profile = await request('/api/me');
  }

  Future<void> login() async {
    final result = await pilotCall('login', {
      'username': username.text,
      'password': password.text,
    });
    changePassword = result['mustChangePassword'] == true;
    password.clear();
    if (!changePassword) await refresh();
  }

  Future<void> choose(String hid) async {
    final result = await request('/api/households/$hid/lists/read');
    householdId = hid;
    lists = result['lists'] as List;
    catalogue = result['catalogue'] as List;
  }

  Future<void> open(String lid) async {
    final data = await pilotCall('select', {
      'householdId': householdId,
      'listId': lid,
      'catalogue': catalogue,
    });
    remote = RemoteWireframeModel()..accept(data);
  }

  @override
  void dispose() {
    for (final c in [username, password, name, householdName, listName, invitation]) {
    c.dispose();
    }
    remote?.dispose();
    super.dispose();
  }

  Widget field(TextEditingController c, String label, {bool secret = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: c,
          obscureText: secret,
          autocorrect: !secret,
          enableSuggestions: !secret,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  Widget button(String text, Future<void> Function() task) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: FilledButton(
      onPressed: busy ? null : () => work(task),
      child: Text(text),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (remote != null || local) {
      return Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      remote?.dispose();
                      remote = null;
                      local = false;
                    }),
                    child: const Text('Accounts & households'),
                  ),
                  Expanded(
                    child: Text(
                      local
                          ? 'Local only'
                          : 'Shared list · refreshes every 10s',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: WireframeApp(model: remote)),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Stage 1 pilot')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                  semanticsLabel: error,
                ),
              if (busy) const LinearProgressIndicator(),
              if (changePassword) ...[
                const Text('Change your temporary password'),
                field(password, 'Current password', secret: true),
                field(name, 'New password (12–128 characters)', secret: true),
                button('Change password', () async {
                  await request('/api/password', {
                    'currentPassword': password.text,
                    'newPassword': name.text,
                  });
                  password.clear();
                  name.clear();
                  changePassword = false;
                  profile = null;
                }),
              ] else if (profile == null) ...[
                const Text(
                  'Sign in with the username and password supplied by your pilot administrator.',
                ),
                field(username, 'Username'),
                field(password, 'Password', secret: true),
                button('Sign in', login),
                const Text(
                  'Forgot your password? Contact your pilot administrator.',
                ),
                TextButton(
                  onPressed: () => setState(() => local = true),
                  child: const Text('Use local-only shopping list'),
                ),
              ] else ...[
                Text('Welcome, ${profile!['displayName']}'),
                button('Sign out', () async {
                  await pilotCall('logout', {});
                  profile = null;
                  householdId = null;
                  lists = [];
                }),
                if (profile!['pilotAdmin'] == true)
                  button('Pilot administration', () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PilotAdmin(),
                      ),
                    );
                  }),
                const Text('Your households'),
                for (final h in profile!['households'] as List)
                  button(
                    '${h['name']} (${h['role']})',
                    () => choose(h['id'] as String),
                  ),
                field(householdName, 'New household name'),
                button('Create household', () async {
                  await request('/api/households', {
                    'name': householdName.text,
                    'requestId':
                        '${DateTime.now().microsecondsSinceEpoch}-household',
                  });
                  householdName.clear();
                  await refresh();
                }),
                field(invitation, 'Invitation token'),
                button('Join household', () async {
                  await request('/api/invitations/redeem', {
                    'token': invitation.text,
                  });
                  invitation.clear();
                  await refresh();
                }),
                if (householdId != null) ...[
                  const Divider(),
                  const Text('Shopping lists'),
                  SelectableText('Household ID: $householdId'),
                  for (final l in lists)
                    button(l['name'] as String, () => open(l['id'] as String)),
                  field(listName, 'New list name'),
                  button('Create list', () async {
                    await request('/api/households/$householdId/lists', {
                      'name': listName.text,
                      'requestId':
                          '${DateTime.now().microsecondsSinceEpoch}-list',
                    });
                    listName.clear();
                    await choose(householdId!);
                  }),
                  field(username, 'Invite username (member)'),
                  button('Create member invitation', () async {
                    final r = await request(
                      '/api/households/$householdId/invitations',
                      {'username': username.text, 'role': 'member'},
                    );
                    if (context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text(
                            'Share this one-time invitation privately',
                          ),
                          content: SelectableText(r['token'] as String),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      );
                    }
                  }),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PilotAdmin extends StatefulWidget {
  const PilotAdmin({super.key});
  @override
  State<PilotAdmin> createState() => _PilotAdminState();
}

class _PilotAdminState extends State<PilotAdmin> {
  final username = TextEditingController(),
      display = TextEditingController(),
      password = TextEditingController(),
      household = TextEditingController();
  String status = '';
  bool busy = false;
  Future<void> submit(String path, Map<String, dynamic> body) async {
    setState(() => busy = true);
    try {
      await pilotCall('request', {'path': path, 'body': body});
      if (!mounted) return;
      password.clear();
      setState(() => status = 'Saved.');
    } catch (e) {
      if (mounted) setState(() => status = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    username.dispose();
    display.dispose();
    password.dispose();
    household.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pilot administration')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(status),
        TextField(
          controller: username,
          decoration: const InputDecoration(labelText: 'Participant username'),
        ),
        TextField(
          controller: display,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Temporary password (12–128 characters)',
          ),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => submit('/api/admin/accounts', {
                  'username': username.text,
                  'displayName': display.text,
                  'password': password.text,
                }),
          child: const Text('Create participant'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => submit('/api/admin/reset', {
                  'username': username.text,
                  'temporaryPassword': password.text,
                }),
          child: const Text('Reset participant password'),
        ),
        TextField(
          controller: household,
          decoration: const InputDecoration(labelText: 'Household ID'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => submit(
                  '/api/admin/households/${household.text}/caregiver',
                  {'username': username.text, 'enabled': true},
                ),
          child: const Text('Assign caregiver'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => submit(
                  '/api/admin/households/${household.text}/caregiver',
                  {'username': username.text, 'enabled': false},
                ),
          child: const Text('Remove caregiver'),
        ),
      ],
    ),
  );
}
