import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../data/sources/hive_repositories.dart';
import '../data/seed_data.dart';
import '../application/providers/repo_providers.dart';
import '../core/notification_service.dart';
import '../core/background_notif_service.dart';

import 'theme.dart';
import 'router.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await Hive.initFlutter();
  await openHiveBoxes();

  // Init notification services (mobile only — not supported on web)
  if (!kIsWeb) {
    await NotificationService.instance.init();
    await BackgroundNotifService.instance.init();
  }

  // Create a temporary container to seed data and set initial user
  final container = ProviderContainer();
  await seedIfNeeded(
    settingsRepo: container.read(settingsRepoProvider),
    userRepo: container.read(userRepoProvider),
    propertyRepo: container.read(propertyRepoProvider),
    columnRepo: container.read(columnRepoProvider),
    cardRepo: container.read(cardRepoProvider),
    fieldRepo: container.read(fieldRepoProvider),
  );

  container.dispose();

  runApp(const ProviderScope(child: _App()));
}

class _App extends ConsumerStatefulWidget {
  const _App();

  @override
  ConsumerState<_App> createState() => _AppState();
}

class _AppState extends ConsumerState<_App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(ref);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Manage Property Room',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: _router,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
