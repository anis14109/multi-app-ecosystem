import 'package:flutter/material.dart';
import 'package:flutter_app/auth/bloc/auth_bloc.dart';
import 'package:flutter_app/auth/bloc/auth_state.dart';
import 'package:flutter_app/auth/view/auth_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Root widget that displays the appropriate screen based on auth state.
///
/// Acts as a state machine viewer, mapping each `AuthState` to its
/// corresponding UI screen.
///
/// The default case (unrecognized state) shows the lock screen if
/// local auth data exists, otherwise the login page. This ensures
/// the app never accidentally shows login to an existing user.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, size: 80),
                  SizedBox(height: 24),
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        if (state is AuthUnauthenticated) {
          return const LoginPage();
        }

        if (state is AuthSetupRequired) {
          return const SetupPage();
        }

        if (state is AuthLocalLocked) {
          return const LockScreen();
        }

        if (state is AuthenticatedOnline || state is AuthenticatedOffline) {
          return const HomePage();
        }

        if (state is AuthError) {
          final previous = state.previousState;
          if (previous is AuthUnauthenticated) {
            return const LoginPage();
          }
          if (previous is AuthSetupRequired) {
            return const SetupPage();
          }
          if (previous is AuthLocalLocked) {
            return const LockScreen();
          }
          if (previous is AuthenticatedOnline ||
              previous is AuthenticatedOffline) {
            return const HomePage();
          }
        }

        // Default fallback: show lock screen, never login.
        // This prevents accidental logout on state edge cases.
        return const LockScreen();
      },
    );
  }
}
