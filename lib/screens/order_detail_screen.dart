import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/sharik_repository.dart';
import '../widgets/common.dart';
import 'orders_inbox_screen.dart';
import 'update_production_screen.dart';

/// Screen 03 — the order.
///
/// Everything he needs to say yes: the goods, his rate, his date. Nothing about
/// the client, because there is nothing about the client in the query.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.house,
    this.repository,
  });

  final String orderId;
  final House house;

  /// Injectable so the screen can be rendered from fixtures.
  final SharikRepository? repository;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final SharikRepository _repo =
      widget.repository ?? SharikRepository(Supabase.instance.client);
  SellerOrder? _order;
  bool _loading = true;
  bool _failed = false;
  DateTime? _requestedDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await _repo.order(widget.orderId, widget.house.id);
      if (!mounted) return;
      setState(() {
        _order = o;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _accept() async {
    final order = _order;
    if (order == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AcceptDialog(order: order),
    );
    if (confirmed != true) return;
    try {
      await _repo.acceptOrder(order.id);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: NoorColors.green,
          content: Text('Accepted — now in production'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: NoorColors.danger,
          content: Text('Could not accept. Try again.'),
        ),
      );
    }
    await _load();
  }

  Future<void> _askMoreTime() async {
    final order = _order;
    if (order == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final base = order.promisedShipDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base.add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: base.add(const Duration(days: 180)),
      helpText: 'When can you deliver?',
    );
    if (picked == null) return;
    setState(() => _requestedDate = picked);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: NoorColors.amber,
        content: Text('Noor will be asked for ${formatDate(picked)}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text(order?.number ?? 'Order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? const EmptyState(
                  title: 'Cannot reach Noor',
                  message: 'Check the connection and try again.',
                  tint: NoorColors.danger,
                )
              : order == null
                  ? const EmptyState(
                      title: 'Order not available',
                      message:
                          'This order is not released to your house. Noor will '
                          'send it when it is ready.',
                    )
                  : _body(order),
      bottomNavigationBar: order == null ? null : _bottomBar(order),
    );
  }

  Widget _body(SellerOrder order) {
    final line = order.lines.isNotEmpty ? order.lines.first : null;
    final sizes = order.sizeBreakdown;

    return ListView(
      padding: const EdgeInsets.all(NoorSpacing.md),
      children: [
        // Style block — the photograph, standing in as colour for the demo.
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NoorRadius.lg),
            gradient: LinearGradient(
              colors: line == null
                  ? [NoorColors.greySoft, NoorColors.grey]
                  : [
                      line.colour,
                      Color.lerp(line.colour, Colors.black, 0.45)!,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const SizedBox(height: NoorSpacing.md),
        Text(line?.styleName ?? order.number, style: NoorText.hero.copyWith(fontSize: 30)),
        const SizedBox(height: 2),
        Text(
          [
            if (line != null) line.styleCode,
            if (line != null && line.fabric.isNotEmpty) line.fabric,
            if (line?.gsm != null) '${line!.gsm} gsm',
          ].join('  ·  '),
          style: NoorText.body.copyWith(color: NoorColors.inkSoft),
        ),

        const SizedBox(height: NoorSpacing.lg),
        Text('COLOURS', style: NoorText.label.copyWith(color: NoorColors.inkFaint)),
        const SizedBox(height: NoorSpacing.sm),
        // Swatches with piece counts underneath — not a table.
        Wrap(
          spacing: NoorSpacing.md,
          runSpacing: NoorSpacing.md,
          children: [
            for (final l in order.lines)
              SizedBox(
                width: 84,
                child: Column(
                  children: [
                    ColourBlock(
                      colours: [
                        l.colour,
                        Color.lerp(l.colour, Colors.black, 0.3)!,
                      ],
                      size: 84,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCount(l.pcs),
                      style: NoorText.title.copyWith(fontSize: 18),
                    ),
                    Text(
                      l.colourwayName,
                      style: NoorText.body.copyWith(
                        fontSize: 12,
                        color: NoorColors.inkSoft,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),

        if (sizes.isNotEmpty) ...[
          const SizedBox(height: NoorSpacing.lg),
          Text('SIZES', style: NoorText.label.copyWith(color: NoorColors.inkFaint)),
          const SizedBox(height: NoorSpacing.sm),
          _SizeBars(sizes: sizes),
        ],

        const SizedBox(height: NoorSpacing.lg),
        // The largest number on the screen.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(NoorSpacing.lg),
          decoration: BoxDecoration(
            color: NoorColors.forest,
            borderRadius: BorderRadius.circular(NoorRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL PIECES',
                style: NoorText.label.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCount(order.totalPieces),
                style: NoorText.hero.copyWith(color: Colors.white, fontSize: 56),
              ),
            ],
          ),
        ),

        const SizedBox(height: NoorSpacing.md),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'YOUR RATE',
                value: line == null
                    ? '—'
                    : '${order.currency} ${line.unitPrice.toStringAsFixed(2)}',
                sub: 'per piece',
              ),
            ),
            const SizedBox(width: NoorSpacing.md),
            Expanded(
              child: _Stat(
                label: 'YOUR ORDER VALUE',
                value: formatMoney(order.goodsValue, order.currency),
                sub: '${order.lines.length} colour'
                    '${order.lines.length == 1 ? '' : 's'}',
              ),
            ),
          ],
        ),

        const SizedBox(height: NoorSpacing.md),
        NoorCard(
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DELIVER BY',
                    style: NoorText.label.copyWith(color: NoorColors.inkFaint),
                  ),
                  const SizedBox(height: 3),
                  Text(formatDate(order.promisedShipDate), style: NoorText.title),
                  if (_requestedDate != null)
                    Text(
                      'You asked for ${formatDate(_requestedDate)}',
                      style: NoorText.body.copyWith(
                        color: NoorColors.amber,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (order.daysRemaining != null)
                Pill(
                  text: order.daysRemaining! < 0
                      ? '${-order.daysRemaining!} DAYS LATE'
                      : '${order.daysRemaining} DAYS LEFT',
                  colour: order.daysRemaining! < 0
                      ? NoorColors.danger
                      : order.daysRemaining! <= 7
                          ? NoorColors.amber
                          : NoorColors.green,
                ),
            ],
          ),
        ),

        const SizedBox(height: NoorSpacing.md),
        // A voice note from Noor. Reading is not how this instruction arrives.
        NoorCard(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice notes arrive in the next build.')),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NoorColors.goldSoft,
                  borderRadius: BorderRadius.circular(NoorRadius.md),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: NoorColors.gold),
              ),
              const SizedBox(width: NoorSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Note from Noor', style: NoorText.title.copyWith(fontSize: 16)),
                    Text(
                      'No voice note on this order',
                      style: NoorText.body.copyWith(
                        color: NoorColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NoorSpacing.xl),
      ],
    );
  }

  Widget _bottomBar(SellerOrder order) {
    return SafeArea(
      minimum: const EdgeInsets.all(NoorSpacing.md),
      child: order.isNew
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _askMoreTime,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      side: const BorderSide(color: NoorColors.hairline),
                      foregroundColor: NoorColors.ink,
                    ),
                    child: const Text('More time'),
                  ),
                ),
                const SizedBox(width: NoorSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: NoorColors.forest,
                      minimumSize: const Size.fromHeight(58),
                    ),
                    child: const Text(
                      'ACCEPT',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UpdateProductionScreen(
                      order: order,
                      repository: widget.repository,
                    ),
                  ),
                );
                await _load();
              },
              style: FilledButton.styleFrom(
                backgroundColor: NoorColors.forest,
                minimumSize: const Size.fromHeight(58),
              ),
              child: const Text(
                'UPDATE PRODUCTION',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
            ),
    );
  }
}

