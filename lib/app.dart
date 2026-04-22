import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/project.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/signup_screen.dart';
import 'presentation/screens/editor/editor_screen.dart';
import 'presentation/screens/export/export_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/legal/privacy_screen.dart';
import 'presentation/screens/legal/terms_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/viewmodels/editor_viewmodel.dart';
import 'presentation/viewmodels/profile_viewmodel.dart';
import 'presentation/viewmodels/settings_viewmodel.dart';

class MoovApp extends StatelessWidget {
  const MoovApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsVm = context.watch<SettingsViewModel>();
    return MaterialApp(
      title: 'Moov Editor',
      debugShowCheckedModeBanner: false,
      themeMode: settingsVm.themeMode,
      theme: AppTheme.lightFor(settingsVm.locale),
      darkTheme: AppTheme.darkFor(settingsVm.locale),
      locale: settingsVm.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/splash',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/editor':
        final project = settings.arguments as Project?;
        if (project == null) return _errorRoute();
        return MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => EditorViewModel(project: project),
            child: const EditorScreen(),
          ),
        );
      case '/export':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ExportScreen(),
        );
      case '/profile':
        return MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => ProfileViewModel(),
            child: const ProfileScreen(),
          ),
        );
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/terms':
        return MaterialPageRoute(builder: (_) => const TermsScreen());
      case '/privacy':
        return MaterialPageRoute(builder: (_) => const PrivacyScreen());
      default:
        return _errorRoute();
    }
  }

  Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('Route not found')),
      ),
    );
  }
}
