import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The garment shapes Sharik can draw.
///
/// These are vector silhouettes, not photographs. A real photo would come from
/// `media_assets`; until the camera exists, a seller should still see the shape
/// of the thing he is making, in the colour he is making it.
enum GarmentKind {
  skirt,
  pleatedSkirt,
  jeans,
  dress,
  blouse,
  abaya,
  kaftan,
  set,
  fabric,
}

/// Pick the shape from what the style is called. The database has no garment
/// type column, and this is a display-only guess — never persist it.
GarmentKind garmentFor(String styleName, [String styleCode = '']) {
  final s = '$styleName $styleCode'.toLowerCase();
  bool has(List<String> words) => words.any(s.contains);

  if (has(['jean', 'denim', 'trouser', 'pant', 'chino'])) return GarmentKind.jeans;
  if (has(['abaya'])) return GarmentKind.abaya;
  if (has(['kaftan', 'caftan'])) return GarmentKind.kaftan;
  if (has(['pleat']) && has(['skirt'])) return GarmentKind.pleatedSkirt;
  if (has(['skirt'])) return GarmentKind.skirt;
  if (has(['dress', 'gown'])) return GarmentKind.dress;
  if (has(['blouse', 'shirt', 'top', 'tunic'])) return GarmentKind.blouse;
  if (has(['set', 'suit', 'co-ord'])) return GarmentKind.set;
  return GarmentKind.fabric;
}

/// A garment rendered in one colourway. Use this wherever a swatch used to be:
/// he recognises the order by colour, and now also by shape.
class GarmentTile extends StatelessWidget {
  const GarmentTile({
    super.key,
    required this.kind,
    required this.colour,
    this.size = 62,
    this.width,
    this.height,
    this.radius = NoorRadius.md,
  });

  final GarmentKind kind;
  final Color colour;
  final double size;

  /// Override for a wide panel; the garment stays in proportion and centres.
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? size,
      height: height ?? size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: GarmentPainter(kind: kind, colour: colour),
          size: Size(width ?? size, height ?? size),
        ),
      ),
    );
  }
}

class GarmentPainter extends CustomPainter {
  GarmentPainter({required this.kind, required this.colour});

  /// width : height of the garment box itself.
  static const double _aspect = 0.82;

