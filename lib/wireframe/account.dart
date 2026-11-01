import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'model.dart';

// ---------------------------------------------------------------------------
// Pilot stand-ins for the SMS check.
// TODO: connect these to an SMS service (e.g. Firebase phone auth or Twilio
// Verify) through the backend. Currently any number is accepted and the code
// is always 123456.
// ---------------------------------------------------------------------------
Future<bool> sendLoginCode(String phone) async => true;
Future<bool> checkLoginCode(String phone, String code) async => code == '123456';

// One-time account setup, shown on first launch.
// The account is saved afterwards, so sign-in is not repeated.
class AccountSetup extends StatefulWidget {
  const AccountSetup({super.key, required this.model});
  final WireframeModel model;
  @override
  State<AccountSetup> createState() => _AccountSetupState();
}

class _AccountSetupState extends State<AccountSetup> {
  // 0 welcome, 1 who, 2 phone, 3 code, 4 name, 5 link, 6 list look, 7 done
  int step = 0;
  String role = '';
  // List look: picture tiles (false) or a plain list (true).
  bool plainChoice = false;
  String? problem;
  bool busy = false;
  final phone = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  final carerCode = TextEditingController();

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    name.dispose();
    carerCode.dispose();
    super.dispose();
  }

  String get cleanPhone => phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
  int get digitCount => cleanPhone.replaceAll('+', '').length;

  void go(int next) {
    // Release the old text box and autofill session before changing step.
    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext(shouldSave: false);
    setState(() {
      problem = null;
      step = next;
    });
  }

  Future<void> sendCode() async {
    if (digitCount < 8 || digitCount > 15) {
      setState(() => problem = 'Please check your number. It looks too short.');
      return;
    }
    setState(() {
      busy = true;
      problem = null;
    });
    final ok = await sendLoginCode(cleanPhone);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) {
        code.clear();
        step = 3;
      } else {
        problem = 'We could not send the message. Please try again.';
      }
    });
  }

  Future<void> checkCode() async {
    if (code.text.length != 6) {
      setState(() => problem = 'Please type all 6 numbers.');
      return;
    }
    setState(() {
      busy = true;
      problem = null;
    });
    final ok = await checkLoginCode(cleanPhone, code.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) {
        step = 4;
      } else {
        problem = 'That code is not right. Please try again.';
      }
    });
  }

  void finish() {
    TextInput.finishAutofillContext();
    widget.model.plainList = plainChoice;
    widget.model.signIn(
      role: role,
      phone: phone.text.trim(),
      name: name.text.trim(),
      linkedTo: carerCode.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ink,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: ColoredBox(
            color: paper,
            child: AutofillGroup(
              child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
              children: [
                if (step > 0 && step < 7) ...[backButton(), const SizedBox(height: 28)],
                ...switch (step) {
                  0 => welcome(),
                  1 => who(),
                  2 => phoneStep(),
                  3 => codeStep(),
                  4 => nameStep(),
                  5 => linkStep(),
                  6 => layoutStep(),
                  _ => doneStep(),
                },
              ],
            ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget backButton() => Align(
    alignment: Alignment.centerLeft,
    child: Tap(
      label: 'Go back',
      onTap: () => go(step == 5 && role == 'carer' ? 4 : step - 1),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 22, 12),
        decoration: box(radius: 28, color: Colors.white),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, size: 22, color: ink),
            const SizedBox(width: 10),
            words('Go Back', 16, weight: 700),
          ],
        ),
      ),
    ),
  );

  Widget heading(String text, [String? sub]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      words(text, 30, weight: 800),
      if (sub != null) ...[
        const SizedBox(height: 14),
        Text(sub, style: type(17, 500, muted).copyWith(height: 1.4)),
      ],
      const SizedBox(height: 32),
    ],
  );

  Widget bigButton(String text, VoidCallback? onTap, {bool outline = false}) => Tap(
    label: text,
    onTap: busy ? null : onTap,
    child: Container(
      height: 84,
      alignment: Alignment.center,
      decoration: box(
        color: outline ? Colors.white : green,
        radius: 42,
        border: outline ? green : null,
        thickness: 2,
      ),
      child: words(
        busy && !outline ? 'Please wait…' : text,
        20,
        weight: 800,
        color: outline ? green : Colors.white,
      ),
    ),
  );

  Widget field(
    TextEditingController c,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    TextCapitalization caps = TextCapitalization.none,
    bool numbers = false,
    ValueChanged<String>? onChanged,
    VoidCallback? onDone,
    List<String>? hints,
  }) => Container(
    height: 84,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    alignment: Alignment.center,
    decoration: box(radius: 22, border: green, thickness: 2),
    child: TextField(
      // A key per field makes each step get a fresh text box, so the
      // keyboard does not stay attached to the previous step's box.
      key: ValueKey(c),
      autofocus: true,
      controller: c,
      autofillHints: hints,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: caps,
      autocorrect: !numbers,
      enableSuggestions: !numbers,
      textAlign: numbers ? TextAlign.center : TextAlign.start,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: (_) => onDone?.call(),
      style: type(numbers ? 30 : 20, 700).copyWith(
        letterSpacing: numbers ? 8 : 0,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: type(numbers ? 24 : 18, 500, label),
        counterText: '',
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  Widget problemText() => problem == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Semantics(
            liveRegion: true,
            child: words(problem!, 16, weight: 600, color: const Color(0xffb91c1c)),
          ),
        );

  List<Widget> welcome() => [
    const SizedBox(height: 40),
    Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: box(color: pale, radius: 75, border: null),
        child: const Icon(Icons.shopping_cart_outlined, size: 76, color: green),
      ),
    ),
    const SizedBox(height: 40),
    Center(child: words('Welcome', 38, weight: 800)),
    const SizedBox(height: 16),
    Text(
      'Let us set up your shopping list. It only takes a minute, and you only need to do it once.',
      textAlign: TextAlign.center,
      style: type(17, 500, muted).copyWith(height: 1.45),
    ),
    const SizedBox(height: 56),
    bigButton('Get started', () => go(1)),
  ];

  Widget roleCard(String value, IconData icon, String title, String sub) => Tap(
    label: title,
    onTap: () => setState(() {
      role = value;
      step = 2;
      problem = null;
    }),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: box(radius: 24, border: role == value ? green : line, thickness: 2),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: box(color: pale, radius: 34, border: null),
            child: Icon(icon, size: 34, color: green),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(title, 20, weight: 800),
                const SizedBox(height: 6),
                words(sub, 15, weight: 500, color: muted),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> who() => [
    heading('Who is using this phone?'),
    roleCard(
      'user',
      Icons.person_outline,
      'I am shopping for myself',
      'My own shopping list',
    ),
    const SizedBox(height: 22),
    roleCard(
      'carer',
      Icons.favorite_border,
      'I am helping someone',
      'I can set safety limits',
    ),
  ];

  List<Widget> phoneStep() => [
    heading(
      'What is your mobile number?',
      'We will send you a text message with a 6 number code.',
    ),
    field(
      phone,
      'Your mobile number',
      keyboard: TextInputType.phone,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
      numbers: false,
      hints: const [AutofillHints.telephoneNumber],
      onDone: sendCode,
    ),
    problemText(),
    const SizedBox(height: 32),
    bigButton('Send my code', sendCode),
  ];

  List<Widget> codeStep() => [
    heading(
      'Type your code',
      'We sent a text message to ${phone.text.trim()}. Type the 6 numbers here.',
    ),
    field(
      code,
      '------',
      keyboard: TextInputType.number,
      formatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      numbers: true,
      hints: const [AutofillHints.oneTimeCode],
      onChanged: (v) {
        if (v.length == 6) checkCode();
      },
      onDone: checkCode,
    ),
    problemText(),
    const SizedBox(height: 32),
    bigButton('Next', checkCode),
    const SizedBox(height: 22),
    bigButton('Send me a new code', sendCode, outline: true),
    const SizedBox(height: 22),
    Center(
      child: words(
        'Trial version: the code is 123456',
        14,
        color: label,
      ),
    ),
  ];

  List<Widget> nameStep() => [
    heading('What should we call you?'),
    field(
      name,
      'Your first name',
      caps: TextCapitalization.words,
      hints: const [AutofillHints.givenName],
      onDone: nameNext,
    ),
    problemText(),
    const SizedBox(height: 32),
    bigButton('Next', nameNext),
  ];

  void nameNext() {
    if (name.text.trim().isEmpty) {
      setState(() => problem = 'Please type your name.');
      return;
    }
    go(role == 'carer' ? 5 : 5);
  }

  List<Widget> linkStep() => role == 'carer'
      ? [
          heading(
            'Your link code',
            'Give this code to the person you are helping. They type it in on their phone to link to you.',
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            decoration: box(color: pale, radius: 24, border: null),
            child: words(
              widget.model.linkCodeFor(cleanPhone),
              46,
              weight: 800,
              color: green,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'You can find this code again in Settings.',
            style: type(15, 500, muted),
          ),
          const SizedBox(height: 40),
          bigButton('Next', () => go(6)),
        ]
      : [
          heading(
            'Do you have a code from your carer?',
            'If someone helps you with shopping, type the 6 number code they gave you. If not, tap Skip.',
          ),
          field(
            carerCode,
            '------',
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            numbers: true,
          ),
          const SizedBox(height: 32),
          bigButton('Next', () => go(6)),
          const SizedBox(height: 22),
          bigButton('Skip', () {
            carerCode.clear();
            go(6);
          }, outline: true),
        ];

  Widget layoutCard(bool plain, IconData icon, String title, String sub) => Tap(
    label: title,
    checked: plainChoice == plain,
    onTap: () => setState(() => plainChoice = plain),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: box(
        radius: 24,
        color: plainChoice == plain ? pale : Colors.white,
        border: plainChoice == plain ? green : line,
        thickness: 2,
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: box(color: Colors.white, radius: 34, border: null),
            child: Icon(icon, size: 34, color: green),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                words(title, 20, weight: 800),
                const SizedBox(height: 6),
                words(sub, 15, weight: 500, color: muted),
              ],
            ),
          ),
          Icon(
            plainChoice == plain
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 30,
            color: plainChoice == plain ? green : muted,
          ),
        ],
      ),
    ),
  );

  List<Widget> layoutStep() => [
    heading(
      'How should your list look?',
      'You can change this later in Settings.',
    ),
    layoutCard(false, Icons.grid_view, 'Pictures', 'A big picture for each item'),
    const SizedBox(height: 22),
    layoutCard(true, Icons.view_list, 'Plain list', 'Simple rows with no pictures'),
    const SizedBox(height: 40),
    bigButton('Next', () => go(7)),
  ];

  List<Widget> doneStep() => [
    const SizedBox(height: 40),
    Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: box(color: pale, radius: 75, border: null),
        child: const Icon(Icons.check, size: 84, color: green),
      ),
    ),
    const SizedBox(height: 40),
    Center(child: words('You are all set, ${name.text.trim()}', 30, weight: 800)),
    const SizedBox(height: 16),
    Text(
      role == 'carer'
          ? 'You can change safety limits in Settings. You will not need to sign in again on this phone.'
          : 'You will not need to sign in again on this phone.',
      textAlign: TextAlign.center,
      style: type(17, 500, muted).copyWith(height: 1.45),
    ),
    const SizedBox(height: 56),
    bigButton('Open my shopping list', finish),
  ];
}

