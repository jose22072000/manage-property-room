import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../domain/domain.dart';
import '../data/sources/hive_repositories.dart';
import '../data/seed_data.dart';
import '../application/providers/repo_providers.dart';

import 'theme.dart';
import 'router.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await Hive.initFlutter();
  await openHiveBoxes();

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

  // Set default user (first admin) if none saved
  final settings = container.read(settingsRepoProvider);
  final currentId = await settings.getCurrentUserId();
  if (currentId == null) {
    final users = await container.read(userRepoProvider).getAll();
    final admin = users.where((u) => u.role == UserRole.admin).firstOrNull;
    if (admin != null) await settings.setCurrentUserId(admin.id);
  }
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
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
