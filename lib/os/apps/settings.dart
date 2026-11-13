import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../data/links.dart';
import '../../data/prefs.dart';
import '../../data/session.dart';
import '../kit/controls.dart';
import '../kit/motion.dart';
import '../kit/tokens.dart';
import '../l10n.dart';
import '../os.dart';
import '../shell.dart' show lampColor;
import '../wall.dart' show ago;
import '../window.dart';

class SettingsApp extends ConsumerWidget {
  const SettingsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final prefs = ref.watch(prefsProvider);
    final p = ref.read(prefsProvider.notifier);
    return AppPane(
      app: AppId.settings,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          Section(tr('Connections')),
          _Panel(
            child: Row(
              children: [
                Lamp(Tk.ok, pulse: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.demo ? tr('Demo') : 'Tududi', style: sans(16, w: 600)),
                      const SizedBox(height: 3),
                      Text(
                        auth.demo
                            ? tr('Sample data on this device. Nothing is sent anywhere.')
                            : '${auth.user?.email ?? ''} · ${auth.serverUrl ?? ''}',
                        style: sans(13.5, color: Tk.ink3, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OsButton(
                  auth.demo ? tr('Leave') : tr('Sign out'),
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    resetAll(ref);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _LinkPanel(
            svc: Svc.karakeep,
            name: 'Karakeep',
            what: 'Bookmarks and clippings',
            hint: 'In Karakeep: Settings → API Keys → New API Key.',
            urlHint: 'karakeep.example.com',
            tokenLabel: 'API key',
          ),
          const SizedBox(height: 10),
          _LinkPanel(
            svc: Svc.memos,
            name: 'Memos',
            what: 'Quick notes',
            hint: 'In Memos: Settings → My Account → Access Tokens → Create.',
            urlHint: 'memos.example.com',
            tokenLabel: 'Access token',
          ),
          const SizedBox(height: 10),
          const _FlatPanel(),
          Section(tr('Appearance')),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(tr('Accent')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < Tk.accents.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Pressable(
                          onTap: () => p.setAccent(i),
                          label: '${tr('Accent')} ${i + 1}',
                          scale: 0.85,
                          radius: BorderRadius.circular(22),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SpringBuilder(
                                value: prefs.accent == i ? 1 : 0,
                                spec: Spec.bouncy,
                                builder: (context, v, _) => Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Tk.accents[i].withValues(alpha: v.clamp(0.0, 1.0)),
                                      width: 1.5,
                                    ),
                                  ),
                                  padding: EdgeInsets.all(1.5 + 3 * v.clamp(0.0, 1.2)),
                                  child: DecoratedBox(
                                    decoration:
                                        BoxDecoration(shape: BoxShape.circle, color: Tk.accents[i]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Reduce motion'), style: sans(15.5, w: 500)),
                          const SizedBox(height: 2),
                          Text(tr('Things change in place instead of moving.'),
                              style: sans(13.5, color: Tk.ink3)),
                        ],
                      ),
                    ),
                    OsSwitch(
                      value: prefs.reduceMotion,
                      label: tr('Reduce motion'),
                      onChanged: p.setReduceMotion,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Section(tr('Language')),
          OsSeg<String>(value: prefs.locale, items: L.names, onChanged: p.setLocale),
          Section(tr('About')),
          Text(
            tr('Tududa 2.0 · an independent client. Not affiliated with Tududi, Karakeep, Memos or Flatastic.'),
            style: sans(13.5, color: Tk.ink3, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Tk.fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Tk.rule),
        ),
        child: child,
      );
}

String _statusText(LinkState s) => switch (s.status) {
      Link.off => tr('Not connected'),
      Link.busy => tr('Connecting…'),
      Link.live => '${tr('Live')} · ${ago(s.synced)}',
      Link.error => tr(s.error ?? 'Could not reach the server'),
    };

/// The head every connection panel shares: a lamp, the name, the state.
class _LinkHead extends StatelessWidget {
  final String name;
  final String what;
  final LinkState state;
  final VoidCallback? onDisconnect;
  const _LinkHead({required this.name, required this.what, required this.state, this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Lamp(lampColor(state.status), pulse: state.status == Link.live),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: sans(16, w: 600)),
              const SizedBox(height: 3),
              Text(
                state.status == Link.off ? tr(what) : _statusText(state),
                style: sans(13.5,
                    color: state.status == Link.error ? Tk.signal : Tk.ink3, height: 1.35),
              ),
            ],
          ),
        ),
        if (state.status == Link.live && onDisconnect != null) ...[
          const SizedBox(width: 10),
          OsButton(tr('Disconnect'), onTap: onDisconnect),
        ],
      ],
    );
  }
}

class _LinkPanel extends ConsumerStatefulWidget {
  final Svc svc;
  final String name;
  final String what;
  final String hint;
  final String urlHint;
  final String tokenLabel;
  const _LinkPanel({
    required this.svc,
    required this.name,
    required this.what,
    required this.hint,
    required this.urlHint,
    required this.tokenLabel,
  });

  @override
  ConsumerState<_LinkPanel> createState() => _LinkPanelState();
}

class _LinkPanelState extends ConsumerState<_LinkPanel> {
  final _url = TextEditingController();
  final _token = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  LinkNotifier get _n => widget.svc == Svc.karakeep
      ? ref.read(karakeepProvider.notifier)
      : ref.read(memosProvider.notifier);

  Future<void> _connect() async {
    if (_url.text.trim().isEmpty || _token.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final ok = await _n.connect(LinkCfg(url: cleanUrl(_url.text), token: _token.text.trim()));
    if (ok && mounted) {
      thud();
      ref.read(osProvider.notifier).toast(tr('{name} is live', {'name': widget.name}));
      _token.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final LinkState s = widget.svc == Svc.karakeep
        ? ref.watch(karakeepProvider)
        : ref.watch(memosProvider);
    final demo = ref.watch(authProvider.select((a) => a.demo));
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LinkHead(
            name: widget.name,
            what: widget.what,
            state: s,
            onDisconnect: demo ? null : _n.disconnect,
          ),
          if (s.status != Link.live) ...[
            const SizedBox(height: 14),
            OsField(
              controller: _url,
              label: tr('Address'),
              hint: widget.urlHint,
              icon: Icons.dns_outlined,
              keyboard: TextInputType.url,
            ),
            const SizedBox(height: 12),
            OsField(
              controller: _token,
              label: tr(widget.tokenLabel),
              icon: Icons.key_outlined,
              obscure: true,
              onSubmit: (_) => _connect(),
            ),
            const SizedBox(height: 10),
            Text(tr(widget.hint), style: sans(13, color: Tk.ink3, height: 1.4)),
            const SizedBox(height: 14),
            OsButton(tr('Connect'),
                primary: true, busy: s.status == Link.busy, onTap: _connect),
          ],
        ],
      ),
    );
  }
}

class _FlatPanel extends ConsumerStatefulWidget {
  const _FlatPanel();

