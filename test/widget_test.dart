import 'package:flutter_test/flutter_test.dart';
import 'package:noor_sharik/core/supabase_config.dart';
import 'package:noor_sharik/data/models.dart';
import 'package:noor_sharik/data/sharik_repository.dart';

Map<String, dynamic> _orderMap({
  String status = 'released',
  List<Map<String, dynamic>> lines = const [],
}) => {
  'id': 'order-1',
  'number': 'NT-2026-0164-A',
  'status': status,
  'total': 14320,
  'currency': 'USD',
  'promised_ship_date': '2026-09-28',
  'expected_arrival_date': '2026-10-14',
  'lead_time_days': 40,
  'updated_at': '2026-08-19T10:00:00+00:00',
  'manufacturer_order_lines': lines,
};

Map<String, dynamic> _lineMap({
  required String id,
  required int pcs,
  required int packs,
  required String hex,
  required String colourName,
}) => {
  'id': id,
  'pcs': pcs,
  'packs': packs,
  'unit_price': 9.80,
  'line_total': pcs * 9.80,
  'styles': {
    'code': 'D-4482',
    'name': 'Linen Wrap Dress',
    'fabric': 'Washed linen',
    'composition': '55% linen',
    'gsm': 210,
  },
  'colourways': {'name': colourName, 'hex': hex},
  'ratio_packs': {
    'ratio': {'S': 2, 'M': 3, 'L': 3, 'XL': 2},
    'pcs_per_pack': 10,
  },
};

Map<String, dynamic> _stepMap({
  required String id,
  required int sort,
  required String status,
  String name = 'Stage',
}) => {
  'id': id,
  'status': status,
  'qty_in': null,
  'qty_out': null,
  'expected_at': '2026-08-30',
  'completed_at': null,
  'note': null,
  'production_stages': {
    'code': 'code-$sort',
    'name': name,
    'sort': sort,
    'requires_media': true,
  },
};

void main() {
  group('the commercial rule: a seller sees an order only once released', () {
    test('pre-release statuses are never queryable', () {
      for (final hidden in const [
        'quoting',
        'proforma_issued',
        'negotiating',
        'approved',
        'declined',
        'in_review',
        'review_query',
        'cancelled',
      ]) {
        expect(
          SupabaseConfig.visibleOrderStatuses,
          isNot(contains(hidden)),
          reason: '$hidden must never reach a seller',
        );
      }
    });

    test('the released set is exactly the seven post-gate statuses', () {
      expect(SupabaseConfig.visibleOrderStatuses, const [
        'released',
        'in_production',
        'inspection',
        'packed',
        'shipped',
        'arrived',
        'closed',
      ]);
    });

    test('every visible status lands in exactly one inbox tab', () {
      for (final status in SupabaseConfig.visibleOrderStatuses) {
        final o = SellerOrder.fromMap(_orderMap(status: status));
        final buckets = [o.isNew, o.isRunning, o.isDone].where((b) => b).length;
        expect(buckets, 1, reason: '$status must appear on exactly one tab');
      }
    });
  });

  group('SellerOrder', () {
    final order = SellerOrder.fromMap(
      _orderMap(
        lines: [
          _lineMap(
            id: 'l1',
            pcs: 800,
            packs: 80,
            hex: '#EDE6D6',
            colourName: 'Ivory',
          ),
          _lineMap(
            id: 'l2',
            pcs: 600,
            packs: 60,
            hex: '#9AA88C',
            colourName: 'Sage',
          ),
        ],
      ),
    );

    test('totals come from the lines', () {
      expect(order.totalPieces, 1400);
      expect(order.goodsValue, closeTo(1400 * 9.80, 0.001));
    });

    test('size bars are ratio x packs, merged across lines', () {
      expect(order.sizeBreakdown, {
        'S': 280, // (80 + 60) packs x 2
        'M': 420, // x 3
        'L': 420, // x 3
        'XL': 280, // x 2
      });
      final summed =
          order.sizeBreakdown.values.fold(0, (a, b) => a + b);
      expect(summed, order.totalPieces);
    });

    test('colourways parse to real colours', () {
      expect(order.lines.first.colour.toARGB32(), 0xFFEDE6D6);
    });

    test('a malformed hex degrades instead of throwing', () {
      final o = SellerOrder.fromMap(
        _orderMap(
          lines: [
            _lineMap(id: 'l', pcs: 10, packs: 1, hex: 'nope', colourName: 'X'),
          ],
        ),
      );
      expect(o.lines.first.colour.toARGB32(), 0xFF9AA0A6);
    });

    test('an order with no lines still renders totals', () {
      final o = SellerOrder.fromMap(_orderMap());
      expect(o.totalPieces, 0);
      expect(o.goodsValue, 0);
      expect(o.sizeBreakdown, isEmpty);
    });
  });

  group('the ladder: only the lowest incomplete stage is actionable', () {
    test('picks the lowest incomplete stage, not the first non-completed row', () {
      final steps = [
        ProductionStep.fromMap(
          _stepMap(id: 'a', sort: 1, status: 'completed', name: 'Fabric'),
        ),
        ProductionStep.fromMap(
          _stepMap(id: 'b', sort: 2, status: 'completed', name: 'Cutting'),
        ),
        ProductionStep.fromMap(
          _stepMap(id: 'c', sort: 3, status: 'in_progress', name: 'Stitching'),
        ),
        ProductionStep.fromMap(
          _stepMap(id: 'd', sort: 4, status: 'pending', name: 'Finishing'),
        ),
      ];
      expect(SharikRepository.actionableStep(steps)!.eventId, 'c');
    });

    test('in_progress counts as incomplete', () {
      final steps = [
        ProductionStep.fromMap(_stepMap(id: 'a', sort: 1, status: 'in_progress')),
      ];
      expect(SharikRepository.actionableStep(steps)!.eventId, 'a');
    });

    test('a finished ladder has nothing to act on', () {
      final steps = [
        ProductionStep.fromMap(_stepMap(id: 'a', sort: 1, status: 'completed')),
        ProductionStep.fromMap(_stepMap(id: 'b', sort: 2, status: 'completed')),
      ];
      expect(SharikRepository.actionableStep(steps), isNull);
    });

    test('an empty ladder does not crash', () {
      expect(SharikRepository.actionableStep(const []), isNull);
    });
  });
}
