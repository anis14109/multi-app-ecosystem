import 'package:flutter/material.dart';
import 'package:flutter_app/auth/email_verification/cubit/email_verification_cubit.dart';
import 'package:flutter_app/auth/widgets/auth_header.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Email verification screen.
///
/// Lets an authenticated user:
/// - paste the signed verification link from their email to verify the
///   address (`GET /auth/email/verify/{id}/{hash}?expires=&signature=`),
/// - or resend the notification (`POST /auth/email/verification-notification`).
class EmailVerificationPage extends StatelessWidget {
  const EmailVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EmailVerificationCubit(
        repository: context.read<AuthRepository>(),
      ),
      child: const EmailVerificationView(),
    );
  }
}

/// Presentational layer for the email-verification flow.
class EmailVerificationView extends StatefulWidget {
  const EmailVerificationView({super.key});

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView> {
  final _linkController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              icon: Icons.mark_email_read_outlined,
              title: 'Verify Email',
              subtitle: 'Confirm your email address to unlock full access',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child:
                  BlocBuilder<EmailVerificationCubit, EmailVerificationState>(
                    builder: (context, state) {
                      if (state is EmailVerificationVerified) {
                        return _VerifiedPanel(
                          onDone: () => Navigator.of(context).pop(),
                        );
                      }

                      final isVerifying = state is EmailVerificationVerifying;
                      final isResending = state is EmailVerificationResending;
                      final verifyError = state is EmailVerificationError
                          ? state.message
                          : null;
                      final resendMessage = state is EmailVerificationResent
                          ? state.message
                          : null;
                      final resendError = state is EmailVerificationResendError
                          ? state.message
                          : null;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (verifyError != null) ...[
                              AuthErrorBanner(
                                message: verifyError,
                                onDismiss: () => context
                                    .read<EmailVerificationCubit>()
                                    .reset(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.mail_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Text(
                                        'Check your inbox for the verification '
                                        'link, then paste it below to confirm '
                                        'your address.',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _linkController,
                              autofocus: true,
                              maxLines: 2,
                              minLines: 1,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _verify(),
                              decoration: const InputDecoration(
                                labelText: 'Verification link',
                                hintText: 'Paste the link from the email',
                                prefixIcon: Icon(Icons.link_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: isVerifying ? null : _verify,
                              child: isVerifying
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Verify Email'),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              "Didn't get a link?",
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            if (resendMessage != null) ...[
                              _InfoMessage(message: resendMessage),
                              const SizedBox(height: 8),
                            ],
                            if (resendError != null) ...[
                              AuthErrorBanner(
                                message: resendError,
                                onDismiss: () => context
                                    .read<EmailVerificationCubit>()
                                    .reset(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: isResending ? null : _resend,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                isResending
                                    ? 'Sending...'
                                    : 'Resend Verification Email',
                              ),
                            ),
                          ],
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

  Future<void> _verify() async {
    await context.read<EmailVerificationCubit>().verifyLink(
      _linkController.text,
    );
  }

  Future<void> _resend() async {
    await context.read<EmailVerificationCubit>().resend();
  }
}

/// Success panel shown after the email address is verified.
class _VerifiedPanel extends StatelessWidget {
  const _VerifiedPanel({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.verified_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Email verified',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your email address is confirmed. You now have full '
              'access to all app features.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neutral (non-error) feedback message with a check icon.
class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
