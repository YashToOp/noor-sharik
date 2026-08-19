import 'package:flutter/material.dart';

/// A manufacturing house. Sharik only ever loads its own.
class House {
  const House({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
  });

  final String id;
  final String code;
  final String name;
  final String city;

  factory House.fromMap(Map<String, dynamic> m) => House(
    id: m['id'] as String,
    code: (m['code'] ?? '') as String,
    name: (m['name'] ?? '') as String,
    city: (m['city'] ?? '') as String,
  );
}

/// One line of an order: a style in a colourway.
///
/// Carries the seller's own rate. There is no client price here and no place to
/// put one.
class OrderLine {
  const OrderLine({
    required this.id,
    required this.pcs,
    required this.packs,
    required this.unitPrice,
    required this.lineTotal,
    required this.styleCode,
    required this.styleName,
    required this.fabric,
    required this.composition,
    required this.gsm,
    required this.colourwayName,
    required this.hex,
    required this.ratio,
    required this.pcsPerPack,
  });

  final String id;
  final int pcs;
  final int packs;
  final double unitPrice;
  final double lineTotal;
  final String styleCode;
  final String styleName;
  final String fabric;
  final String composition;
  final int? gsm;
  final String colourwayName;
  final String hex;

  /// e.g. {S: 2, M: 3, L: 3, XL: 2} — pieces per pack, per size.
  final Map<String, int> ratio;
  final int pcsPerPack;

  Color get colour {
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return const Color(0xFF9AA0A6);
    return Color(int.parse('FF$h', radix: 16));
  }

  /// Size breakdown for this line: ratio x packs.
  Map<String, int> get sizeBreakdown =>
      ratio.map((size, perPack) => MapEntry(size, perPack * packs));

  factory OrderLine.fromMap(Map<String, dynamic> m) {
    final style = (m['styles'] ?? const {}) as Map<String, dynamic>;
    final cw = (m['colourways'] ?? const {}) as Map<String, dynamic>;
    final pack = (m['ratio_packs'] ?? const {}) as Map<String, dynamic>?;

    final rawRatio = (pack?['ratio'] ?? const {}) as Map<String, dynamic>;
    return OrderLine(
      id: m['id'] as String,
      pcs: (m['pcs'] as num?)?.toInt() ?? 0,
      packs: (m['packs'] as num?)?.toInt() ?? 0,
      unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (m['line_total'] as num?)?.toDouble() ?? 0,
      styleCode: (style['code'] ?? '') as String,
      styleName: (style['name'] ?? '') as String,
      fabric: (style['fabric'] ?? '') as String,
      composition: (style['composition'] ?? '') as String,
      gsm: (style['gsm'] as num?)?.toInt(),
      colourwayName: (cw['name'] ?? '') as String,
      hex: (cw['hex'] ?? '#9AA0A6') as String,
      ratio: rawRatio.map((k, v) => MapEntry(k, (v as num).toInt())),
      pcsPerPack: (pack?['pcs_per_pack'] as num?)?.toInt() ?? 0,
    );
  }
}

/// An order as the seller sees it.
///
/// The client relationship is Noor's. This class has no client name, city or
/// price — not hidden in the UI, simply never selected from the database, so
/// there is nothing to leak.
class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.total,
    required this.currency,
    required this.promisedShipDate,
    required this.expectedArrivalDate,
    required this.leadTimeDays,
    required this.updatedAt,
    required this.lines,
  });

  final String id;
  final String number;
  final String status;

  /// The seller's own order value — sum of his rates, not the client's price.
  final double total;
  final String currency;
  final DateTime? promisedShipDate;
  final DateTime? expectedArrivalDate;
  final int? leadTimeDays;
  final DateTime? updatedAt;
  final List<OrderLine> lines;

  int get totalPieces => lines.fold(0, (sum, l) => sum + l.pcs);

  /// The seller's value for the goods. Freight and packing are Noor's business.
  double get goodsValue => lines.fold(0.0, (sum, l) => sum + l.lineTotal);

  int? get daysRemaining {
    final d = promisedShipDate;
    if (d == null) return null;
    final now = DateTime.now();
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool get isNew => status == 'released';
  bool get isRunning => const {
    'in_production',
    'inspection',
    'packed',
  }.contains(status);
  bool get isDone => const {'shipped', 'arrived', 'closed'}.contains(status);

  /// Merged size curve across every line — the proportional bars.
  Map<String, int> get sizeBreakdown {
    final out = <String, int>{};
    for (final l in lines) {
      l.sizeBreakdown.forEach((size, n) => out[size] = (out[size] ?? 0) + n);
    }
    return out;
  }

  factory SellerOrder.fromMap(Map<String, dynamic> m) {
    final rawLines =
        (m['manufacturer_order_lines'] ?? const []) as List<dynamic>;
    return SellerOrder(
      id: m['id'] as String,
      number: (m['number'] ?? '') as String,
      status: (m['status'] ?? '') as String,
      total: (m['total'] as num?)?.toDouble() ?? 0,
      currency: (m['currency'] ?? 'USD') as String,
      promisedShipDate: _date(m['promised_ship_date']),
      expectedArrivalDate: _date(m['expected_arrival_date']),
      leadTimeDays: (m['lead_time_days'] as num?)?.toInt(),
      updatedAt: _date(m['updated_at']),
      lines: rawLines
          .map((e) => OrderLine.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One rung of the production ladder: a `production_events` row joined to the
/// `production_stages` row that names it.
class ProductionStep {
  const ProductionStep({
    required this.eventId,
    required this.stageCode,
    required this.stageName,
    required this.sort,
    required this.status,
    required this.qtyIn,
    required this.qtyOut,
    required this.expectedAt,
    required this.completedAt,
    required this.note,
    required this.requiresMedia,
    required this.gradients,
  });

  final String eventId;
  final String stageCode;
  final String stageName;
  final int sort;
  final String status;
  final int? qtyIn;
  final int? qtyOut;
  final DateTime? expectedAt;
  final DateTime? completedAt;
  final String? note;
  final bool requiresMedia;

  /// Colour blocks recorded against this stage, newest last. Each is a pair of
  /// hex values — the demo's stand-in for a photo, stored in `media_assets`
  /// exactly as the seeded rows already do.
  final List<List<Color>> gradients;

  bool get isCompleted => status == 'completed';

  factory ProductionStep.fromMap(Map<String, dynamic> m) {
    final stage = (m['production_stages'] ?? const {}) as Map<String, dynamic>;
    return ProductionStep(
      eventId: m['id'] as String,
      stageCode: (stage['code'] ?? '') as String,
      stageName: (stage['name'] ?? '') as String,
      sort: (stage['sort'] as num?)?.toInt() ?? 0,
      status: (m['status'] ?? 'pending') as String,
      qtyIn: (m['qty_in'] as num?)?.toInt(),
      qtyOut: (m['qty_out'] as num?)?.toInt(),
      expectedAt: _date(m['expected_at']),
      completedAt: _date(m['completed_at']),
      note: m['note'] as String?,
      requiresMedia: (stage['requires_media'] ?? false) as bool,
      gradients: const [],
    );
  }

  ProductionStep withGradients(List<List<Color>> g) => ProductionStep(
    eventId: eventId,
    stageCode: stageCode,
    stageName: stageName,
    sort: sort,
    status: status,
    qtyIn: qtyIn,
    qtyOut: qtyOut,
    expectedAt: expectedAt,
    completedAt: completedAt,
    note: note,
    requiresMedia: requiresMedia,
    gradients: g,
  );
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v as String)?.toLocal();
}
