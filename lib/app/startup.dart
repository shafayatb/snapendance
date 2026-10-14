import 'package:flutter/material.dart';

import '../features/uploads/data/upload_queue_repository.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

/// Opens upload storage and builds the app. Only a database that cannot open stops start-up;
/// the leftover-file check and WorkManager setup run again on the next launch.
Future<Widget> startApp({
  required Future<UploadQueueRepository> Function() openUploadQueue,
  required Future<void> Function() initializeScheduler,
  required Widget Function(UploadQueueRepository uploadQueue) buildApp,
}) async {
  final uploadQueue = await openUploadQueue();
  try {
    // Before the camera can capture (plan U3).
    await uploadQueue.reconcile();
  } on Exception catch (error) {
    debugPrint('Checking stored captures failed: $error');
  }
  try {
    await initializeScheduler();
  } on Object catch (error) {
    // Uploads then wait for the next launch; capture and the queue still work.
    debugPrint('Setting up background uploads failed: $error');
  }
  return buildApp(uploadQueue);
}

/// Runs [start] and shows its app; if it throws, a start-up error with Try again, so a storage
/// failure never leaves the app on its launch screen.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.start});

  final Future<Widget> Function() start;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<Widget> _app = widget.start();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _app,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.requireData;
        // A retry keeps the last error in its snapshot until it settles.
        if (snapshot.hasError &&
            snapshot.connectionState == ConnectionState.done) {
          debugPrint('Start-up failed: ${snapshot.error}');
          return _StartupError(
            onRetry: () => setState(() {
              _app = widget.start();
            }),
          );
        }
        return const ColoredBox(color: AppColors.background);
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Couldn’t start Snapendance',
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The app’s storage couldn’t be opened. Free up some space '
                      'if the phone is full, then try again.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