  final GarmentKind kind;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // A near-neutral studio backdrop, faintly tinted so the garment sits in a
    // scene rather than floating. Kept close to neutral: in a textile app the
    // colour has to read true.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(NoorColors.paper, colour, 0.06)!,
            Color.lerp(const Color(0xFFE8E4DA), colour, 0.14)!,
          ],
        ).createShader(rect),
    );

    final dark = Color.lerp(colour, Colors.black, 0.34)!;
    final light = Color.lerp(colour, Colors.white, 0.12)!;

    final body = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, colour, dark],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);

    final seam = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.shortestSide * 0.014).clamp(0.6, 1.8)
      ..color = Color.lerp(colour, Colors.black, 0.45)!.withValues(alpha: 0.55);

    // The garment keeps a portrait proportion and centres itself, so a wide
    // hero panel does not stretch a skirt sideways.
    var gh = h;
    var gw = gh * _aspect;
    if (gw > w) {
      gw = w;
      gh = gw / _aspect;
    }
    final dx = (w - gw) / 2;
    final dy = (h - gh) / 2;

    Offset p(double x, double y) => Offset(dx + x * gw, dy + y * gh);
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(p(x1, y1), p(x2, y2), seam);

    switch (kind) {
      case GarmentKind.skirt:
        _skirt(canvas, p, body, seam, line);
      case GarmentKind.pleatedSkirt:
        _pleatedSkirt(canvas, p, body, seam, line);
      case GarmentKind.jeans:
        _jeans(canvas, p, body, seam, line);
      case GarmentKind.dress:
        _dress(canvas, p, body, line);
      case GarmentKind.blouse:
        _blouse(canvas, p, body, line);
      case GarmentKind.abaya:
        _abaya(canvas, p, body, line);
      case GarmentKind.kaftan:
        _kaftan(canvas, p, body, line);
      case GarmentKind.set:
        _set(canvas, p, body, line);
      case GarmentKind.fabric:
        _fabric(canvas, p, body, line);
    }
  }

  // ------------------------------------------------------------- silhouettes

  void _waistband(
    Canvas canvas,
    Offset Function(double, double) p,
    Paint body,
    Paint seam,
    double l,
    double r,
    double top,
    double bottom,
  ) {
    final band = Rect.fromPoints(p(l, top), p(r, bottom));
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(band.height * 0.35)),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(band.height * 0.35)),
      seam,
    );
  }

  void _skirt(Canvas canvas, Offset Function(double, double) p, Paint body,
      Paint seam, void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.34, 0.20).dx, p(0.34, 0.20).dy)
      ..lineTo(p(0.66, 0.20).dx, p(0.66, 0.20).dy)
      ..lineTo(p(0.85, 0.80).dx, p(0.85, 0.80).dy)
      ..quadraticBezierTo(
          p(0.5, 0.90).dx, p(0.5, 0.90).dy, p(0.15, 0.80).dx, p(0.15, 0.80).dy)
      ..close();
    canvas.drawPath(path, body);
    _waistband(canvas, p, body, seam, 0.32, 0.68, 0.13, 0.21);
    line(0.44, 0.22, 0.36, 0.82);
    line(0.56, 0.22, 0.64, 0.82);
  }

  void _pleatedSkirt(Canvas canvas, Offset Function(double, double) p,
      Paint body, Paint seam, void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.36, 0.20).dx, p(0.36, 0.20).dy)
      ..lineTo(p(0.64, 0.20).dx, p(0.64, 0.20).dy)
      ..lineTo(p(0.90, 0.86).dx, p(0.90, 0.86).dy)
      ..quadraticBezierTo(
          p(0.5, 0.96).dx, p(0.5, 0.96).dy, p(0.10, 0.86).dx, p(0.10, 0.86).dy)
      ..close();
    canvas.drawPath(path, body);
    _waistband(canvas, p, body, seam, 0.34, 0.66, 0.13, 0.21);
    // the pleats
    for (var i = 1; i <= 5; i++) {
      final t = i / 6;
      line(0.36 + 0.28 * t, 0.22, 0.11 + 0.78 * t, 0.89);
    }
  }

  void _jeans(Canvas canvas, Offset Function(double, double) p, Paint body,
      Paint seam, void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.28, 0.19).dx, p(0.28, 0.19).dy)
      ..lineTo(p(0.72, 0.19).dx, p(0.72, 0.19).dy)
      ..lineTo(p(0.78, 0.93).dx, p(0.78, 0.93).dy)
      ..lineTo(p(0.565, 0.93).dx, p(0.565, 0.93).dy)
      ..lineTo(p(0.50, 0.52).dx, p(0.50, 0.52).dy)
      ..lineTo(p(0.435, 0.93).dx, p(0.435, 0.93).dy)
      ..lineTo(p(0.22, 0.93).dx, p(0.22, 0.93).dy)
      ..close();
    canvas.drawPath(path, body);
    _waistband(canvas, p, body, seam, 0.26, 0.74, 0.12, 0.20);
    line(0.50, 0.21, 0.50, 0.40); // fly
    line(0.32, 0.22, 0.38, 0.30); // pockets
    line(0.68, 0.22, 0.62, 0.30);
  }

  void _dress(Canvas canvas, Offset Function(double, double) p, Paint body,
      void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.34, 0.15).dx, p(0.34, 0.15).dy)
      ..lineTo(p(0.43, 0.13).dx, p(0.43, 0.13).dy)
      ..quadraticBezierTo(
          p(0.5, 0.24).dx, p(0.5, 0.24).dy, p(0.57, 0.13).dx, p(0.57, 0.13).dy)
      ..lineTo(p(0.66, 0.15).dx, p(0.66, 0.15).dy)
      ..lineTo(p(0.76, 0.30).dx, p(0.76, 0.30).dy)
      ..lineTo(p(0.67, 0.34).dx, p(0.67, 0.34).dy)
      ..lineTo(p(0.63, 0.47).dx, p(0.63, 0.47).dy)
      ..lineTo(p(0.85, 0.87).dx, p(0.85, 0.87).dy)
      ..quadraticBezierTo(
          p(0.5, 0.96).dx, p(0.5, 0.96).dy, p(0.15, 0.87).dx, p(0.15, 0.87).dy)
      ..lineTo(p(0.37, 0.47).dx, p(0.37, 0.47).dy)
      ..lineTo(p(0.33, 0.34).dx, p(0.33, 0.34).dy)
      ..lineTo(p(0.24, 0.30).dx, p(0.24, 0.30).dy)
      ..close();
    canvas.drawPath(path, body);
    // The wrap: a lapel from the neckline to the side waist, with the under
    // panel showing. One diagonal alone reads as a slash at small sizes.
    line(0.44, 0.23, 0.60, 0.47);
    line(0.37, 0.47, 0.63, 0.47); // waist seam
  }

  void _blouse(Canvas canvas, Offset Function(double, double) p, Paint body,
      void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.32, 0.20).dx, p(0.32, 0.20).dy)
      ..lineTo(p(0.42, 0.18).dx, p(0.42, 0.18).dy)
      ..quadraticBezierTo(
          p(0.5, 0.30).dx, p(0.5, 0.30).dy, p(0.58, 0.18).dx, p(0.58, 0.18).dy)
      ..lineTo(p(0.68, 0.20).dx, p(0.68, 0.20).dy)
      ..lineTo(p(0.80, 0.38).dx, p(0.80, 0.38).dy)
      ..lineTo(p(0.70, 0.44).dx, p(0.70, 0.44).dy)
      ..lineTo(p(0.72, 0.78).dx, p(0.72, 0.78).dy)
      ..lineTo(p(0.28, 0.78).dx, p(0.28, 0.78).dy)
      ..lineTo(p(0.30, 0.44).dx, p(0.30, 0.44).dy)
      ..lineTo(p(0.20, 0.38).dx, p(0.20, 0.38).dy)
      ..close();
    canvas.drawPath(path, body);
    line(0.50, 0.30, 0.50, 0.78); // placket
  }

  void _abaya(Canvas canvas, Offset Function(double, double) p, Paint body,
      void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.38, 0.13).dx, p(0.38, 0.13).dy)
      ..quadraticBezierTo(
          p(0.5, 0.20).dx, p(0.5, 0.20).dy, p(0.62, 0.13).dx, p(0.62, 0.13).dy)
      ..lineTo(p(0.74, 0.21).dx, p(0.74, 0.21).dy)
      ..lineTo(p(0.82, 0.62).dx, p(0.82, 0.62).dy)
      ..lineTo(p(0.72, 0.64).dx, p(0.72, 0.64).dy)
      ..lineTo(p(0.79, 0.92).dx, p(0.79, 0.92).dy)
      ..quadraticBezierTo(
          p(0.5, 0.98).dx, p(0.5, 0.98).dy, p(0.21, 0.92).dx, p(0.21, 0.92).dy)
      ..lineTo(p(0.28, 0.64).dx, p(0.28, 0.64).dy)
      ..lineTo(p(0.18, 0.62).dx, p(0.18, 0.62).dy)
      ..lineTo(p(0.26, 0.21).dx, p(0.26, 0.21).dy)
      ..close();
    canvas.drawPath(path, body);
    line(0.50, 0.19, 0.50, 0.94); // front opening
  }

  void _kaftan(Canvas canvas, Offset Function(double, double) p, Paint body,
      void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.38, 0.16).dx, p(0.38, 0.16).dy)
      ..quadraticBezierTo(
          p(0.5, 0.24).dx, p(0.5, 0.24).dy, p(0.62, 0.16).dx, p(0.62, 0.16).dy)
      ..lineTo(p(0.86, 0.36).dx, p(0.86, 0.36).dy)
      ..lineTo(p(0.74, 0.44).dx, p(0.74, 0.44).dy)
      ..lineTo(p(0.80, 0.88).dx, p(0.80, 0.88).dy)
      ..quadraticBezierTo(
          p(0.5, 0.95).dx, p(0.5, 0.95).dy, p(0.20, 0.88).dx, p(0.20, 0.88).dy)
      ..lineTo(p(0.26, 0.44).dx, p(0.26, 0.44).dy)
      ..lineTo(p(0.14, 0.36).dx, p(0.14, 0.36).dy)
      ..close();
    canvas.drawPath(path, body);
    line(0.42, 0.28, 0.58, 0.28); // yoke embroidery
    line(0.44, 0.34, 0.56, 0.34);
  }

  void _set(Canvas canvas, Offset Function(double, double) p, Paint body,
      void Function(double, double, double, double) line) {
    final top = Path()
      ..moveTo(p(0.30, 0.16).dx, p(0.30, 0.16).dy)
      ..lineTo(p(0.70, 0.16).dx, p(0.70, 0.16).dy)
      ..lineTo(p(0.78, 0.28).dx, p(0.78, 0.28).dy)
      ..lineTo(p(0.70, 0.33).dx, p(0.70, 0.33).dy)
      ..lineTo(p(0.70, 0.50).dx, p(0.70, 0.50).dy)
      ..lineTo(p(0.30, 0.50).dx, p(0.30, 0.50).dy)
      ..lineTo(p(0.30, 0.33).dx, p(0.30, 0.33).dy)
      ..lineTo(p(0.22, 0.28).dx, p(0.22, 0.28).dy)
      ..close();
    final bottom = Path()
      ..moveTo(p(0.32, 0.55).dx, p(0.32, 0.55).dy)
      ..lineTo(p(0.68, 0.55).dx, p(0.68, 0.55).dy)
      ..lineTo(p(0.72, 0.92).dx, p(0.72, 0.92).dy)
      ..lineTo(p(0.55, 0.92).dx, p(0.55, 0.92).dy)
      ..lineTo(p(0.50, 0.70).dx, p(0.50, 0.70).dy)
      ..lineTo(p(0.45, 0.92).dx, p(0.45, 0.92).dy)
      ..lineTo(p(0.28, 0.92).dx, p(0.28, 0.92).dy)
      ..close();
    canvas.drawPath(top, body);
    canvas.drawPath(bottom, body);
    line(0.32, 0.55, 0.68, 0.55);
  }

  /// A folded bolt of cloth — the fallback when the style name says nothing.
  void _fabric(Canvas canvas, Offset Function(double, double) p, Paint body,
      void Function(double, double, double, double) line) {
    final path = Path()
      ..moveTo(p(0.16, 0.30).dx, p(0.16, 0.30).dy)
      ..lineTo(p(0.84, 0.22).dx, p(0.84, 0.22).dy)
      ..lineTo(p(0.84, 0.72).dx, p(0.84, 0.72).dy)
      ..quadraticBezierTo(
          p(0.5, 0.86).dx, p(0.5, 0.86).dy, p(0.16, 0.78).dx, p(0.16, 0.78).dy)
      ..close();
    canvas.drawPath(path, body);
    line(0.16, 0.44, 0.84, 0.37);
    line(0.16, 0.58, 0.84, 0.52);
  }

  @override
  bool shouldRepaint(covariant GarmentPainter old) =>
      old.kind != kind || old.colour != colour;
}
