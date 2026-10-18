import 'dart:async';

import 'package:alchemist/alchemist.dart';

/// Golden tests are CI-only: platform goldens (real fonts, differ per OS) are
/// disabled; only the deterministic CI goldens (Ahem font blocks) are
/// compared, so they are stable on macOS, Linux and CI alike.
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      forceUpdateGoldenFiles: false,
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
      ciGoldensConfig: CiGoldensConfig(
        enabled: true,
        filePathResolver: _ciPath,
      ),
    ),
    run: () async => testMain(),
  );
}

String _ciPath(String fileName, String environmentName) => 'ci/$fileName.png';
