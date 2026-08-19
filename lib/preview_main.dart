// Renders the three screens from fixtures, with no database behind them.
//
// This exists because the build container cannot reach Supabase. It is a
// LOOK-AND-FEEL preview only: nothing here proves the wiring works, and it must
// never be mistaken for a run against noor-demo. The fixtures below are copied
// from the real seeded rows so the numbers on screen match the demo.
//
//   flutter run -t lib/preview_main.dart
//
// Where no system font is available (a headless container, say), bundle one and
// pass it through:  --dart-define=PREVIEW_FONT=MyFamily
//
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'data/sharik_repository.dart';
import 'screens/orders_inbox_screen.dart';

const _zubair = House(
  id: '40000000-0000-4000-a000-000000000001',
  code: 'ZG',
  name: 'Zubair Garments',
  city: "Sana'a",
);

const _ratio = {'S': 2, 'M': 3, 'L': 3, 'XL': 2};

OrderLine _line({
  required String id,
  required String styleCode,
  required String styleName,
  required String colourwayName,
  required String hex,
  required int pcs,
  required int packs,
  required double unitPrice,
  String fabric = 'Washed linen',
  String composition = '55% linen · 45% viscose',
  int gsm = 210,
}) => OrderLine(
  id: id,
  pcs: pcs,
  packs: packs,
  unitPrice: unitPrice,
  lineTotal: pcs * unitPrice,
  styleCode: styleCode,
  styleName: styleName,
  fabric: fabric,
  composition: composition,
  gsm: gsm,
  colourwayName: colourwayName,
  hex: hex,
  ratio: _ratio,
  pcsPerPack: 10,
);

final _released = SellerOrder(
  id: '7c000000-0000-4000-a000-000000000002',
  number: 'NT-2026-0164-A',
  status: 'released',
  total: 14320,
  currency: 'USD',
  promisedShipDate: DateTime(2026, 9, 28),
  expectedArrivalDate: DateTime(2026, 10, 14),
  leadTimeDays: 40,
  updatedAt: DateTime(2026, 8, 19),
  lines: [
    _line(
      id: 'l1',
      styleCode: 'D-4482',
      styleName: 'Linen Wrap Dress',
      colourwayName: 'Ivory',
      hex: '#EDE6D6',
      pcs: 800,
      packs: 80,
      unitPrice: 9.80,
    ),
    _line(
      id: 'l2',
      styleCode: 'D-4482',
      styleName: 'Linen Wrap Dress',
      colourwayName: 'Sage',
      hex: '#9AA88C',
      pcs: 600,
      packs: 60,
      unitPrice: 9.80,
    ),
  ],
);

final _running = SellerOrder(
  id: '7c000000-0000-4000-a000-000000000001',
  number: 'NT-2026-0163-A',
  status: 'in_production',
  total: 15100,
  currency: 'USD',
  promisedShipDate: DateTime(2026, 9, 2),
  expectedArrivalDate: DateTime(2026, 9, 18),
  leadTimeDays: 45,
  updatedAt: DateTime(2026, 8, 18),
  lines: [
    _line(
      id: 'l3',
      styleCode: 'D-4471',
      styleName: 'Navy Linen Skirt',
      colourwayName: 'Navy',
      hex: '#1F3A5F',
      pcs: 1200,
      packs: 120,
      unitPrice: 8.40,
    ),
    _line(
      id: 'l4',
      styleCode: 'D-4463',
      styleName: 'Pleated Maxi Skirt',
      colourwayName: 'Olive',
      hex: '#67714E',
      pcs: 600,
      packs: 60,
      unitPrice: 7.20,
    ),
  ],
);

