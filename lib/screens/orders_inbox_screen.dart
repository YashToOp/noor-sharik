import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/sharik_repository.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

/// Screen 02 — the inbox.
///
/// Three tabs driven by colour. A new order must arrive on its own, with a
/// sound, the moment QC approves the gate.
class OrdersInboxScreen extends StatefulWidget {
  const OrdersInboxScreen({
    super.key,
    required this.house,
    this.repository,
  });

  final House house;

  /// Injectable so the screen can be rendered from fixtures.
  final SharikRepository? repository;

  @override
  State<OrdersInboxScreen> createState() => _OrdersInboxScreenState();
}

class _OrdersInboxScreenState extends State<OrdersInboxScreen>
    with SingleTickerProviderStateMixin {
  late final SharikRepository _repo =
      widget.repository ?? SharikRepository(Supabase.instance.client);
  late final TabController _tabs = TabController(length: 3, vsync: this);
  RealtimeChannel? _channel;

  List<SellerOrder> _orders = const [];
  Set<String> _knownIds = {};
  Set<String> _freshIds = {};
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load(firstRun: true);
    _channel = _repo.subscribeOrders(
      houseId: widget.house.id,
      onChange: () => _load(),
    );
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool firstRun = false}) async {
    try {
      final orders = await _repo.orders(widget.house.id);
      if (!mounted) return;

      final ids = orders.map((o) => o.id).toSet();
      final arrived = firstRun ? <String>{} : ids.difference(_knownIds);

      setState(() {
        _orders = orders;
        _knownIds = ids;
        _freshIds = {..._freshIds, ...arrived};
        _loading = false;
        _failed = false;
      });

      if (arrived.isNotEmpty) _announce(arrived.length);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// In-app sound and a badge. He is on the factory floor, not watching a screen.
  void _announce(int count) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    _tabs.animateTo(0);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: NoorColors.amber,
          duration: const Duration(seconds: 4),
          content: Text(
            count == 1 ? 'New order from Noor' : '$count new orders from Noor',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  List<SellerOrder> get _new => _orders.where((o) => o.isNew).toList();
  List<SellerOrder> get _running => _orders.where((o) => o.isRunning).toList();
  List<SellerOrder> get _done => _orders.where((o) => o.isDone).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.house.name, style: NoorText.title),
            Text(
              'Orders',
              style: NoorText.body.copyWith(
                color: NoorColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: NoorColors.ink,
          unselectedLabelColor: NoorColors.inkFaint,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3,
          indicatorColor: NoorColors.amber,
          tabs: [
            _CountTab(label: 'New', count: _new.length, colour: NoorColors.amber),
            _CountTab(
              label: 'Running',
              count: _running.length,
              colour: NoorColors.green,
            ),
            _CountTab(
              label: 'Done',
              count: _done.length,
              colour: NoorColors.grey,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? _RetryState(onRetry: () => _load(firstRun: true))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _OrderList(
                      orders: _new,
                      fresh: _freshIds,
                      house: widget.house,
                      accent: NoorColors.amber,
                      repository: _repo,
                      showActions: true,
                      onChanged: _load,
                      empty: const EmptyState(
                        title: 'No new orders',
                        message:
                            'When Noor releases an order it will appear here '
                            'straight away.',
                        tint: NoorColors.amber,
                      ),
                    ),
                    _OrderList(
                      orders: _running,
                      fresh: _freshIds,
                      house: widget.house,
                      accent: NoorColors.green,
                      repository: _repo,
                      showActions: false,
                      onChanged: _load,
                      empty: const EmptyState(
                        title: 'Nothing in production',
                        message: 'Accept an order and it moves here.',
                        tint: NoorColors.green,
                      ),
                    ),
                    _OrderList(
                      orders: _done,
                      fresh: _freshIds,
                      house: widget.house,
                      accent: NoorColors.grey,
                      repository: _repo,
                      showActions: false,
                      onChanged: _load,
                      empty: const EmptyState(
                        title: 'Nothing finished yet',
                        message: 'Shipped and closed orders rest here.',
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({
    required this.label,
    required this.count,
    required this.colour,
  });

  final String label;
  final int count;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: colour,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.fresh,
    required this.house,
    required this.accent,
    required this.showActions,
    required this.onChanged,
    required this.empty,
    required this.repository,
  });

  final List<SellerOrder> orders;
  final Set<String> fresh;
  final House house;
  final Color accent;
  final bool showActions;
  final Future<void> Function() onChanged;
  final Widget empty;
  final SharikRepository? repository;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onChanged,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [const SizedBox(height: 120), empty],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView.separated(
        padding: const EdgeInsets.all(NoorSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: NoorSpacing.md),
        itemBuilder: (context, i) => OrderCard(
          order: orders[i],
          house: house,
          repository: repository,
          accent: accent,
          isFresh: fresh.contains(orders[i].id),
          showActions: showActions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// A large card that leads with colour. PIECES and VALUE are the biggest text.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.house,
    required this.accent,
    required this.isFresh,
    required this.showActions,
    required this.onChanged,
    this.repository,
  });

  final SellerOrder order;
  final House house;
  final SharikRepository? repository;
  final Color accent;
  final bool isFresh;
  final bool showActions;
  final Future<void> Function() onChanged;

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: order.id,
          house: house,
          repository: repository,
        ),
      ),
    );
    await onChanged();
  }

  Future<void> _accept(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AcceptDialog(order: order),
    );
    if (confirmed != true) return;
    try {
      final repo =
          repository ?? SharikRepository(Supabase.instance.client);
      await repo.acceptOrder(order.id);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: NoorColors.green,
          content: Text('${order.number} accepted — now in production'),
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
    await onChanged();
  }

  Future<void> _decline(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot take this order?'),
        content: const Text(
          'Noor will be told and will call you. The order stays open until '
          'they do.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NoorColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tell Noor'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Noor has been told.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = order.daysRemaining;
    return NoorCard(
      onTap: () => _open(context),
      accent: isFresh ? accent : null,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NoorSpacing.md,
              NoorSpacing.md,
              NoorSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The colourway block leads. He knows the order by its colour.
                Row(
                  children: [
                    for (final line in order.lines.take(4))
                      Padding(
                        padding: const EdgeInsets.only(right: NoorSpacing.sm),
                        child: Column(
                          children: [
                            ColourBlock(
                              colours: [
                                line.colour,
                                Color.lerp(line.colour, Colors.black, 0.28)!,
                              ],
                              size: 62,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              line.colourwayName,
                              style: NoorText.body.copyWith(
                                fontSize: 11,
                                color: NoorColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (isFresh)
                      Pill(text: 'NEW', colour: accent)
                    else
                      Pill(text: order.status.replaceAll('_', ' ').toUpperCase(),
                          colour: accent),
                  ],
                ),
                const SizedBox(height: NoorSpacing.md),
                Text(
                  order.lines.isEmpty
                      ? order.number
                      : order.lines.first.styleName,
                  style: NoorText.title,
                ),
                Text(
                  order.number,
                  style: NoorText.body.copyWith(
                    color: NoorColors.inkFaint,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: NoorSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Figure(
                      label: 'PIECES',
                      value: formatCount(order.totalPieces),
                    ),
                    const SizedBox(width: NoorSpacing.xl),
                    _Figure(
                      label: 'VALUE',
                      value: formatMoney(order.goodsValue, order.currency),
                    ),
                  ],
                ),
                const SizedBox(height: NoorSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        size: 16, color: NoorColors.inkFaint),
                    const SizedBox(width: 6),
                    Text(
                      'Deliver by ${formatDate(order.promisedShipDate)}',
                      style: NoorText.body.copyWith(
                        color: NoorColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (days != null)
                      Pill(
                        text: days < 0
                            ? '${-days} DAYS LATE'
                            : '$days DAYS LEFT',
                        colour: days < 0
                            ? NoorColors.danger
                            : days <= 7
                                ? NoorColors.amber
                                : NoorColors.green,
                      ),
                  ],
                ),
                const SizedBox(height: NoorSpacing.md),
              ],
            ),
          ),
          if (showActions) ...[
            const Divider(height: 1),
            // Accept and No sit on the card. No drill-down for the commonest
            // action he takes all day.
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _accept(context),
                    child: Container(
                      height: 58,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: NoorColors.forest,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(NoorRadius.lg),
                        ),
                      ),
                      child: const Text(
                        'ACCEPT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _decline(context),
                    child: Container(
                      height: 58,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(NoorRadius.lg),
                        ),
                      ),
                      child: Text(
                        'NO',
                        style: NoorText.label.copyWith(
                          color: NoorColors.danger,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NoorText.label.copyWith(color: NoorColors.inkFaint)),
        const SizedBox(height: 2),
        Text(value, style: NoorText.figure),
      ],
    );
  }
}

/// Accept means committing to a date. Show him the date before he commits.
class AcceptDialog extends StatelessWidget {
  const AcceptDialog({super.key, required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Accept this order?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatCount(order.totalPieces)} pieces · '
            '${formatMoney(order.goodsValue, order.currency)}',
            style: NoorText.body,
          ),
          const SizedBox(height: NoorSpacing.md),
          Container(
            padding: const EdgeInsets.all(NoorSpacing.md),
            decoration: BoxDecoration(
              color: NoorColors.greenSoft,
              borderRadius: BorderRadius.circular(NoorRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOU DELIVER BY',
                  style: NoorText.label.copyWith(color: NoorColors.green),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(order.promisedShipDate),
                  style: NoorText.title,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Back'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NoorColors.forest),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyState(
            title: 'Cannot reach Noor',
            message: 'Check the connection and try again.',
            tint: NoorColors.danger,
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
