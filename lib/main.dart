import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/headache_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = HeadacheDatabase();
  await database.initialize();

  runApp(
    ProviderScope(
      overrides: [headacheDatabaseProvider.overrideWithValue(database)],
      child: const HeadLogApp(),
    ),
  );
}
