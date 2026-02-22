import 'package:flutter/material.dart';

import 'app/di.dart';
import 'app/app_root.dart';

Future<void> main() async {
  final deps = await AppDI.build();
  runApp(
    AppRoot(
      settings: deps.settings,
      auth: deps.auth,
      api: deps.api,
      appLock: deps.appLock,
    ),
  );
}