  @override
  ConsumerState<_FlatPanel> createState() => _FlatPanelState();
}

class _FlatPanelState extends ConsumerState<_FlatPanel> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _key = TextEditingController();
  bool _useKey = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final f = ref.read(flatProvider.notifier);
    FocusScope.of(context).unfocus();
    final ok = _useKey
        ? await f.connect(LinkCfg(url: FlatNotifier.host, token: _key.text.trim()))
        : await f.login(_email.text, _password.text);
    if (ok && mounted) {
      thud();
      ref.read(osProvider.notifier).toast(tr('{name} is live', {'name': 'Flatastic'}));
      _password.clear();
      _key.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(flatProvider);
    final demo = ref.watch(authProvider.select((a) => a.demo));
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LinkHead(
            name: 'Flatastic',
            what: 'Chores and shopping at home',
            state: s,
            onDisconnect: demo ? null : ref.read(flatProvider.notifier).disconnect,
          ),
          if (s.status != Link.live) ...[
            const SizedBox(height: 14),
            if (_useKey)
              OsField(
                controller: _key,
                label: tr('API key'),
                icon: Icons.key_outlined,
                obscure: true,
                onSubmit: (_) => _connect(),
              )
            else ...[
              OsField(
                controller: _email,
                label: tr('Email'),
                icon: Icons.alternate_email_rounded,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              OsField(
                controller: _password,
                label: tr('Password'),
                icon: Icons.lock_outline_rounded,
                obscure: true,
                onSubmit: (_) => _connect(),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              tr('Flatastic has no public API; this uses the one its own apps use, so it can change without notice. Your password is used once to get a key and is not kept.'),
              style: sans(13, color: Tk.ink3, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OsButton(tr('Connect'),
                      primary: true, busy: s.status == Link.busy, onTap: _connect),
                ),
                const SizedBox(width: 10),
                OsButton(_useKey ? tr('Use password') : tr('Use a key'),
                    onTap: () => setState(() => _useKey = !_useKey)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
