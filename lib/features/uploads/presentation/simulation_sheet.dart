import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/upload_models.dart';
import 'batch_cubit.dart';
import 'batch_state.dart';

// The sheet is part of the always-dark camera (C11).
const _sheetColor = Color(0xFF1E232C);
const _text = Color(0xFFE6EAF1);
const _textVariant = Color(0xFF9BA5B6);
const _selected = Color(0xFF8DB2FF);
const _mockBadge = Color(0xFF3A2E14);
const _mockBadgeText = Color(0xFFF2B65A);
const _primary = Color(0xFF2F66DC);

/// Opens the "Upload simulation" sheet (C11). It ships in release, labeled MOCK API (plan U13).
Future<void> showSimulationSheet(BuildContext context) {
  // The sheet is its own route; hand it the caller's Cubit.
  final cubit = context.read<BatchCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _sheetColor,
    barrierColor: const Color(0x99000000),
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const SimulationSheet()),
  );
}

class SimulationSheet extends StatelessWidget {
  const SimulationSheet({super.key});

  static const _options = [
    (MockScenario.success, 'Success', 'Every upload returns 200 OK'),
    (
      MockScenario.failOnce,
      'Fail once, then succeed',
      'First attempt errors, the retry succeeds',
    ),
    (
      MockScenario.timeout,
      'Timeout (slow network)',
      'No reply for 30 s, request times out',
    ),
    (
      MockScenario.noNetwork,
      'No network',
      'Behaves as if the device is offline',
    ),
    (
      MockScenario.permanentFailure,
      'Permanent failure',
      'Always rejected; items end as Failed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Upload simulation',
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _mockBadge,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 14,
                          color: _mockBadgeText,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'MOCK API',
                          style: TextStyle(
                            color: _mockBadgeText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.88,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                'Chooses how the mock server answers the next uploads. No photos leave the '
                'device. For testing the sync engine only.',
                style: TextStyle(
                  color: _textVariant,
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
            ),
            BlocSelector<BatchCubit, BatchState, MockScenario>(
              selector: (state) => state.scenario,
              builder: (context, scenario) => RadioGroup<MockScenario>(
                groupValue: scenario,
                onChanged: (value) {
                  if (value != null) {
                    context.read<BatchCubit>().setScenario(value);
                  }
                },
                child: Column(
                  children: [
                    for (final (value, label, detail) in _options)
                      RadioListTile<MockScenario>(
                        value: value,
                        tileColor: Colors.transparent,
                        selectedTileColor: const Color(0x1A8DB2FF),
                        selected: value == scenario,
                        activeColor: _selected,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        title: Text(
                          label,
                          style: const TextStyle(color: _text, fontSize: 16),
                        ),
                        subtitle: Text(
                          detail,
                          style: const TextStyle(
                            color: _textVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
