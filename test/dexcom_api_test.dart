import 'dart:convert';

import 'package:glucose_trends/data/sources/dexcom_api_client.dart';
import 'package:glucose_trends/models/trend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shaped like a Dexcom API v3 `/users/self/egvs` response.
const _body = '''
{
  "recordType": "egv",
  "recordVersion": "3.0",
  "userId": "abc-123",
  "records": [
    {
      "recordId": "1",
      "systemTime": "2024-05-01T15:00:00",
      "displayTime": "2024-05-01T08:00:00",
      "value": 112,
      "trend": "fortyFiveUp",
      "trendRate": 1.4,
      "unit": "mg/dL",
      "transmitterGeneration": "g7"
    },
    {
      "recordId": "2",
      "systemTime": "2024-05-01T15:05:00",
      "displayTime": "2024-05-01T08:05:00",
      "value": null,
      "status": "low",
      "trend": "doubleDown",
      "unit": "mg/dL"
    },
    {
      "recordId": "3",
      "systemTime": "2024-05-01T15:10:00",
      "displayTime": "2024-05-01T08:10:00",
      "value": null,
      "status": "high",
      "trend": "flat",
      "unit": "mg/dL"
    }
  ]
}
''';

void main() {
  test('parses records into readings using display time', () {
    final readings =
        parseEgvRecords(jsonDecode(_body) as Map<String, dynamic>);

    expect(readings, hasLength(3));
    expect(readings.first.valueMgdl, 112);
    expect(readings.first.trend, GlucoseTrend.fortyFiveUp);
    // displayTime is the user's wall clock and must not be shifted.
    expect(readings.first.time, DateTime(2024, 5, 1, 8));
  });

  test('maps low/high status records to the sensor reporting limits', () {
    final readings =
        parseEgvRecords(jsonDecode(_body) as Map<String, dynamic>);

    expect(readings[1].valueMgdl, 39);
    expect(readings[2].valueMgdl, 401);
  });

  test('drops records that carry neither a value nor a status', () {
    final readings = parseEgvRecords({
      'records': [
        {'displayTime': '2024-05-01T08:00:00', 'value': null},
        {'displayTime': '2024-05-01T08:05:00', 'value': 120},
      ],
    });
    expect(readings, hasLength(1));
  });

  test('drops records with an unparseable timestamp', () {
    final readings = parseEgvRecords({
      'records': [
        {'displayTime': 'not-a-date', 'value': 120},
        {'value': 120},
      ],
    });
    expect(readings, isEmpty);
  });

  test('falls back to systemTime when displayTime is absent', () {
    final readings = parseEgvRecords({
      'records': [
        {'systemTime': '2024-05-01T15:00:00', 'value': 120},
      ],
    });
    expect(readings.single.time, DateTime(2024, 5, 1, 15));
  });

  test('unknown trend strings degrade to none rather than throwing', () {
    final readings = parseEgvRecords({
      'records': [
        {
          'displayTime': '2024-05-01T08:00:00',
          'value': 120,
          'trend': 'somethingNew',
        },
      ],
    });
    expect(readings.single.trend, GlucoseTrend.none);
  });

  group('chunkDateRange', () {
    final start = DateTime(2026, 1, 1);

    test('splits a 90-day span into windows Dexcom will accept', () {
      final chunks = chunkDateRange(
        start,
        start.add(const Duration(days: 90)),
        maxChunk: const Duration(days: 29),
      );

      expect(chunks, isNotEmpty);
      for (final (from, to) in chunks) {
        expect(
          to.difference(from),
          lessThanOrEqualTo(kDexcomMaxRequestSpan),
          reason: 'a chunk longer than 30 days is rejected with a 400',
        );
      }
    });

    test('covers the whole span with no gaps or overlaps', () {
      final end = start.add(const Duration(days: 90));
      final chunks =
          chunkDateRange(start, end, maxChunk: const Duration(days: 29));

      expect(chunks.first.$1, start);
      expect(chunks.last.$2, end);
      for (var i = 1; i < chunks.length; i++) {
        expect(chunks[i].$1, chunks[i - 1].$2);
      }
    });

    test('a short span needs a single request', () {
      final chunks = chunkDateRange(
        start,
        start.add(const Duration(days: 3)),
        maxChunk: const Duration(days: 29),
      );
      expect(chunks, hasLength(1));
    });

    test('an inverted or empty span produces no requests', () {
      expect(
        chunkDateRange(start, start, maxChunk: const Duration(days: 29)),
        isEmpty,
      );
      expect(
        chunkDateRange(start, start.subtract(const Duration(days: 1)),
            maxChunk: const Duration(days: 29)),
        isEmpty,
      );
    });
  });

  test('an empty or malformed body yields no readings', () {
    expect(parseEgvRecords({'records': []}), isEmpty);
    expect(parseEgvRecords({}), isEmpty);
    expect(parseEgvRecords({'records': 'nope'}), isEmpty);
  });
}
