import 'package:flutter/material.dart';
import 'package:flutter_app/auth/auth.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_app/core/services/env_config.dart';
import 'package:flutter_app/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Root application widget with BLoC/Repository providers wired up.
///
/// Provides the [AuthBloc] and [AuthRepository] to the entire widget tree.
/// The [AuthWrapper] handles screen routing based on authentication state.
/// Named routes are used for navigation between auth screens. The
/// pushed sub-flow pages (forgot/reset password, email verification,
/// password confirmation) use their own dedicated cubits and read the
/// [AuthRepository] from the ancestor [RepositoryProvider].
class App extends StatelessWidget {
  const App({
    required this._authBloc,
    required this._authRepository,
    super.key,
  });

  final AuthBloc _authBloc;
  final AuthRepository _authRepository;

  static const Color _seedColor = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
      ],
      child: BlocProvider.value(
        value: _authBloc,
        child: MaterialApp(
          title: EnvConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthWrapper(),
          routes: {
            '/register': (_) => BlocProvider.value(
              value: _authBloc,
              child: const RegisterPage(),
            ),
            '/profile': (_) => BlocProvider.value(
              value: _authBloc,
              child: const ProfilePage(),
            ),
            // These sub-flow pages are self-contained: they create their
            // own cubit from the ancestor AuthRepository and do not
            // depend on AuthBloc state (which stays un-paused on the
            // AuthWrapper screen beneath the pushed route).
            '/forgot-password': (_) => const ForgotPasswordPage(),
            '/reset-password': (_) => const ResetPasswordPage(),
            '/email-verification': (_) => const EmailVerificationPage(),
            '/password-confirmation': (_) => const PasswordConfirmationPage(),
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
