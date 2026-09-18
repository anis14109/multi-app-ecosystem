import 'package:flutter/material.dart';
import 'package:flutter_app/auth/bloc/auth_bloc.dart';
import 'package:flutter_app/auth/bloc/auth_event.dart';
import 'package:flutter_app/auth/bloc/auth_state.dart';
import 'package:flutter_app/auth/widgets/pin_keypad.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _SetupStep { choose, enter, confirm }

/// Setup screen displayed after first successful authentication.
///
/// Guides the user through choosing a local unlock method:
/// - **Biometric unlock** — fast, seamless fingerprint/face unlock.
/// - **Create a PIN** — a 6-digit numeric PIN entered via an
///   on-screen keypad (create + confirm).
///
/// If the device does not support biometrics, only PIN setup is shown.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  _SetupStep _step = _SetupStep.choose;
  final List<String> _pin = [];
  final List<String> _confirmPin = [];
  String? _error;

  bool get _isConfirming => _step == _SetupStep.confirm;

  List<String> get _activeEntry => _isConfirming ? _confirmPin : _pin;

  void _onDigit(String digit) {
    if (digit.isEmpty) return;
    final entry = _activeEntry;
    if (entry.length >= 6) return;

    setState(() {
      entry.add(digit);
      _error = null;
    });

    if (entry.length == 6) {
      if (_isConfirming) {
        final confirm = _confirmPin.join();
        final original = _pin.join();
        if (confirm == original) {
          context.read<AuthBloc>().add(AuthPinCreated(pin: original));
        } else {
          setState(() {
            _error = "PINs don't match. Please try again.";
            _step = _SetupStep.enter;
            _pin.clear();
            _confirmPin.clear();
          });
        }
      } else {
        setState(() {
          _step = _SetupStep.confirm;
          _confirmPin.clear();
        });
      }
    }
  }

  void _onBackspace() {
    final entry = _activeEntry;
    if (entry.isEmpty) return;
    setState(() {
      entry.removeLast();
      _error = null;
    });
  }

  void _startPinFlow() {
    setState(() {
      _step = _SetupStep.enter;
      _pin.clear();
      _confirmPin.clear();
      _error = null;
    });
  }

  void _onChooseBiometric() {
    context.read<AuthBloc>().add(const AuthBiometricEnabled());
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
            final biometricAvailable =
                state is AuthSetupRequired && state.biometricAvailable;
            final effectiveStep =
                _step == _SetupStep.choose && !biometricAvailable
                    ? _SetupStep.enter
                    : _step;

            if (effectiveStep == _SetupStep.choose) {
              return _buildChoice(context);
            }
            return _buildPinEntry(context, biometricAvailable);
          },
        ),
      ),
    );
  }

  Widget _buildChoice(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.shield_outlined, size: 80, color: primary),
              const SizedBox(height: 16),
              Text(
                'Secure Your App',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how to unlock the app.'
                '\nThis works even when you are offline.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _onChooseBiometric,
                icon: const Icon(Icons.fingerprint, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Enable Biometric Unlock'),
                      SizedBox(height: 4),
                      Text(
                        'Fast, seamless fingerprint / face unlock',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _startPinFlow,
                icon: const Icon(Icons.pin_outlined, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Create a PIN'),
                      SizedBox(height: 4),
                      Text(
                        'Unlock with a 6-digit PIN',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry(BuildContext context, bool biometricAvailable) {
    final entry = _activeEntry;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (biometricAvailable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _step = _SetupStep.choose;
                        _pin.clear();
                        _confirmPin.clear();
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                ),
              Icon(
                Icons.pin_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Create Your PIN',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a 6-digit PIN to unlock the app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              PinDots(length: entry.length),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            ],
          ),
        ),
      ),
    );
  }
}
