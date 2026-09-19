import 'package:flutter/material.dart';
import 'package:flutter_app/auth/bloc/auth_bloc.dart';
import 'package:flutter_app/auth/bloc/auth_event.dart';
import 'package:flutter_app/auth/bloc/auth_state.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Profile page showing the authenticated user's account details.
///
/// Displays the freshest [UserModel] (fetched via `/api/v1/auth/me`)
/// with a manual refresh action and a logout button. Fields follow the
/// Laravel `UserResource` contract: email verification, two-factor
/// status, and member-since date.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthRefreshRequested());
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = state is AuthenticatedOnline
                ? state.user
                : state is AuthenticatedOffline
                ? state.user
                : null;
            if (user == null) {
              return const Center(child: Text('No profile data available.'));
            }

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _ProfileHero(user: user),
                const SizedBox(height: 24),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'User ID',
                  value: '${user.id}',
                ),
                _InfoTile(
                  icon: Icons.alternate_email,
                  label: 'Email',
                  value: user.email,
                ),
                _InfoTile(
                  icon: Icons.verified_outlined,
                  label: 'Email verified',
                  value: user.isEmailVerified ? 'Yes' : 'No',
                  valueIcon: user.isEmailVerified
                      ? Icons.check_circle
                      : Icons.cancel,
                ),
                _InfoTile(
                  icon: Icons.key_outlined,
                  label: 'Two-factor authentication',
                  value: user.twoFactorEnabled ? 'Enabled' : 'Not enabled',
                ),
                _InfoTile(
                  icon: Icons.event_outlined,
                  label: 'Member since',
                  value: _formatDate(user.createdAt),
                ),
                _InfoTile(
                  icon: Icons.update,
                  label: 'Last updated',
                  value: _formatDate(user.updatedAt),
                ),
                const SizedBox(height: 32),
                if (!user.isEmailVerified) ...[
                  _VerificationCard(userEmail: user.email),
                  const SizedBox(height: 24),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/password-confirmation');
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Confirm Password'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogoutAll(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out of All Devices'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthLogoutRequested());
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Format an ISO-8601 timestamp for display, or a placeholder.
  String _formatDate(String? iso) {
    final parsed = iso != null ? DateTime.tryParse(iso) : null;
    if (parsed == null) return '—';
    return DateFormat.yMMMMd().format(parsed.toLocal());
  }

  /// Ask for confirmation before revoking every session.
  Future<void> _confirmLogoutAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of all devices?'),
        content: const Text(
          'This will sign out every device currently signed in to '
          'your account, including this one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      context.read<AuthBloc>().add(const AuthLogoutAllRequested());
    }
  }
}

/// Gradient header block with avatar and full name.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user.name.isNotEmpty ? user.name : 'User';
    final initial = name[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: scheme.primary,
            child: Text(
              initial,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label/value row used for the account detail list.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueIcon,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData? valueIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (valueIcon != null) ...[
                      Icon(
                        valueIcon,
                        size: 16,
                        color: value.toLowerCase() == 'yes'
                            ? Colors.green
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Info block shown when the email address has not been verified yet.
class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.userEmail});

  final String userEmail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.mark_email_unread_outlined, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              'Verify your email',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Your address $userEmail is not verified yet. Some '
              'features are unavailable until you confirm it.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/email-verification');
              },
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Verify Now'),
            ),
          ],
        ),
      ),
    );
  }
}
