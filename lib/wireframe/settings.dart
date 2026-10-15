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
        if (model.isCarer)
          row(Icons.logout, 'Sign out of this phone', () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Sign out of this phone?'),
                content: const Text(
                  'The person you help will need to sign in again.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Stay signed in'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Sign out'),
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