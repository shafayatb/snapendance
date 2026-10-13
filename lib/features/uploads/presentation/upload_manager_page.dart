import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/dashed_border.dart';
import '../data/upload_queue_repository.dart';
import '../domain/upload_models.dart';
import 'uploads_cubit.dart';
import 'uploads_state.dart';

/// The Upload Manager (U1-U5, light theme), reached only from the camera.
class UploadManagerPage extends StatelessWidget {
  const UploadManagerPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const UploadManagerPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          UploadsCubit(context.read<UploadQueueRepository>())..start(),
      child: const UploadManagerView(),
    );
  }
}

class UploadManagerView extends StatefulWidget {
  const UploadManagerView({super.key});

  @override
  State<UploadManagerView> createState() => _UploadManagerViewState();
}

class _UploadManagerViewState extends State<UploadManagerView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // The worker may have uploaded while the app was in the background.
    if (lifecycle == AppLifecycleState.resumed) {
      context.read<UploadsCubit>().appResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back to camera',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text('Upload Manager', style: textTheme.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<UploadsCubit, UploadsState>(
                  builder: (context, state) {
                    if (!state.loaded) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.batches.isEmpty) return const _EmptyState();
                    return _UploadList(state: state);
                  },
                ),
              ),
              const _StartNewBatchBar(),
            ],
          ),
        ),
      ),
    );
  }
}

/// One list entry: the progress card, a heading, a batch header, an item, or a collapsed line.
sealed class _Entry {
  const _Entry();
}

class _ProgressEntry extends _Entry {
  const _ProgressEntry();
}

class _HeadingEntry extends _Entry {
  const _HeadingEntry();
}

class _BatchEntry extends _Entry {
  const _BatchEntry(this.batch);
  final QueuedBatch batch;
}

class _ItemEntry extends _Entry {
  const _ItemEntry(this.item);
  final UploadItem item;
}

class _MoreSyncedEntry extends _Entry {
  const _MoreSyncedEntry(this.count);
  final int count;
}

class _UploadList extends StatelessWidget {
  const _UploadList({required this.state});

  final UploadsState state;

  /// Unfinished items, then the newest synced one; older synced items collapse into a line
  /// (deviation U1: "n more synced").
  List<_Entry> _entries() {
    final entries = <_Entry>[const _ProgressEntry(), const _HeadingEntry()];
    for (final batch in state.batches) {
      entries.add(_BatchEntry(batch));
      final synced =
          batch.items
              .where((item) => item.status == ItemStatus.uploaded)
              .toList()
            ..sort((a, b) => b.uploadedAt!.compareTo(a.uploadedAt!));
      for (final item in batch.items) {
        if (item.status != ItemStatus.uploaded) entries.add(_ItemEntry(item));
      }
      if (synced.isNotEmpty) entries.add(_ItemEntry(synced.first));
      if (synced.length > 1) entries.add(_MoreSyncedEntry(synced.length - 1));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: entries.length,
      itemBuilder: (context, index) => switch (entries[index]) {
        _ProgressEntry() => _ProgressCard(state: state),
        _HeadingEntry() => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(
            'PENDING UPLOADS (${state.pending})',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.04,
            ),
          ),
        ),
        _BatchEntry(:final batch) => _BatchHeader(batch: batch),
        _ItemEntry(:final item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ItemRow(item: item),
        ),
        _MoreSyncedEntry(:final count) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '$count more synced in this batch',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final UploadsState state;

  String get _note {
    final uploading = state.count(ItemStatus.uploading);
    if (uploading > 0) {
      return 'Uploading $uploading ${uploading == 1 ? 'photo' : 'photos'}';
    }
    if (state.has(ItemStatus.retrying)) return 'Retrying automatically';
    if (state.has(ItemStatus.pending)) return 'Waiting to upload';
    return 'Needs your attention';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = state.total == 0 ? 0.0 : state.uploaded / state.total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BATCH SYNC PROGRESS',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.04,
                  ),
                ),
              ),
              Text(
                '${(fraction * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Bar(value: fraction, height: 8),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${state.uploaded} of ${state.total} uploaded',
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  _note,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: AppColors.primary,
        backgroundColor: AppColors.disabledContainer,
      ),
    );
  }
}

String _when(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final clock = DateFormat('HH:mm').format(time);
  if (day == today) return 'Today $clock';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $clock';
  return '${DateFormat('d MMM').format(time)} $clock';
}

class _BatchHeader extends StatelessWidget {
  const _BatchHeader({required this.batch});

  final QueuedBatch batch;

  @override
  Widget build(BuildContext context) {
    final total = batch.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Batch ${batch.id}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' · ${_when(batch.submittedAt)}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${batch.uploadedCount} of $total uploaded',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Bar(value: batch.uploadedCount / total, height: 4),
        ],
      ),
    );
  }
}

String _size(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).ceil()} KB';
}

/// The status line's color, icon, and label (U1-U3, with deviations U3).
(Color, IconData, String) _status(UploadItem item) => switch (item.status) {
  ItemStatus.pending => (
    AppStatusColors.queued,
    Icons.schedule_rounded,
    'QUEUED',
  ),
  ItemStatus.uploading => (
    AppStatusColors.uploading,
    Icons.arrow_upward_rounded,
    'UPLOADING',
  ),
  ItemStatus.retrying => (
    AppStatusColors.pending,
    Icons.autorenew_rounded,
    'RETRYING · ATTEMPT ${item.attempts}/$maxUploadAttempts',
  ),
  ItemStatus.uploaded => (
    AppStatusColors.synced,
    Icons.check_circle_rounded,
    'SYNCED ${DateFormat('HH:mm').format(item.uploadedAt!)}',
  ),
  ItemStatus.failed => (
    AppStatusColors.failed,
    Icons.error_rounded,
    // An exhausted item's stored error already starts with "Failed after 5 attempts".
    (item.lastError ?? '').startsWith('Failed')
        ? item.lastError!.toUpperCase()
        : 'FAILED · ${(item.lastError ?? 'unknown error').toUpperCase()}',
  ),
};

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final UploadItem item;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _status(item);
    final cubit = context.read<UploadsCubit>();
    final action = switch (item) {
      UploadItem(fileMissing: true) => ('Remove', () => cubit.remove(item.id)),
      UploadItem(status: ItemStatus.failed) => (
        'Retry',
        () => cubit.retry(item.id),
      ),
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          _Thumbnail(item: item),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 15,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.fileMissing
                      ? '— · file not found'
                      : _size(item.sizeBytes),
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.52,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action.$2,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(action.$1),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});

  final UploadItem item;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.disabledContainer,
      child: SizedBox.square(dimension: _size),
    );
    if (item.fileMissing) {
      return const DashedBorder(
        color: AppColors.onSurfaceVariant,
        radius: 8,
        child: SizedBox.square(
          dimension: _size,
          child: Icon(
            Icons.hide_image_outlined,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      // Decoded at display size, so long lists stay light.
      child: Image.file(
        File(item.filePath),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        cacheWidth: (_size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

/// U5.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppStatusColors.syncedContainer,
              child: Icon(
                Icons.cloud_done_outlined,
                size: 34,
                color: AppStatusColors.synced,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Nothing waiting to upload',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'New photo batches appear here until every image is synced.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back to the camera, whose open batch is where the next photos go.
class _StartNewBatchBar extends StatelessWidget {
  const _StartNewBatchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: FilledButton.icon(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('START NEW UPLOAD BATCH'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}
