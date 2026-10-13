import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_tokens.dart';

/// The app's entry point (design frame H1): a header and one card per feature.
///
/// The Attendance card shows a static subtitle. Attendance data is stored by
/// the native Android screen and is not shared with Flutter.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Snapendance', style: textTheme.headlineLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      DateFormat('EEE, d MMM').format(DateTime.now()),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _FeatureCard(
                  icon: Icons.location_on_outlined,
                  title: 'Attendance',
                  subtitle: 'Office setup and check-in',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // H1 sets card titles at 17 px, between titleMedium and labelLarge.
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox.square(
                dimension: 48,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
