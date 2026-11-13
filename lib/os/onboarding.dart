import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import 'kit/backdrop.dart';
import 'kit/controls.dart';
import 'kit/dots.dart';
import 'kit/glass.dart';
import 'kit/motion.dart';
import 'kit/tokens.dart';
import 'l10n.dart';

/// The moment before anything is known: the wordmark writes itself.
class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  String _text = '      ';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() => _text = 'TUDUDA');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tk.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: Backdrop()),
          Center(child: DotText(_text, dot: 5, gap: 2)),
        ],
      ),
    );
  }
}

/// Signing in: the server and the account in one step, or the demo.
class Onboarding extends ConsumerStatefulWidget {
  const Onboarding({super.key});

  @override
  ConsumerState<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<Onboarding> {
  late final _server = TextEditingController(text: ref.read(authProvider).serverUrl ?? '');
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _mark = '      ';
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _mark = 'TUDUDA');
    });
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    if (_server.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = tr('Fill in the server, your email and your password.'));
      return;
    }
    setState(() => _error = null);
    final ok = await ref
        .read(authProvider.notifier)
        .connect(_server.text, _email.text.trim(), _password.text);
    if (!ok && mounted) {
      setState(() => _error = tr(ref.read(authProvider).error ?? 'Could not sign in'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authProvider.select((s) => s.status == AuthStatus.loading));
    return Scaffold(
      backgroundColor: Tk.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: Backdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DotText(_mark, dot: 5, gap: 2),
                        ),
                        const SizedBox(height: 22),
                        Enter(
                          i: 1,
                          child: Text(
                            tr('One place for your tasks, notes, links and home.'),
                            style: sans(27, w: 680, wdth: 112, height: 1.12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Enter(
                          i: 2,
                          child: Text(
                            tr('Start with your Tududi server. Karakeep, Memos and Flatastic connect inside.'),
                            style: sans(15, color: Tk.ink2, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Enter(
                          i: 3,
                          dy: 26,
                          builder: (context, v) => Glass(
                            radius: 26,
                            opacity: v,
                            padding: const EdgeInsets.all(18),
                            child: Opacity(
                              opacity: v,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  OsField(
                                    controller: _server,
                                    label: tr('Server'),
                                    hint: 'tududi.example.com',
                                    icon: Icons.dns_outlined,
                                    keyboard: TextInputType.url,
                                    autofill: const [AutofillHints.url],
                                  ),
                                  const SizedBox(height: 14),
                                  OsField(
                                    controller: _email,
                                    label: tr('Email'),
                                    hint: 'you@example.com',
                                    icon: Icons.alternate_email_rounded,
                                    keyboard: TextInputType.emailAddress,
                                    autofill: const [AutofillHints.username, AutofillHints.email],
                                  ),
                                  const SizedBox(height: 14),
                                  OsField(
                                    controller: _password,
                                    label: tr('Password'),
                                    icon: Icons.lock_outline_rounded,
                                    obscure: true,
                                    autofill: const [AutofillHints.password],
                                    onSubmit: (_) => _connect(),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.error_outline_rounded,
                                              size: 16, color: Tk.signal),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(_error!,
                                              style: sans(13.5, color: Tk.signal, height: 1.35)),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  OsButton(tr('Connect'),
                                      primary: true, busy: busy, onTap: _connect),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Enter(
                          i: 4,
                          child: OsButton(
                            tr('Look around with sample data'),
                            icon: Icons.play_arrow_rounded,
                            onTap: busy ? null : () => ref.read(authProvider.notifier).enterDemo(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
