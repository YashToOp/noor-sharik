import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// What the seller produced at this stage: the quantity and the two colour
/// blocks standing in for his photographs.
class StageCompletion {
  const StageCompletion({required this.quantity, required this.colours});
  final int quantity;
  final List<String> colours;
}

/// Two steps, four taps: pick two blocks, confirm the quantity.
class CompleteStageFlow extends StatefulWidget {
  const CompleteStageFlow({
    super.key,
    required this.order,
    required this.step,
  });

  final SellerOrder order;
  final ProductionStep step;

  @override
  State<CompleteStageFlow> createState() => _CompleteStageFlowState();
}

class _CompleteStageFlowState extends State<CompleteStageFlow> {
  final List<String> _picked = [];

  /// Stand-ins for the camera: the order's own colourways first, then the
  /// tones of a factory floor.
  List<String> get _palette {
    final fromOrder = widget.order.lines
        .map((l) => l.hex.toUpperCase())
        .toSet()
        .toList();
    const floor = [
      '#8A6F4D', '#5C4A33', '#B9AE99', '#3C4043',
      '#D8CDB6', '#6E7B6A', '#2B2F33', '#A8925F',
    ];
    return [...fromOrder, ...floor];
  }

  void _pick(String hex) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_picked.contains(hex)) {
        _picked.remove(hex);
      } else if (_picked.length < 2) {
        _picked.add(hex);
      }
    });
    if (_picked.length == 2) _next();
  }

  Future<void> _next() async {
    final result = await Navigator.of(context).push<StageCompletion>(
      MaterialPageRoute(
        builder: (_) => _QuantityScreen(
          order: widget.order,
          step: widget.step,
          colours: List.of(_picked),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.step.stageName, style: NoorText.title),
            Text(
              'Show Noor two photos',
              style: NoorText.body.copyWith(
                color: NoorColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(NoorSpacing.md),
              crossAxisCount: 3,
              mainAxisSpacing: NoorSpacing.md,
              crossAxisSpacing: NoorSpacing.md,
              children: [
                for (final hex in _palette)
                  _PickTile(
                    hex: hex,
                    index: _picked.indexOf(hex),
                    onTap: () => _pick(hex),
                  ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(NoorSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _picked.isEmpty
                        ? 'Tap two blocks'
                        : _picked.length == 1
                            ? 'One more'
                            : 'Ready',
                    style: NoorText.body.copyWith(color: NoorColors.inkSoft),
                  ),
                ),
                FilledButton(
                  onPressed: _picked.length == 2 ? _next : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: NoorColors.forest,
                    minimumSize: const Size(150, 56),
                  ),
                  child: const Text(
                    'NEXT',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
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

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.hex,
    required this.index,
    required this.onTap,
  });

  final String hex;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = _colour(hex);
    final selected = index >= 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NoorRadius.md),
              gradient: LinearGradient(
                colors: [base, Color.lerp(base, Colors.black, 0.4)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: selected ? NoorColors.gold : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: NoorColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pre-filled from the order. He should be able to confirm without typing.
class _QuantityScreen extends StatefulWidget {
  const _QuantityScreen({
    required this.order,
    required this.step,
    required this.colours,
  });

  final SellerOrder order;
  final ProductionStep step;
  final List<String> colours;

  @override
  State<_QuantityScreen> createState() => _QuantityScreenState();
}

class _QuantityScreenState extends State<_QuantityScreen> {
  late int _qty = _expected;

  int get _expected =>
      widget.step.qtyIn ?? widget.order.totalPieces;

  List<int> get _chips {
    final full = _expected;
    return <int>{
      full,
      (full - 50).clamp(0, full),
      (full - 100).clamp(0, full),
    }.toList();
  }

  void _bump(int by) {
    HapticFeedback.selectionClick();
    setState(() => _qty = (_qty + by).clamp(0, 999999));
  }

  @override
  Widget build(BuildContext context) {
    final short = _expected - _qty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.step.stageName)),
      body: Padding(
        padding: const EdgeInsets.all(NoorSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final c in widget.colours)
                  Padding(
                    padding: const EdgeInsets.only(right: NoorSpacing.sm),
                    child: ColourBlock(
                      colours: [
                        _colour(c),
                        Color.lerp(_colour(c), Colors.black, 0.4)!,
                      ],
                      size: 52,
                    ),
                  ),
                const Spacer(),
                Pill(text: 'PHOTOS ADDED', colour: NoorColors.green),
              ],
            ),
            const SizedBox(height: NoorSpacing.lg),
            Text(
              'HOW MANY PIECES?',
              style: NoorText.label.copyWith(color: NoorColors.inkFaint),
            ),
            const SizedBox(height: NoorSpacing.md),
            Row(
              children: [
                _RoundButton(icon: Icons.remove, onTap: () => _bump(-10)),
                Expanded(
                  child: Text(
                    formatCount(_qty),
                    textAlign: TextAlign.center,
                    style: NoorText.hero.copyWith(fontSize: 60),
                  ),
                ),
                _RoundButton(icon: Icons.add, onTap: () => _bump(10)),
              ],
            ),
            const SizedBox(height: NoorSpacing.sm),
            Text(
              short > 0
                  ? '$short short of ${formatCount(_expected)}'
                  : short < 0
                      ? '${-short} more than expected'
                      : 'All of them',
              textAlign: TextAlign.center,
              style: NoorText.body.copyWith(
                color: short == 0 ? NoorColors.green : NoorColors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: NoorSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in _chips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: ChoiceChip(
                      label: Text(formatCount(c)),
                      selected: _qty == c,
                      showCheckmark: false,
                      selectedColor: NoorColors.forest,
                      backgroundColor: NoorColors.card,
                      surfaceTintColor: Colors.transparent,
                      side: const BorderSide(color: NoorColors.hairline),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _qty == c ? Colors.white : NoorColors.ink,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _qty = c);
                      },
                    ),
                  ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                StageCompletion(quantity: _qty, colours: widget.colours),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: NoorColors.forest,
                minimumSize: const Size.fromHeight(72),
              ),
              child: const Text(
                'CONFIRM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: NoorSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NoorColors.card,
      shape: const CircleBorder(
        side: BorderSide(color: NoorColors.hairline),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Icon(icon, size: 32, color: NoorColors.ink),
        ),
      ),
    );
  }
}

Color _colour(String hex) {
  final s = hex.replaceAll('#', '');
  if (s.length != 6) return const Color(0xFF9AA0A6);
  return Color(int.parse('FF$s', radix: 16));
}
