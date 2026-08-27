import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/glucose_reading.dart';
import '../../models/trend.dart';
import 'dexcom_auth.dart';

class DexcomApiException implements Exception {
  DexcomApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// The window of data Dexcom holds for this account.
class DexcomDataRange {
  const DexcomDataRange({this.start, this.end});
  final DateTime? start;
  final DateTime? end;
  bool get isEmpty => start == null || end == null;
}

/// Thin client over the Dexcom API v3 EGV endpoints.
class DexcomApiClient {
  DexcomApiClient(this._auth, {http.Client? client})
      : _http = client ?? http.Client();

  final DexcomAuth _auth;
  final http.Client _http;

  /// The API rejects any single `/egvs` query spanning more than 30 days:
  ///
  ///     {"message":"Invalid Date Range Error",
  ///      "errors":[{"parameter":"dateRange","detail":"range exceeds 30 days"}]}
  ///
  /// Longer requests are split into chunks under that limit. (Dexcom's own
  /// docs describe a 90-day maximum; the live API enforces 30.)
  static const _maxChunk = Duration(days: 29);

  String get _base =>
      (_auth.credentials?.environment ?? DexcomEnvironment.sandbox).baseUrl;

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final token = await _auth.accessToken();
    final uri = Uri.parse('$_base$path')
        .replace(queryParameters: query?.isEmpty ?? true ? null : query);

    final response = await _http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (response.statusCode == 429) {
      throw DexcomApiException(
          'Dexcom rate limit reached. Try again in a few minutes.',
          statusCode: 429);
    }
    if (response.statusCode != 200) {
      throw DexcomApiException(
          'Dexcom API error ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Earliest and latest EGV Dexcom has for this account.
  Future<DexcomDataRange> dataRange() async {
    final json = await _get('/v3/users/self/dataRange');
    final egvs = json['egvs'] as Map<String, dynamic>?;
    if (egvs == null) return const DexcomDataRange();
    return DexcomDataRange(
      start: _parseRangeEnd(egvs['start']),
      end: _parseRangeEnd(egvs['end']),
    );
  }

  static DateTime? _parseRangeEnd(dynamic node) {
    if (node is! Map) return null;
    final raw = node['displayTime'] ?? node['systemTime'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  /// Fetch every EGV between [start] and [end], chunking as required.
  ///
  /// Results are sorted ascending and de-duplicated by timestamp.
  Future<List<GlucoseReading>> fetchEgvs({
    required DateTime start,
    required DateTime end,
    void Function(double progress)? onProgress,
  }) async {
    if (!start.isBefore(end)) return const [];

    final chunks = chunkDateRange(start, end, maxChunk: _maxChunk);

    final byTime = <DateTime, GlucoseReading>{};
    for (var i = 0; i < chunks.length; i++) {
      final (chunkStart, chunkEnd) = chunks[i];
      final json = await _get('/v3/users/self/egvs', {
        'startDate': _formatDexcomDate(chunkStart),
        'endDate': _formatDexcomDate(chunkEnd),
      });
      for (final r in parseEgvRecords(json)) {
        byTime[r.time] = r;
      }
      onProgress?.call((i + 1) / chunks.length);
    }

    final out = byTime.values.toList()..sort();
    return out;
  }

  /// Dexcom expects a naive local timestamp — sending an offset or `Z` is
  /// rejected, so the zone designator is deliberately stripped.
  static String _formatDexcomDate(DateTime t) {
    String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
    final l = t.toLocal();
    return '${p(l.year, 4)}-${p(l.month)}-${p(l.day)}'
        'T${p(l.hour)}:${p(l.minute)}:${p(l.second)}';
  }
}

/// Split `[start, end]` into consecutive windows no longer than [maxChunk].
///
/// Exposed for testing: exceeding Dexcom's per-request limit fails the whole
/// sync with a 400, and the limit is smaller than their documentation states.
List<(DateTime, DateTime)> chunkDateRange(
  DateTime start,
  DateTime end, {
  required Duration maxChunk,
}) {
  final chunks = <(DateTime, DateTime)>[];
  var cursor = start;
  while (cursor.isBefore(end)) {
    final next = cursor.add(maxChunk);
    chunks.add((cursor, next.isAfter(end) ? end : next));
    cursor = next;
  }
  return chunks;
}

/// The largest window Dexcom accepts in one `/egvs` request.
const kDexcomMaxRequestSpan = Duration(days: 30);

/// Parse a v3 `/egvs` response body into readings.
///
/// Exposed separately from the HTTP layer so it can be unit-tested against
/// captured fixtures.
List<GlucoseReading> parseEgvRecords(Map<String, dynamic> json) {
  final records = json['records'];
  if (records is! List) return const [];

  final out = <GlucoseReading>[];
  for (final raw in records) {
    if (raw is! Map) continue;

    // `value` is null when the sensor reported Low/High instead of a number.
    final value = raw['value'];
    final status = raw['status'] as String?;
    int? mgdl;
    if (value is num) {
      mgdl = value.round();
    } else if (status == 'low') {
      mgdl = 39;
    } else if (status == 'high') {
      mgdl = 401;
    }
    if (mgdl == null) continue;

    final timeRaw = raw['displayTime'] ?? raw['systemTime'];
    if (timeRaw is! String) continue;
    final time = DateTime.tryParse(timeRaw);
    if (time == null) continue;

    out.add(GlucoseReading(
      // displayTime is already the user's local wall clock; parsing it must not
      // shift it, so it is kept as an unzoned local value.
      time: DateTime(time.year, time.month, time.day, time.hour, time.minute,
          time.second),
      valueMgdl: mgdl,
      trend: GlucoseTrend.parse(raw['trend'] as String?),
    ));
  }
  out.sort();
  return out;
}
