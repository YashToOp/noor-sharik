import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Every list gets one of these. Never a crash, never a blank screen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.tint = NoorColors.grey,
  });

  final String title;
  final String message;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoorSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(NoorRadius.sm),
                  ),
                ),
              ),
            ),
            const SizedBox(height: NoorSpacing.lg),
            Text(title, style: NoorText.title, textAlign: TextAlign.center),
            const SizedBox(height: NoorSpacing.sm),
            Text(
              message,
              style: NoorText.body.copyWith(color: NoorColors.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A block of colour standing in for a photograph. The seller recognises an
/// order by its colour long before he reads its number.
class ColourBlock extends StatelessWidget {
  const ColourBlock({
    super.key,
    required this.colours,
    this.size = 56,
    this.radius = NoorRadius.md,
  });

  final List<Color> colours;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = colours.isEmpty ? [NoorColors.greySoft, NoorColors.grey] : colours;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: c.length == 1 ? [c.first, c.first] : c,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    required this.colour,
    this.background,
  });

  final String text;
  final Color colour;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: NoorText.label.copyWith(color: colour),
      ),
    );
  }
}

class NoorCard extends StatelessWidget {
  const NoorCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
    this.padding = const EdgeInsets.all(NoorSpacing.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NoorColors.card,
      borderRadius: BorderRadius.circular(NoorRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NoorRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NoorRadius.lg),
            border: Border.all(
              color: accent?.withValues(alpha: 0.35) ?? NoorColors.hairline,
              width: accent == null ? 1 : 1.5,
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

String formatMoney(double v, String currency) {
  final whole = v.round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$currency $buf';
}

String formatCount(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String formatShortDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]}';
}
