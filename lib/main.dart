import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/providers/auth_provider.dart';
import 'core/services/api_service.dart';
import 'data/prefs.dart';
import 'os/kit/motion.dart';
import 'os/kit/tokens.dart';
import 'os/l10n.dart';
import 'os/onboarding.dart';
import 'os/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TududaApp(),
    ),
  );
}

class TududaApp extends ConsumerStatefulWidget {
  const TududaApp({super.key});

  @override
  ConsumerState<TududaApp> createState() => _TududaAppState();
}

class _TududaAppState extends ConsumerState<TududaApp> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // On the web, ?demo opens straight on the sample data.
      if (kIsWeb && Uri.base.queryParameters.containsKey('demo')) {
        await ref.read(authProvider.notifier).enterDemo();
      } else {
        await ref.read(authProvider.notifier).checkAuth();
      }
      if (mounted) setState(() => _checked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final signedIn = ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));
    L.code = prefs.locale;
    final accent = Tk.accents[prefs.accent.clamp(0, Tk.accents.length - 1)];
    return MaterialApp(
      title: 'Tududa',
      debugShowCheckedModeBanner: false,
      theme: osTheme(accent),
      builder: (context, child) {
        Motion.reduced = prefs.reduceMotion || MediaQuery.disableAnimationsOf(context);
        return BackdropGroup(
          child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.4, child: child!),
        );
      },
      home: KeyedSubtree(
        key: ValueKey('${prefs.locale}-$signedIn-$_checked'),
        child: !_checked
            ? const Boot()
            : signedIn
                ? const OsShell()
                : const Onboarding(),
      ),
    );
  }
}
