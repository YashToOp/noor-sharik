import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/sharik_repository.dart';
import '../widgets/common.dart';
import 'complete_stage_flow.dart';

/// Screen 04 — the money screen.
///
/// A vertical ladder of stages. Only the lowest incomplete one is actionable;
/// it gets the gold panel and one enormous button. That write is what makes the
/// client's timeline move.
class UpdateProductionScreen extends StatefulWidget {
  const UpdateProductionScreen({super.key, required this.order});

  final SellerOrder order;

  @override
  State<UpdateProductionScreen> createState() => _UpdateProductionScreenState();
}

class _UpdateProductionScreenState extends State<UpdateProductionScreen> {
  late final SharikRepository _repo = SharikRepository(Supabase.instance.client);
  RealtimeChannel? _channel;

  List<ProductionStep> _steps = const [];
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.subscribeSteps(
      orderId: widget.order.id,
      onChange: _load,
    );
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final steps = await _repo.steps(widget.order.id);
      if (!mounted) return;
      setState(() {
        _steps = steps;
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

  Future<void> _complete(ProductionStep step) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<StageCompletion>(
      MaterialPageRoute(
        builder: (_) => CompleteStageFlow(order: widget.order, step: step),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _repo.completeStage(
        eventId: step.eventId,
        orderId: widget.order.id,
        qtyOut: result.quantity,
        colours: result.colours,
        stageName: step.stageName,
      );
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: NoorColors.green,
          content: Text('${step.stageName} done — Noor can see it now'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: NoorColors.danger,
          content: Text('Could not save. Try again.'),
        ),
      );
    }
    if (mounted) setState(() => _saving = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final actionable = SharikRepository.actionableStep(_steps);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Production', style: NoorText.title),
            Text(
              widget.order.number,
              style: NoorText.body.copyWith(
                color: NoorColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? const EmptyState(
                  title: 'Cannot reach Noor',
                  message: 'Check the connection and try again.',
                  tint: NoorColors.danger,
                )
              : _steps.isEmpty
                  ? const EmptyState(
                      title: 'No stages yet',
                      message:
                          'Noor sets the stages up when the order is released.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(NoorSpacing.md),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _steps.length,
                        itemBuilder: (context, i) {
                          final s = _steps[i];
                          return _StepTile(
                            step: s,
                            isLast: i == _steps.length - 1,
                            isActionable: actionable?.eventId == s.eventId,
                            saving: _saving,
                            onDone: () => _complete(s),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.isLast,
    required this.isActionable,
    required this.saving,
    required this.onDone,
  });

  final ProductionStep step;
  final bool isLast;
  final bool isActionable;
  final bool saving;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final done = step.isCompleted;
    final colour = done
        ? NoorColors.green
        : isActionable
            ? NoorColors.gold
            : NoorColors.grey;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The rail.
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done ? NoorColors.green : Colors.transparent,
                  border: Border.all(color: colour, width: 2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 19, color: Colors.white)
                      : Text(
                          '${step.sort}',
                          style: TextStyle(
                            color: colour,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? NoorColors.green : NoorColors.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: NoorSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: NoorSpacing.md),
              child: isActionable
                  ? _ActionablePanel(step: step, saving: saving, onDone: onDone)
                  : _QuietRow(step: step, done: done),
            ),
          ),
        ],
      ),
    );
  }
}

/// Completed and future stages both stay quiet. Only one thing on this screen
/// asks to be touched.
class _QuietRow extends StatelessWidget {
  const _QuietRow({required this.step, required this.done});
  final ProductionStep step;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: done ? 1 : 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Text(
            step.stageName,
            style: NoorText.title.copyWith(
              fontSize: 17,
              color: done ? NoorColors.ink : NoorColors.inkSoft,
            ),
          ),
          if (done) ...[
            const SizedBox(height: 3),
            Text(
              [
                formatDate(step.completedAt),
                if (step.qtyOut != null) '${formatCount(step.qtyOut!)} pcs',
              ].join('  ·  '),
              style: NoorText.body.copyWith(
                color: NoorColors.green,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (step.gradients.isNotEmpty) ...[
              const SizedBox(height: NoorSpacing.sm),
              Row(
                children: [
                  for (final g in step.gradients)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ColourBlock(colours: g, size: 42, radius: 10),
                    ),
                ],
              ),
            ],
          ] else
            Text(
              'Expected ${formatShortDate(step.expectedAt)}',
              style: NoorText.body.copyWith(
                color: NoorColors.inkFaint,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionablePanel extends StatelessWidget {
  const _ActionablePanel({
    required this.step,
    required this.saving,
    required this.onDone,
  });

  final ProductionStep step;
  final bool saving;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NoorSpacing.md),
      decoration: BoxDecoration(
        color: NoorColors.goldSoft,
        borderRadius: BorderRadius.circular(NoorRadius.lg),
        border: Border.all(color: NoorColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOW',
            style: NoorText.label.copyWith(color: NoorColors.gold),
          ),
          const SizedBox(height: 2),
          Text(step.stageName, style: NoorText.title.copyWith(fontSize: 22)),
          const SizedBox(height: 3),
          Text(
            'Expected ${formatShortDate(step.expectedAt)}'
            '${step.qtyIn != null ? '  ·  ${formatCount(step.qtyIn!)} pcs in' : ''}',
            style: NoorText.body.copyWith(
              color: NoorColors.inkSoft,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: NoorSpacing.md),
          FilledButton(
            onPressed: saving ? null : onDone,
            style: FilledButton.styleFrom(
              backgroundColor: NoorColors.gold,
              minimumSize: const Size.fromHeight(76),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NoorRadius.md),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_rounded,
                          size: 26, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'DONE + PHOTO',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
