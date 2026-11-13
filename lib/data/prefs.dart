import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

class Prefs {
  final int accent;
  final String locale;
  final bool reduceMotion;
  const Prefs({this.accent = 0, this.locale = 'en', this.reduceMotion = false});

  Prefs copyWith({int? accent, String? locale, bool? reduceMotion}) => Prefs(
        accent: accent ?? this.accent,
        locale: locale ?? this.locale,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
}

class PrefsNotifier extends Notifier<Prefs> {
  @override
  Prefs build() {
    final p = ref.watch(sharedPreferencesProvider);
    final system = PlatformDispatcher.instance.locale.languageCode;
    return Prefs(
      accent: p.getInt('os_accent') ?? 0,
      locale: p.getString('app_locale') ?? (const ['de', 'zh'].contains(system) ? system : 'en'),
      reduceMotion: p.getBool('os_reduce_motion') ?? false,
    );
  }

  void setAccent(int i) {
    ref.read(sharedPreferencesProvider).setInt('os_accent', i);
    state = state.copyWith(accent: i);
  }

  void setLocale(String l) {
    ref.read(sharedPreferencesProvider).setString('app_locale', l);
    state = state.copyWith(locale: l);
  }

  void setReduceMotion(bool v) {
    ref.read(sharedPreferencesProvider).setBool('os_reduce_motion', v);
    state = state.copyWith(reduceMotion: v);
  }
}

final prefsProvider = NotifierProvider<PrefsNotifier, Prefs>(PrefsNotifier.new);