/// Not in noor-demo — the seeded catalogue is skirts, dresses and abayas.
/// Here so the garment drawing can be reviewed on trousers too.
final _denim = SellerOrder(
  id: 'preview-denim',
  number: 'NT-2026-0171-A',
  status: 'released',
  total: 9400,
  currency: 'USD',
  promisedShipDate: DateTime(2026, 10, 12),
  expectedArrivalDate: DateTime(2026, 10, 28),
  leadTimeDays: 42,
  updatedAt: DateTime(2026, 8, 19),
  lines: [
    _line(
      id: 'l5',
      styleCode: 'J-2204',
      styleName: 'Straight Leg Jeans',
      colourwayName: 'Indigo',
      hex: '#2E4272',
      pcs: 700,
      packs: 70,
      unitPrice: 11.60,
      fabric: 'Rigid denim',
      composition: '100% cotton',
      gsm: 340,
    ),
    _line(
      id: 'l6',
      styleCode: 'J-2204',
      styleName: 'Straight Leg Jeans',
      colourwayName: 'Stone Wash',
      hex: '#8FA0B8',
      pcs: 500,
      packs: 50,
      unitPrice: 11.60,
      fabric: 'Rigid denim',
      composition: '100% cotton',
      gsm: 340,
    ),
  ],
);

ProductionStep _step({
  required int sort,
  required String name,
  required String status,
  int? qtyIn,
  int? qtyOut,
  DateTime? completedAt,
  List<List<Color>> gradients = const [],
}) => ProductionStep(
  eventId: 'evt-$sort',
  stageCode: 'stage-$sort',
  stageName: name,
  sort: sort,
  status: status,
  qtyIn: qtyIn,
  qtyOut: qtyOut,
  expectedAt: DateTime(2026, 8, 20 + sort),
  completedAt: completedAt,
  note: null,
  requiresMedia: true,
  gradients: gradients,
);

final _ladder = <ProductionStep>[
  _step(
    sort: 1,
    name: 'Fabric sourced',
    status: 'completed',
    qtyOut: 1800,
    completedAt: DateTime(2026, 7, 24),
    gradients: const [
      [Color(0xFF8A6F4D), Color(0xFF5C4A33)],
    ],
  ),
  _step(
    sort: 2,
    name: 'Cutting',
    status: 'completed',
    qtyIn: 1800,
    qtyOut: 1800,
    completedAt: DateTime(2026, 8, 1),
    gradients: const [
      [Color(0xFF1F3A5F), Color(0xFF152A47)],
      [Color(0xFF8A6F4D), Color(0xFF5C4A33)],
    ],
  ),
  _step(sort: 3, name: 'Stitching', status: 'in_progress', qtyIn: 1800),
  _step(sort: 4, name: 'Finishing & pressing', status: 'pending'),
  _step(sort: 5, name: 'Inspection', status: 'pending'),
  _step(sort: 6, name: 'Packing', status: 'pending'),
  _step(sort: 7, name: 'Shipped', status: 'pending'),
];

class PreviewRepository extends SharikRepository {
  PreviewRepository() : super(SupabaseClient('https://preview.invalid', 'none'));

  final List<SellerOrder> _orders = [_released, _denim, _running];

  @override
  Future<List<House>> houses() async => const [_zubair];

  @override
  Future<List<SellerOrder>> orders(String houseId) async => _orders;

  @override
  Future<SellerOrder?> order(String orderId, String houseId) async =>
      _orders.where((o) => o.id == orderId).firstOrNull;

  @override
  Future<List<ProductionStep>> steps(String orderId) async => _ladder;

  @override
  Future<void> acceptOrder(String orderId) async {}

  @override
  Future<void> completeStage({
    required String eventId,
    required String orderId,
    required int qtyOut,
    required List<String> colours,
    required String stageName,
  }) async {}

  @override
  RealtimeChannel? subscribeOrders({
    required String houseId,
    required void Function() onChange,
  }) => null;

  @override
  RealtimeChannel? subscribeSteps({
    required String orderId,
    required void Function() onChange,
  }) => null;
}

const _previewFont = String.fromEnvironment('PREVIEW_FONT');

void main() {
  runApp(
    MaterialApp(
      title: 'Noor Sharik — preview',
      debugShowCheckedModeBanner: false,
      theme: buildNoorTheme(
        fontFamily: _previewFont.isEmpty ? null : _previewFont,
      ),
      home: OrdersInboxScreen(house: _zubair, repository: PreviewRepository()),
    ),
  );
}
