import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/glucose_repository.dart';
import 'data/reading_store.dart';
import 'data/sources/dexcom_auth.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await SettingsController.open();
  final store = await ReadingStore.open();
  final auth = DexcomAuth();
  await auth.load();

  final repository = GlucoseRepository(store: store, auth: auth);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: repository),
      ],
      child: const GlucoseTrendsApp(),
    ),
  );
}
