import 'package:flutter/material.dart';
import 'package:flutter_app/auth/bloc/auth_bloc.dart';
import 'package:flutter_app/auth/bloc/auth_event.dart';
import 'package:flutter_app/auth/bloc/auth_state.dart';
import 'package:flutter_app/auth/widgets/pin_keypad.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lock screen displayed when the app requires local re-authentication.
///
/// Unlock methods (based on the user's setup choice):
/// 1. PIN Entry via an on-screen **number pad** (6-digit numeric PIN).
/// 2. Biometric: Fingerprint/Face ID via `local_auth`.
///
/// A biometric shortcut is shown on the lock screen whenever the
/// device supports it; tapping it opens the system biometric prompt.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final List<String> _pin = [];
  var _attemptCount = 0;

  void _onDigit(String digit) {
    if (digit.isEmpty) return;
    if (_pin.length >= 6) return;

    setState(() {
      _pin.add(digit);
    });

    if (_pin.length == 6) {
      final entered = _pin.join();
      setState(() {
        _attemptCount++;
        _pin.clear();
      });
      context.read<AuthBloc>().add(AuthPinVerified(pin: entered));
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(_pin.removeLast);
  }

  void _onBiometricUnlock() {
    context.read<AuthBloc>().add(const AuthBiometricVerified());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            AuthLocalLocked? locked;
            if (state is AuthLocalLocked) {
              locked = state;
            } else if (state is AuthError &&
                state.previousState is AuthLocalLocked) {
              locked = state.previousState as AuthLocalLocked;
            }

            final hasPin = locked?.hasPin ?? false;
            final biometricAvailable =
                locked?.biometricAvailable ?? false;

            final showKeypad = hasPin;
            final showBiometric = biometricAvailable;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'App Locked',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      showKeypad
                          ? 'Enter your PIN to unlock'
                          : showBiometric
                              ? 'Authenticate with biometrics to unlock'
                              : 'No unlock method available',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 48),
                    if (showKeypad) ...[
                      PinDots(length: _pin.length),
                      const SizedBox(height: 16),
                      if (_attemptCount > 0) ...[
                        Text(
                          '$_attemptCount attempt'
                          '${_attemptCount > 1 ? 's' : ''}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
                      if (showBiometric) ...[
                        const SizedBox(height: 8),
                        IconButton.filledTonal(
                          onPressed: _onBiometricUnlock,
                          icon: const Icon(Icons.fingerprint, size: 32),
                          iconSize: 32,
                          tooltip: 'Unlock with Biometrics',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ] else if (showBiometric) ...[
                      IconButton.filled(
                        onPressed: _onBiometricUnlock,
                        icon: const Icon(Icons.fingerprint, size: 40),
                        iconSize: 40,
                        tooltip: 'Unlock with Biometrics',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No unlock method was found on this device. '
                        'Contact support to regain access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
