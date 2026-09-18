import 'package:flutter/material.dart';
import 'package:flutter_app/auth/bloc/auth_bloc.dart';
import 'package:flutter_app/auth/bloc/auth_event.dart';
import 'package:flutter_app/auth/bloc/auth_state.dart';
import 'package:flutter_app/core/services/env_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Home dashboard displayed after successful authentication.
///
/// Greets the user with a gradient hero, shows their online/offline
/// status, and provides quick navigation cards (profile, account,
/// about) plus a logout action.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError &&
              (state.previousState is AuthenticatedOnline ||
                  state.previousState is AuthenticatedOffline)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isOnline = state is AuthenticatedOnline;
            final user = state is AuthenticatedOnline
                ? state.user
                : state is AuthenticatedOffline
                    ? state.user
                    : null;

            final name = user?.name ?? 'User';
            final email = user?.email ?? '';

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 220,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.85),
                      child: Icon(
                        Icons.apps,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(EnvConfig.appName),
                  actions: [
                    IconButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(
                              const AuthLogoutRequested(),
                            );
                      },
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout',
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 64, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, $name',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (email.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Chip(
                            avatar: Icon(
                              isOnline
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                              size: 18,
                              color: isOnline
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            label: Text(
                              isOnline
                                  ? 'Connected'
                                  : 'Offline Mode',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        'Quick Actions',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _ActionCard(
                        icon: Icons.account_circle_outlined,
                        title: 'My Profile',
                        subtitle: 'View your account details',
                        onTap: () => Navigator.of(context).pushNamed('/profile'),
                      ),
                      const SizedBox(height: 12),
                      const _ActionCard(
                        icon: Icons.shield_outlined,
                        title: 'Security',
                        subtitle: 'PIN & biometric unlock settings',
                        onTap: null,
                      ),
                      const SizedBox(height: 12),
                      const _ActionCard(
                        icon: Icons.info_outline,
                        title: 'About',
                        subtitle: 'App version and information',
                        onTap: null,
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.offline_pin_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'The app works fully offline after '
                                  'unlocking. Your local data stays '
                                  'protected even without the internet.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tappable dashboard shortcut card.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap != null
            ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
            : null,
      ),
    );
  }
}
