import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'models.dart';

/// Every read and write Sharik is allowed to make.
///
/// Reads: manufacturer_orders, manufacturer_order_lines, styles, colourways,
/// production_events, production_stages, media_assets, houses.
///
/// Writes — and nothing else, ever:
///   * manufacturer_orders.status -> 'in_production', on accept
///   * production_events.status / qty_out / qty_in / completed_at
///   * media_assets, the colour blocks for a completed stage
///   * issues, when the seller raises a problem
class SharikRepository {
  SharikRepository(this._client);

  final SupabaseClient _client;

  static const String _orderSelect = '''
    id, number, status, total, currency, promised_ship_date,
    expected_arrival_date, lead_time_days, updated_at,
    manufacturer_order_lines (
      id, pcs, packs, unit_price, line_total,
      styles ( code, name, fabric, composition, gsm ),
      colourways ( name, hex ),
      ratio_packs ( ratio, pcs_per_pack )
    )
  ''';

  Future<List<House>> houses() async {
    final rows = await _client
        .from('houses')
        .select('id, code, name, city')
        .eq('status', 'active')
        .order('name');
    return rows.map<House>((r) => House.fromMap(r)).toList();
  }

  /// Orders this house may see.
  ///
  /// The two filters below are the whole commercial contract: his house only,
  /// and only once QC has released it. Never relax either.
  Future<List<SellerOrder>> orders(String houseId) async {
    final rows = await _client
        .from('manufacturer_orders')
        .select(_orderSelect)
        .eq('house_id', houseId)
        .inFilter('status', SupabaseConfig.visibleOrderStatuses)
        .order('updated_at', ascending: false);
    return rows.map<SellerOrder>((r) => SellerOrder.fromMap(r)).toList();
  }

  Future<SellerOrder?> order(String orderId, String houseId) async {
    final rows = await _client
        .from('manufacturer_orders')
        .select(_orderSelect)
        .eq('id', orderId)
        .eq('house_id', houseId)
        .inFilter('status', SupabaseConfig.visibleOrderStatuses)
        .limit(1);
    if (rows.isEmpty) return null;
    return SellerOrder.fromMap(rows.first);
  }

  /// The production ladder, lowest sort first.
  Future<List<ProductionStep>> steps(String orderId) async {
    final rows = await _client
        .from('production_events')
        .select('''
          id, status, qty_in, qty_out, expected_at, completed_at, note,
          production_stages ( code, name, sort, requires_media )
        ''')
        .eq('manufacturer_order_id', orderId);

    final steps = rows.map<ProductionStep>((r) => ProductionStep.fromMap(r)).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    if (steps.isEmpty) return steps;

    final media = await _client
        .from('media_assets')
        .select('owner_id, meta, sort')
        .eq('owner_type', 'production_event')
        .inFilter('owner_id', steps.map((s) => s.eventId).toList())
        .order('sort');

    final byEvent = <String, List<List<Color>>>{};
    for (final m in media) {
      final meta = (m['meta'] ?? const {}) as Map<String, dynamic>;
      final raw = (meta['gradient'] ?? const []) as List<dynamic>;
      final colours = raw.map((h) => _hex(h as String)).toList();
      if (colours.isEmpty) continue;
      byEvent.putIfAbsent(m['owner_id'] as String, () => []).add(colours);
    }

    return steps
        .map((s) => s.withGradients(byEvent[s.eventId] ?? const []))
        .toList();
  }

  /// The lowest stage that is not yet completed. The only one he may act on.
  static ProductionStep? actionableStep(List<ProductionStep> steps) {
    for (final s in steps) {
      if (!s.isCompleted) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------- writes --

  /// Accept. The only status Sharik may ever write to an order.
  Future<void> acceptOrder(String orderId) async {
    await _client
        .from('manufacturer_orders')
        .update({
          'status': 'in_production',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('status', 'released');
  }

  /// Complete one stage. This is the write the whole demo turns on: the moment
  /// it lands, the client's timeline moves in Majlis.
  ///
  /// `colours` is the pair of hex values he picked, stored in `media_assets`
  /// with the same shape the seeded rows use — `meta.gradient`. The contract's
  /// `production_events.photo_colours` column does not exist in this schema;
  /// media_assets is where this project already keeps stage imagery.
  Future<void> completeStage({
    required String eventId,
    required String orderId,
    required int qtyOut,
    required List<String> colours,
    required String stageName,
  }) async {
    final now = DateTime.now().toUtc();

    await _client
        .from('production_events')
        .update({
          'status': 'completed',
          'qty_out': qtyOut,
          'completed_at': now.toIso8601String(),
        })
        .eq('id', eventId);

    if (colours.isNotEmpty) {
      await _client.from('media_assets').insert({
        'tenant_id': SupabaseConfig.tenantId,
        'owner_type': 'production_event',
        'owner_id': eventId,
        'kind': 'floor',
        'url': 'noor://gradient',
        'meta': {'gradient': colours, 'label': stageName},
        'sort': 0,
      });
    }

    // qty_in on a stage is the previous stage's qty_out. That chain is how Noor
    // sees where pieces disappear, so carry it forward as we go.
    final ladder = await steps(orderId);
    final done = ladder.indexWhere((s) => s.eventId == eventId);
    if (done >= 0 && done + 1 < ladder.length) {
      await _client
          .from('production_events')
          .update({'qty_in': qtyOut})
          .eq('id', ladder[done + 1].eventId);
    }
  }

  /// Raise a problem. Insert only — QC resolves it.
  Future<void> raiseIssue({
    required String orderId,
    required String houseId,
    required String issueTypeCode,
    required String description,
  }) async {
    final type = await _client
        .from('issue_types')
        .select('id, sla_hours')
        .eq('code', issueTypeCode)
        .limit(1)
        .single();

    final sla = (type['sla_hours'] as num?)?.toInt() ?? 24;
    await _client.from('issues').insert({
      'tenant_id': SupabaseConfig.tenantId,
      'issue_type_id': type['id'],
      'manufacturer_order_id': orderId,
      'house_id': houseId,
      'description': description,
      'status': 'open',
      'sla_due_at': DateTime.now()
          .toUtc()
          .add(Duration(hours: sla))
          .toIso8601String(),
      'client_visible': false,
    });
  }

  Future<List<String>> issueTypeCodes() async {
    final rows = await _client.from('issue_types').select('code').order('code');
    return rows.map<String>((r) => r['code'] as String).toList();
  }

  // -------------------------------------------------------------- realtime --

  /// A new order must appear on its own, with a sound, the moment QC releases
  /// it. Filtered to this house — never the whole table.
  RealtimeChannel? subscribeOrders({
    required String houseId,
    required void Function() onChange,
  }) {
    return _client
        .channel('sharik-orders-$houseId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'manufacturer_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'house_id',
            value: houseId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  RealtimeChannel? subscribeSteps({
    required String orderId,
    required void Function() onChange,
  }) {
    return _client
        .channel('sharik-steps-$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'production_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'manufacturer_order_id',
            value: orderId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}

Color _hex(String h) {
  final s = h.replaceAll('#', '');
  if (s.length != 6) return const Color(0xFF9AA0A6);
  return Color(int.parse('FF$s', radix: 16));
}
