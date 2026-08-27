import 'package:csv/csv.dart';

import '../../models/glucose_reading.dart';
import '../../util/units.dart';

class CsvImportException implements Exception {
  CsvImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CsvImportResult {
  const CsvImportResult({
    required this.readings,
    required this.skippedRows,
    required this.detectedUnit,
  });

  final List<GlucoseReading> readings;

  /// Non-EGV rows (calibrations, carbs, insulin, the patient-info header rows)
  /// plus anything unparseable. Surfaced so a mostly-bad file is obvious.
  final int skippedRows;

  final GlucoseUnit detectedUnit;
}

/// Parses a Dexcom Clarity "Export data" CSV.
///
/// The export's exact columns vary by region, account type and unit setting, so
/// columns are located by header text rather than by fixed index.
class ClarityCsvImporter {
  static const _lowSentinelMgdl = 39;
  static const _highSentinelMgdl = 401;

  CsvImportResult parse(String contents) {
    // dynamicTyping off: glucose cells may be the literal strings "Low"/"High",
    // and timestamps must stay as text.
    final rows = Csv(dynamicTyping: false).decode(contents);

    if (rows.isEmpty) throw CsvImportException('The file is empty.');

    final header = rows.first.map((c) => c.toString().trim()).toList();
    final timestampCol = _findColumn(header, ['timestamp', 'device timestamp']);
    final mgdlCol = _findColumn(header, ['glucose value (mg/dl)']);
    final mmolCol = _findColumn(header, ['glucose value (mmol/l)']);
    final glucoseCol = mgdlCol ?? mmolCol ?? _findColumn(header, ['glucose']);
    final eventTypeCol = _findColumn(header, ['event type']);

    if (timestampCol == null || glucoseCol == null) {
      throw CsvImportException(
          'This does not look like a Clarity export — no timestamp/glucose '
          'columns found. Export from Clarity with "Export data → CSV".');
    }

    final unit = mmolCol != null && mgdlCol == null
        ? GlucoseUnit.mmoll
        : GlucoseUnit.mgdl;

    final byTime = <DateTime, GlucoseReading>{};
    var skipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= glucoseCol || row.length <= timestampCol) {
        skipped++;
        continue;
      }

      // Clarity exports interleave EGV rows with carb/insulin/calibration rows
      // and a few patient-info rows at the top.
      if (eventTypeCol != null && row.length > eventTypeCol) {
        final type = row[eventTypeCol].toString().trim().toUpperCase();
        if (type.isNotEmpty && type != 'EGV') {
          skipped++;
          continue;
        }
      }

      final time = _parseTimestamp(row[timestampCol].toString().trim());
      final mgdl = _parseGlucose(row[glucoseCol].toString().trim(), unit);
      if (time == null || mgdl == null) {
        skipped++;
        continue;
      }

      byTime[time] = GlucoseReading(time: time, valueMgdl: mgdl);
    }

    if (byTime.isEmpty) {
      throw CsvImportException(
          'No glucose readings found in the file (${rows.length - 1} rows read).');
    }

    final readings = byTime.values.toList()..sort();
    return CsvImportResult(
      readings: readings,
      skippedRows: skipped,
      detectedUnit: unit,
    );
  }

  static int? _findColumn(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      for (var i = 0; i < header.length; i++) {
        if (header[i].toLowerCase().contains(candidate)) return i;
      }
    }
    return null;
  }

  static DateTime? _parseTimestamp(String raw) {
    if (raw.isEmpty) return null;
    // Clarity writes `2024-05-01T08:32:11`, but some regional exports use a
    // space separator instead of `T`.
    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  /// Values outside the sensor's 40–400 mg/dL reporting range come through as
  /// the literal strings "Low" and "High".
  static int? _parseGlucose(String raw, GlucoseUnit unit) {
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower == 'low') return _lowSentinelMgdl;
    if (lower == 'high') return _highSentinelMgdl;

    final parsed = double.tryParse(raw);
    if (parsed == null) return null;
    return unit.toMgdl(parsed).round();
  }
}
