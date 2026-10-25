import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/routing/app_router.dart';
import '../core/theme/theme.dart';

class SoamaApp extends ConsumerWidget {
  const SoamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: SoamaTheme.light(),
      darkTheme: SoamaTheme.dark(),
      routerConfig: AppRouter.router,
    );
  }
}
