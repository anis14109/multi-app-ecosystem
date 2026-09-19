import 'package:flutter/material.dart';
import 'package:flutter_app/auth/reset_password/cubit/reset_password_cubit.dart';
import 'package:flutter_app/auth/reset_password/password_reset_link.dart';
import 'package:flutter_app/auth/widgets/auth_header.dart';
import 'package:flutter_app/auth/widgets/form_fields.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reset the password using the token from the reset email
/// (`POST /auth/reset-password`).
///
/// The user pastes the reset link (or bare token) they received by email.
/// The link is parsed to extract the token and prefill the email address.
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ResetPasswordCubit(
        repository: context.read<AuthRepository>(),
      ),
      child: const ResetPasswordView(),
    );
  }
}

/// Presentational layer for the reset-password flow.
class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onLinkChanged(String value) {
    final parsed = PasswordResetLink.parse(value);
    if (parsed == null) return;
    if (_emailController.text.isEmpty && parsed.email != null) {
      _emailController.text = parsed.email!;
    }
  }

  String? _validateLink(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please paste the reset link from your email';
    }
    if (PasswordResetLink.parse(value) == null) {
      return 'Could not read the reset link';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final parsed = PasswordResetLink.parse(_linkController.text)!;
      await context.read<ResetPasswordCubit>().resetPassword(
        token: parsed.token,
        email: _emailController.text,
        password: _passwordController.text,
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
              icon: Icons.password_outlined,
              title: 'Reset Password',
              subtitle: 'Set a new password for your account',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                builder: (context, state) {
                  if (state is ResetPasswordSuccess) {
                    return _ResetSuccessPanel(
                      onDone: () => Navigator.of(context)
                        ..pop()
                        ..pop(),
                    );
                  }

                  final errorMessage = state is ResetPasswordError
                      ? state.message
                      : null;
                  final isLoading = state is ResetPasswordLoading;

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
                                  context.read<ResetPasswordCubit>().reset(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _linkController,
                            autofocus: true,
                            onChanged: _onLinkChanged,
                            textInputAction: TextInputAction.next,
                            maxLines: 2,
                            minLines: 1,
                            decoration: const InputDecoration(
                              labelText: 'Reset link',
                              hintText: 'Paste the link from the email',
                              prefixIcon: Icon(Icons.link_outlined),
                            ),
                            validator: _validateLink,
                          ),
                          const SizedBox(height: 16),
                          AuthEmailField(
                            controller: _emailController,
                            onFieldSubmitted: (_) => _onSubmit(),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          AuthPasswordField(
                            controller: _passwordController,
                            hintText: 'Minimum 8 characters',
                            onFieldSubmitted: (_) => _onSubmit(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a new password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AuthPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm New Password',
                            onFieldSubmitted: (_) => _onSubmit(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm the new password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
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
                                : const Text('Reset Password'),
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

/// Confirmation screen shown after a successful password reset.
class _ResetSuccessPanel extends StatelessWidget {
  const _ResetSuccessPanel({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Password updated',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your password has been changed and all other sessions '
              'were signed out for security.',
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
