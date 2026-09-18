import 'package:flutter/material.dart';

import 'package:flutter_app/core/services/env_config.dart';

/// Decorative gradient header shown at the top of the auth screens.
///
/// Displays the brand mark (from [EnvConfig.appName]), an optional
/// headline, and a supporting subtitle on a soft gradient that
/// matches the active color scheme.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.title,
    this.subtitle,
    this.icon = Icons.apps,
    this.onBack,
  });

  /// Headline shown under the brand mark. Defaults to the app name.
  final String? title;

  /// Optional supporting text under the headline.
  final String? subtitle;

  /// Icon rendered inside the decorative badge.
  final IconData icon;

  /// When provided, renders a back button at the top of the header that
  /// calls this callback (used by pushed auth screens).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                tooltip: 'Back',
                icon: Icon(
                  Icons.arrow_back,
                  color: scheme.onPrimaryContainer,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface.withValues(alpha: 0.5),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title ?? EnvConfig.appName,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact dismissible error banner for inline auth feedback.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    required this.message, required this.onDismiss, super.key,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            icon: Icon(Icons.close, color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
