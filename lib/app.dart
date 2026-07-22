import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/bookshelf_screen.dart';
import 'services/progress_saver.dart';
import 'providers/settings_provider.dart';

class TingshuApp extends ConsumerWidget {
  const TingshuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: '听书',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: toThemeMode(settings.themeMode),
      home: const AppLifecycleProgressObserver(child: BookshelfScreen()),
    );
  }
}
