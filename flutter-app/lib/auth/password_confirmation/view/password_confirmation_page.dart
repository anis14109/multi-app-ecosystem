import 'package:flutter/material.dart';
import 'package:flutter_app/auth/password_confirmation/cubit/password_confirmation_cubit.dart';
import 'package:flutter_app/auth/widgets/auth_header.dart';
import 'package:flutter_app/auth/widgets/form_fields.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reusable password-confirmation screen.
///
/// Confirms the user's current password with the server
/// (`POST /api/v1/user/confirm-password`) before sensitive actions.
/// The optional `VoidCallback` may be passed as the route argument and is
/// invoked immediately after a successful confirmation.
class PasswordConfirmationPage extends StatelessWidget {
  const PasswordConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PasswordConfirmationCubit(
        repository: context.read<AuthRepository>(),
      ),
      child: const PasswordConfirmationView(),
    );
  }
}

/// Presentational layer for the password-confirmation flow.
class PasswordConfirmationView extends StatefulWidget {
  const PasswordConfirmationView({super.key});

  @override
  State<PasswordConfirmationView> createState() =>
      _PasswordConfirmationViewState();
}

class _PasswordConfirmationViewState extends State<PasswordConfirmationView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  VoidCallback? _onConfirmed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onConfirmed ??=
        ModalRoute.of(context)?.settings.arguments as VoidCallback?;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      await context.read<PasswordConfirmationCubit>().confirmPassword(
        _passwordController.text,
      );
    }
  }

  void _handleSuccess(BuildContext context) {
    _onConfirmed?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              icon: Icons.shield_outlined,
              title: 'Confirm Password',
              subtitle: 'Confirm your password to continue',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child:
                  BlocConsumer<
                    PasswordConfirmationCubit,
                    PasswordConfirmationState
                  >(
                    listener: (context, state) {
                      if (state is PasswordConfirmationSuccess) {
                        _handleSuccess(context);
                      }
                    },
                    builder: (context, state) {
                      final errorMessage = state is PasswordConfirmationError
                          ? state.message
                          : null;
                      final isSubmitting =
                          state is PasswordConfirmationSubmitting;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (errorMessage != null) ...[
                                AuthErrorBanner(
                                  message: errorMessage,
                                  onDismiss: () => context
                                      .read<PasswordConfirmationCubit>()
                                      .reset(),
                                ),
                                const SizedBox(height: 16),
                              ],
                              AuthPasswordField(
                                controller: _passwordController,
                                autofocus: true,
                                onFieldSubmitted: (_) => _onSubmit(),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: isSubmitting ? null : _onSubmit,
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Confirm'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