// Settings > My details: change the name or phone number.
// A new phone number is verified with a new SMS code first.
class AccountDetails extends StatefulWidget {
  const AccountDetails({super.key, required this.model, required this.onDone});
  final WireframeModel model;
  final VoidCallback onDone;
  @override
  State<AccountDetails> createState() => _AccountDetailsState();
}

class _AccountDetailsState extends State<AccountDetails> {
  late final name = TextEditingController(text: widget.model.accountName);
  late final phone = TextEditingController(text: widget.model.phone);
  final code = TextEditingController();
  bool asking = false, busy = false;
  String? problem;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  String digits(String v) => v.replaceAll(RegExp(r'[^0-9+]'), '');
  bool get phoneChanged => digits(phone.text) != digits(widget.model.phone);

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      setState(() => problem = 'Please type your name.');
      return;
    }
    final count = digits(phone.text).replaceAll('+', '').length;
    if (count < 8 || count > 15) {
      setState(() => problem = 'Please check your number. It looks too short.');
      return;
    }
    if (phoneChanged && !asking) {
      setState(() {
        busy = true;
        problem = null;
      });
      final ok = await sendLoginCode(digits(phone.text));
      if (!mounted) return;
      setState(() {
        busy = false;
        asking = ok;
        code.clear();
        if (!ok) problem = 'We could not send the message. Please try again.';
      });
      return;
    }
    if (asking) {
      setState(() => busy = true);
      final ok = await checkLoginCode(digits(phone.text), code.text);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          busy = false;
          problem = 'That code is not right. Please try again.';
        });
        return;
      }
    }
    widget.model.updateAccount(
      name: name.text.trim(),
      phone: phone.text.trim(),
    );
    widget.onDone();
  }

  Widget box2(Widget child) => Container(
    height: 84,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    alignment: Alignment.center,
    decoration: box(radius: 22, border: green, thickness: 2),
    child: child,
  );

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
      children: [
        words('My name', 18, weight: 700, color: muted),
        const SizedBox(height: 12),
        box2(
          TextField(
            controller: name,
            enabled: !asking,
            autofillHints: const [AutofillHints.givenName],
            textCapitalization: TextCapitalization.words,
            autocorrect: true,
            enableSuggestions: true,
            style: type(20, 700),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 28),
        words('My phone number', 18, weight: 700, color: muted),
        const SizedBox(height: 12),
        box2(
          TextField(
            controller: phone,
            enabled: !asking,
            autofillHints: const [AutofillHints.telephoneNumber],
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            onChanged: (_) => setState(() => problem = null),
            style: type(20, 700),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (widget.model.isCarer && phoneChanged) ...[
          const SizedBox(height: 14),
          Text(
            'Your link code will change when you change your number.',
            style: type(15, 500, muted).copyWith(height: 1.4),
          ),
        ],
        if (asking) ...[
          const SizedBox(height: 28),
          words('Type the 6 number code we sent', 18, weight: 700, color: muted),
          const SizedBox(height: 12),
          box2(
            TextField(
              controller: code,
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: type(30, 700).copyWith(letterSpacing: 8),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '------',
                hintStyle: type(24, 500, label),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: words('Trial version: the code is 123456', 14, color: label)),
        ],
        if (problem != null) ...[
          const SizedBox(height: 18),
          Semantics(
            liveRegion: true,
            child: words(problem!, 16, weight: 600, color: const Color(0xffb91c1c)),
          ),
        ],
        const SizedBox(height: 36),
        Tap(
          label: asking ? 'Save' : (phoneChanged ? 'Send my code' : 'Save'),
          onTap: busy ? null : save,
          child: Container(
            height: 84,
            alignment: Alignment.center,
            decoration: box(color: green, radius: 42, border: null),
            child: words(
              busy
                  ? 'Please wait…'
                  : asking
                  ? 'Save'
                  : (phoneChanged ? 'Send my code' : 'Save'),
              20,
              weight: 800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Tap(
          label: 'Cancel',
          onTap: widget.onDone,
          child: Container(
            height: 72,
            alignment: Alignment.center,
            decoration: box(radius: 36, border: line, thickness: 2),
            child: words('Cancel', 18, weight: 700, color: muted),
          ),
        ),
      ],
    ),
  );
}

// Shown after Log out. The account is saved, so one tap signs in.
class WelcomeBack extends StatelessWidget {
  const WelcomeBack({super.key, required this.model});
  final WireframeModel model;

  @override
  Widget build(BuildContext context) {
    final name = model.accountName.trim();
    return Scaffold(
      backgroundColor: ink,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: ColoredBox(
              color: paper,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(32, 80, 32, 48),
                children: [
                  words(name.isEmpty ? 'Welcome back' : 'Welcome back, $name', 30,
                      weight: 800),
                  const SizedBox(height: 14),
                  Text(
                    'Your lists are ready.',
                    style: type(17, 500, muted).copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 40),
                  Tap(
                    label: 'Sign in',
                    onTap: model.signBackIn,
                    child: Container(
                      height: 84,
                      alignment: Alignment.center,
                      decoration: box(color: green, radius: 42, border: null),
                      child: words('Sign in', 20,
                          weight: 800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Tap(
                    label: 'Not you? Set up a different account',
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('Set up a different account?'),
                          content: const Text(
                            'The saved name and phone number are removed. '
                            'Your lists are kept.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) model.forgetAccount();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Center(
                        child: words('Not you? Set up a different account', 16,
                            weight: 700, color: green),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}