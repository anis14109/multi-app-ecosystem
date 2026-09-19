import 'package:flutter/material.dart';
import 'package:flutter_app/auth/forgot_password/cubit/forgot_password_cubit.dart';
import 'package:flutter_app/auth/widgets/auth_header.dart';
import 'package:flutter_app/auth/widgets/form_fields.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Request a password-reset link (`POST /auth/forgot-password`).
///
/// Pushed from the login screen. On success the page presents a confirmation
/// and a way back to login. Errors are shown inline via [AuthErrorBanner].
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForgotPasswordCubit(
        repository: context.read<AuthRepository>(),
      ),
      child: const ForgotPasswordView(),
    );
  }
}

/// Presentational layer for the forgot-password flow.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      await context.read<ForgotPasswordCubit>().forgotPassword(
        _emailController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              icon: Icons.lock_reset_outlined,
              title: 'Forgot Password',
              subtitle: 'Enter your email to receive a reset link',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                builder: (context, state) {
                  if (state is ForgotPasswordSuccess) {
                    return _SuccessPanel(
                      email: _emailController.text.trim(),
                      onDone: () => Navigator.of(context).pop(),
                    );
                  }

                  final errorMessage = state is ForgotPasswordError
                      ? state.message
                      : null;
                  final isLoading = state is ForgotPasswordLoading;

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
                              onDismiss: () =>
                                  context.read<ForgotPasswordCubit>().reset(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          AuthEmailField(
                            controller: _emailController,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _onSubmit(),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: isLoading ? null : _onSubmit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Send Reset Link'),
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

/// Confirmation screen shown after the reset-link request succeeds.
class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.email, required this.onDone});

  final String email;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 64,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Check your inbox',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'If an account exists for $email, a password reset link '
              'has been sent. The link expires in 60 minutes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onDone,
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