class _SizeBars extends StatelessWidget {
  const _SizeBars({required this.sizes});
  final Map<String, int> sizes;

  static const _order = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  @override
  Widget build(BuildContext context) {
    final entries = sizes.entries.toList()
      ..sort((a, b) {
        final ia = _order.indexOf(a.key);
        final ib = _order.indexOf(b.key);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    final max = entries.fold(0, (m, e) => e.value > m ? e.value : m);

    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: NoorSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    e.key,
                    style: NoorText.title.copyWith(fontSize: 15),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Stack(
                      children: [
                        Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: NoorColors.greySoft,
                            borderRadius: BorderRadius.circular(NoorRadius.sm),
                          ),
                        ),
                        Container(
                          height: 26,
                          width: max == 0 ? 0 : c.maxWidth * (e.value / max),
                          decoration: BoxDecoration(
                            color: NoorColors.forestSoft,
                            borderRadius: BorderRadius.circular(NoorRadius.sm),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: NoorSpacing.sm),
                SizedBox(
                  width: 56,
                  child: Text(
                    formatCount(e.value),
                    textAlign: TextAlign.right,
                    style: NoorText.title.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return NoorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NoorText.label.copyWith(color: NoorColors.inkFaint)),
          const SizedBox(height: 4),
          Text(value, style: NoorText.title.copyWith(fontSize: 19)),
          Text(
            sub,
            style: NoorText.body.copyWith(
              color: NoorColors.inkSoft,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
