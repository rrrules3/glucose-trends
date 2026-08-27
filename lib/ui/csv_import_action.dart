import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/glucose_repository.dart';

/// Picks a Clarity CSV and merges it into the history, reporting the outcome.
///
/// Shared by the Settings row and the empty-state button so importing behaves
/// identically wherever it is started from — this is the only route into the
/// app for someone using it without a Dexcom developer account.
Future<void> importClarityCsv(
  BuildContext context,
  GlucoseRepository repo,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final picked = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['csv', 'txt'],
    dialogTitle: 'Select a Clarity CSV export',
  );
  if (picked == null) return;

  try {
    final bytes = await picked.readAsBytes();
    // Clarity exports are UTF-8, occasionally with a BOM or stray bytes.
    final result = await repo.importCsv(utf8.decode(bytes, allowMalformed: true));

    messenger.showSnackBar(SnackBar(
      content: Text(
        'Imported ${result.readings.length} readings from a '
        '${result.detectedUnit.label} export'
        '${result.skippedRows > 0 ? ' · ${result.skippedRows} non-glucose rows skipped' : ''}',
      ),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('$e'),
      duration: const Duration(seconds: 6),
    ));
  }
}
