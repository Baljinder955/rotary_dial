import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Public widget
/// A customizable rotary dial widget for Flutter.
///
/// This widget emulates a classic rotary phone dialer with realistic physics,
/// sound effects, and customizable styling.
class RotaryDial extends StatefulWidget {
  /// The size of the rotary dial. If null, it will be determined by the constraints.
  final double? size;

  /// Callback triggered when a digit is successfully dialed and registered.
  final ValueChanged<String> onDigitSelected;

  /// Theme customization for the rotary dial colors, sizes, and behaviors.
  final RotaryDialTheme theme;

  /// Specific flag to enable or disable haptic feedback during rotation.
  /// Defaults to true.
  final bool enableHaptics;

  /// Callback triggered when the dial is rotated.
  /// This can be used to play custom sound effects or trigger other actions on tick.
  final VoidCallback? onDialRotate;

  const RotaryDial({
    super.key,
    this.size,
    required this.onDigitSelected,
    this.theme = const RotaryDialTheme(),
    this.enableHaptics = true,
    this.onDialRotate,
  });

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial>
    with SingleTickerProviderStateMixin {
  // ── Animation ──
  late final AnimationController _controller;
  Animation<double>? _returnAnim;

  // ── Drag state ──
  double _rotation = 0.0;
  double _lastAngle = 0.0;
  double _lastTickRotation = 0.0;
  int? _activeDigit;
  int? _pendingDigit;
  bool _disposed = false;

  // ── Dial geometry ──
  static const double _stopAngle = 0.0;
  static const double _firstDigitGap = pi / 3.3;
  static const double _digitSpacing = pi / 6.0;
  static const double _dotAngle = 0.105;
  static const double _acceptThreshold = 0.85;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_onReturnComplete);
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeStatusListener(_onReturnComplete);
    _controller.dispose();
    super.dispose();
  }

  double _digitAngle(int digit) {
    final idx = digit == 0 ? 9 : digit - 1;
    return _stopAngle - (_firstDigitGap + idx * _digitSpacing);
  }

  double _maxRot(int digit) => _dotAngle - _digitAngle(digit);
  double _norm(double a) => atan2(sin(a), cos(a));

  // Ring arc: digit 0 → CW long way → digit 1 (≈ 270°)
  double get _ringStart {
    double a = _digitAngle(0);
    while (a < 0) {
      a += 2 * pi;
    }
    return a;
  }

  double get _ringSweep {
    double d1 = _digitAngle(1);
    while (d1 < 0) {
      d1 += 2 * pi;
    }
    return d1 - _ringStart;
  }

  // ── Gesture handlers ──
  void _onPanStart(DragStartDetails d) {
    if (_controller.isAnimating) return;

    final box = context.findRenderObject() as RenderBox;
    final center = box.size.center(Offset.zero);
    final local = d.localPosition - center;

    final halfW = box.size.width / 2;

    // configurable hit region
    final minR = halfW * widget.theme.gestureMinRadiusFactor;
    final maxR = halfW * widget.theme.gestureMaxRadiusFactor;

    if (local.distance < minR || local.distance > maxR) return;

    _lastAngle = atan2(local.dy, local.dx);
    _lastTickRotation = _rotation;
    _activeDigit = null;

    for (int digit = 0; digit <= 9; digit++) {
      final h = _norm(_digitAngle(digit) + _rotation);
      if (_norm(h - _lastAngle).abs() < widget.theme.digitTouchAngleWindow) {
        _activeDigit = digit;
        break;
      }
    }

    if (!_disposed) setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_activeDigit == null) return;

    final box = context.findRenderObject() as RenderBox;
    final center = box.size.center(Offset.zero);
    final local = d.localPosition - center;

    final halfW = box.size.width / 2;
    final minR = halfW * widget.theme.dragCancelMinRadiusFactor;
    final maxR = halfW * widget.theme.dragCancelMaxRadiusFactor;

    if (local.distance < minR || local.distance > maxR) {
      _release(canceled: true);
      return;
    }

    final angle = atan2(local.dy, local.dx);
    double delta = _norm(angle - _lastAngle);

    // only allow CW rotation
    if (delta < 0) delta = 0;

    final newRot = (_rotation + delta).clamp(0.0, _maxRot(_activeDigit!));

    if (!_disposed) {
      if ((newRot - _lastTickRotation).abs() > 0.17) {
        // ~10 degrees
        if (widget.enableHaptics) HapticFeedback.selectionClick();
        widget.onDialRotate?.call();
        _lastTickRotation = newRot;
      }

      setState(() {
        _rotation = newRot;
        _lastAngle = angle;
      });
    }
  }

  void _onPanEnd(DragEndDetails _) => _release();
  void _onPanCancel() => _release(canceled: true);

  void _release({bool canceled = false}) {
    if (canceled || _activeDigit == null) {
      _pendingDigit = null;
    } else {
      final m = _maxRot(_activeDigit!);
      _pendingDigit = _rotation >= m * _acceptThreshold ? _activeDigit : null;
    }
    _activeDigit = null;
    _animateReturn();
  }

  void _animateReturn() {
    if (_rotation == 0.0) {
      _tryRegister();
      return;
    }

    final frac = _rotation / _maxRot(0);

    final ms = (widget.theme.returnBaseMs + frac * widget.theme.returnExtraMs)
        .clamp(widget.theme.returnMinMs, widget.theme.returnMaxMs)
        .toInt();

    _controller.duration = Duration(milliseconds: ms);

    _returnAnim = Tween<double>(begin: _rotation, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.theme.returnCurve),
    )..addListener(() {
        if (!_disposed) {
          final val = _returnAnim!.value;
          // Trigger tick on return
          if ((val - _lastTickRotation).abs() > 0.17) {
            if (widget.enableHaptics) HapticFeedback.selectionClick();
            widget.onDialRotate?.call();
            _lastTickRotation = val;
          }
          setState(() => _rotation = val);
        }
      });

    _controller.forward(from: 0.0);
  }

  void _onReturnComplete(AnimationStatus s) {
    if (s == AnimationStatus.completed) _tryRegister();
  }

  void _tryRegister() {
    _lastTickRotation = 0.0;

    if (_pendingDigit != null) {
      if (widget.enableHaptics) {
        HapticFeedback.mediumImpact();
      }
      widget.onDigitSelected(_pendingDigit.toString());
      _pendingDigit = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.size != null) return _buildDial(widget.size!);

    return LayoutBuilder(
      builder: (_, box) => _buildDial(min(box.maxWidth, box.maxHeight)),
    );
  }

  Widget _buildDial(double s) {
    final t = widget.theme;

    // scale factors controlled by theme
    final numDist = s * t.numberDistanceFactor;
    final numSize = s * t.numberSizeFactor;

    final holeW = (numSize + t.holeExtraWidthPx) * t.holeWidthFactor;
    final holeH = holeW * t.holeHeightFactor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(s, s),
              painter: _BasePainter(
                digitAngleFn: _digitAngle,
                numberDist: numDist,
                numberSize: numSize,
                dotAngle: _dotAngle,
                activeDigit: _activeDigit,
                theme: t,
              ),
            ),
            Transform.rotate(
              angle: _rotation,
              child: CustomPaint(
                size: Size(s, s),
                painter: _RingPainter(
                  digitAngleFn: _digitAngle,
                  numberDist: numDist,
                  holeWidth: holeW,
                  holeHeight: holeH,
                  arcStart: _ringStart,
                  arcSweep: _ringSweep,
                  activeDigit: _activeDigit,
                  theme: t,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// All UI controls live here.
/// Theme data for customizing the visual appearance and behavior of the [RotaryDial].
///
/// This class provides granular control over colors, gradients, stroke widths,
/// sizing factors, text styles, and animation parameters.
@immutable
class RotaryDialTheme {
  // ===== COLORS =====

  /// Fill color for the static base circle (Layer 1).
  final Color baseFillColor;

  /// Optional gradient for the base circle. If provided, it overrides [baseFillColor].
  final Gradient? baseGradient;

  /// Color of the outline stroke for the base circle.
  final Color baseOutlineColor;

  /// Fill color for the center circle (where the active digit is displayed).
  final Color centerFillColor;

  /// Color of the outline stroke for the center circle.
  final Color centerOutlineColor;

  /// Fill color for the rotating ring (Layer 2).
  final Color ringFillColor;

  /// Color of the outline stroke for the rotating ring.
  final Color ringOutlineColor;

  /// Optional gradient for the ring. When non-null, overrides [ringFillColor].
  final Gradient? ringGradient;

  /// Color of the numbers on the base dial.
  final Color numberColor;

  /// Color of the number when it is currently being dialed (active).
  final Color activeNumberColor;

  /// Color of the text displayed in the center of the dial.
  /// If null, defaults to [baseFillColor].
  final Color? centerDigitColor;

  /// Color of the stop dot.
  final Color dotColor;

  /// Color of the outline for the digit holes on the ring.
  final Color holeOutlineColor;

  /// Color of the outline for the digit hole that is currently active/selected.
  final Color activeHoleOutlineColor;

  /// Color used for the glow effect on active elements (numbers and holes).
  final Color activeGlowColor;

  // ===== STROKES =====

  /// Stroke width for the base circle outline.
  final double baseOutlineStrokePx;

  /// Stroke width for the center circle outline.
  final double centerOutlineStrokePx;

  /// Stroke width for the ring outline.
  final double ringOutlineStrokePx;

  /// Stroke width for the digit hole outlines.
  final double holeOutlineStrokePx;

  /// Stroke width for the active digit hole outline.
  final double activeHoleOutlineStrokePx;

  // ===== SIZING FACTORS =====

  /// Factor determining the outer radius of the dial elements relative to the widget size.
  /// Range: 0.0 to 1.0 (default 0.98).
  final double outerRadiusFactor;

  /// Factor determining the inner radius (hole for the center) relative to the widget size.
  /// Range: 0.0 to 1.0 (default 0.45).
  final double innerRadiusFactor;

  /// Factor determining the distance of numbers from the center.
  final double numberDistanceFactor;

  /// Factor determining the size of the numbers.
  final double numberSizeFactor;

  /// Factor determining the radius of the stop dot.
  final double dotRadiusFactor;

  /// Factor scaling the width of the digit holes.
  /// Width is calculated based on number size + [holeExtraWidthPx].
  final double holeWidthFactor;

  /// Factor scaling the height of the digit holes.
  final double holeHeightFactor;

  /// Extra pixel width added to the hole calculation before scaling.
  final double holeExtraWidthPx;

  // ===== TEXT =====

  /// Text style for the numbers on the dial.
  final TextStyle numberTextStyle;

  /// Text style for the digit displayed in the center.
  final TextStyle centerTextStyle;

  // ===== ACTIVE EFFECTS =====

  /// Whether to enable the glow effect for the active digit and hole.
  final bool enableActiveGlow;

  /// Sigma (blur radius) for the active number glow.
  final double activeNumberGlowSigma;

  /// Sigma (blur radius) for the active hole glow.
  final double activeHoleGlowSigma;

  /// Factor scaling the radius of the glow behind the active number.
  final double activeNumberGlowRadiusFactor;

  // ===== GESTURE TUNING =====

  /// The angular window (in radians) to detect which digit is being touched.
  final double digitTouchAngleWindow;

  /// Minimum radius factor (relative to half width) for detecting gestures.
  final double gestureMinRadiusFactor;

  /// Maximum radius factor (relative to half width) for detecting gestures.
  final double gestureMaxRadiusFactor;

  /// Minimum radius factor to cancel a drag operation.
  final double dragCancelMinRadiusFactor;

  /// Maximum radius factor to cancel a drag operation.
  final double dragCancelMaxRadiusFactor;

  // ===== RETURN ANIMATION =====

  /// Base duration (in ms) for the return animation.
  final int returnBaseMs;

  /// Extra duration (in ms) added scaling with the rotation distance.
  final int returnExtraMs;

  /// Minimum duration (in ms) for the return animation.
  final int returnMinMs;

  /// Maximum duration (in ms) for the return animation.
  final int returnMaxMs;

  /// Curve used for the return animation.
  final Curve returnCurve;

  /// Creates a [RotaryDialTheme].
  const RotaryDialTheme({
    // colors
    this.baseFillColor = Colors.black,
    this.baseGradient,
    this.baseOutlineColor = Colors.black,
    this.centerFillColor = Colors.white,
    this.centerOutlineColor = Colors.black,
    this.ringFillColor = Colors.white,
    this.ringOutlineColor = Colors.black,
    this.ringGradient,
    this.numberColor = Colors.white,
    this.activeNumberColor = Colors.amber,
    this.centerDigitColor,
    this.dotColor = Colors.white,
    this.holeOutlineColor = Colors.black,
    this.activeHoleOutlineColor = Colors.amber,
    this.activeGlowColor = Colors.amber,

    // strokes
    this.baseOutlineStrokePx = 3,
    this.centerOutlineStrokePx = 3,
    this.ringOutlineStrokePx = 3,
    this.holeOutlineStrokePx = 3,
    this.activeHoleOutlineStrokePx = 3.5,

    // sizing
    this.outerRadiusFactor = 0.98,
    this.innerRadiusFactor = 0.45,
    this.numberDistanceFactor = 0.37,
    this.numberSizeFactor = 0.13,
    this.dotRadiusFactor = 0.04,
    this.holeWidthFactor = 1.20,
    this.holeHeightFactor = 1.0,
    this.holeExtraWidthPx = 5,

    // text
    this.numberTextStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),
    this.centerTextStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      height: 1.0,
    ),

    // glow
    this.enableActiveGlow = true,
    this.activeNumberGlowSigma = 12,
    this.activeHoleGlowSigma = 8,
    this.activeNumberGlowRadiusFactor = 0.7,

    // gesture tuning
    this.digitTouchAngleWindow = 0.24,
    this.gestureMinRadiusFactor = 0.30,
    this.gestureMaxRadiusFactor = 1.02,
    this.dragCancelMinRadiusFactor = 0.15,
    this.dragCancelMaxRadiusFactor = 1.30,

    // animation
    this.returnBaseMs = 300,
    this.returnExtraMs = 500,
    this.returnMinMs = 250,
    this.returnMaxMs = 800,
    this.returnCurve = Curves.easeOutCubic,
  });
}

// ═══════════════════════════════════════════════════════════════
// Layer 1 — Static base + numbers + dot
// ═══════════════════════════════════════════════════════════════
class _BasePainter extends CustomPainter {
  final double Function(int) digitAngleFn;
  final double numberDist;
  final double numberSize;
  final double dotAngle;
  final int? activeDigit;
  final RotaryDialTheme theme;

  _BasePainter({
    required this.digitAngleFn,
    required this.numberDist,
    required this.numberSize,
    required this.dotAngle,
    required this.theme,
    this.activeDigit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    final outerR = r * theme.outerRadiusFactor;
    final innerR = r * theme.innerRadiusFactor;
    final midR = (outerR + innerR) / 2;

    // Base paints
    final baseOutline = Paint()
      ..color = theme.baseOutlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.baseOutlineStrokePx;

    final centerOutline = Paint()
      ..color = theme.centerOutlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.centerOutlineStrokePx;

    // Base outer
    if (theme.baseGradient != null) {
      final gradPaint = Paint()
        ..shader = theme.baseGradient!.createShader(
          Rect.fromCircle(center: center, radius: outerR),
        );
      canvas.drawCircle(center, outerR, gradPaint);
    } else {
      canvas.drawCircle(center, outerR, Paint()..color = theme.baseFillColor);
    }

    canvas.drawCircle(center, outerR, baseOutline);

    // Center
    canvas.drawCircle(
      center,
      innerR + 2,
      Paint()..color = theme.centerFillColor,
    );
    canvas.drawCircle(center, innerR, centerOutline);

    // Digits
    for (int i = 0; i < 10; i++) {
      final digit = (i + 1) % 10;
      final a = digitAngleFn(digit);

      final c = Offset(
        center.dx + numberDist * cos(a),
        center.dy + numberDist * sin(a),
      );

      final isActive = digit == activeDigit;

      if (theme.enableActiveGlow && isActive) {
        final glowPaint = Paint()
          ..color = theme.activeGlowColor.withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            theme.activeNumberGlowSigma,
          );
        canvas.drawCircle(
          c,
          numberSize * theme.activeNumberGlowRadiusFactor,
          glowPaint,
        );
      }

      final style = theme.numberTextStyle.copyWith(
        color: isActive ? theme.activeNumberColor : theme.numberColor,
        fontSize: numberSize * 0.9,
      );

      final tp = TextPainter(
        text: TextSpan(text: digit.toString(), style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }

    // Stop dot
    final dot = Offset(
      center.dx + midR * cos(dotAngle),
      center.dy + midR * sin(dotAngle),
    );
    canvas.drawCircle(
      dot,
      r * theme.dotRadiusFactor,
      Paint()..color = theme.dotColor,
    );

    // Center digit display
    if (activeDigit != null) {
      final style = theme.centerTextStyle.copyWith(
        color: theme.centerDigitColor ?? theme.baseFillColor,
        fontSize: innerR * 0.7,
      );

      final tp = TextPainter(
        text: TextSpan(text: activeDigit.toString(), style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BasePainter old) =>
      numberDist != old.numberDist ||
      numberSize != old.numberSize ||
      activeDigit != old.activeDigit ||
      theme != old.theme;
}

// ═══════════════════════════════════════════════════════════════
// Layer 2 — Rotating ring with holes
// ═══════════════════════════════════════════════════════════════
class _RingPainter extends CustomPainter {
  final double Function(int) digitAngleFn;
  final double numberDist;
  final double holeWidth;
  final double holeHeight;
  final double arcStart;
  final double arcSweep;
  final int? activeDigit;
  final RotaryDialTheme theme;

  _RingPainter({
    required this.digitAngleFn,
    required this.numberDist,
    required this.holeWidth,
    required this.holeHeight,
    required this.arcStart,
    required this.arcSweep,
    required this.theme,
    this.activeDigit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    final outerR = r * theme.outerRadiusFactor;
    final innerR = r * theme.innerRadiusFactor;
    final midR = (outerR + innerR) / 2;
    final capR = (outerR - innerR) / 2;

    final endAngle = arcStart + arcSweep;

    // 1) Sector
    Path sector = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerR),
        arcStart,
        arcSweep,
        false,
      )
      ..lineTo(
        center.dx + innerR * cos(endAngle),
        center.dy + innerR * sin(endAngle),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerR),
        endAngle,
        -arcSweep,
        false,
      )
      ..close();

    // 2) Caps
    final sCap = Offset(
      center.dx + midR * cos(arcStart),
      center.dy + midR * sin(arcStart),
    );
    final eCap = Offset(
      center.dx + midR * cos(endAngle),
      center.dy + midR * sin(endAngle),
    );

    final c1 = Path()..addOval(Rect.fromCircle(center: sCap, radius: capR));
    final c2 = Path()..addOval(Rect.fromCircle(center: eCap, radius: capR));

    Path ring = Path.combine(PathOperation.union, sector, c1);
    ring = Path.combine(PathOperation.union, ring, c2);

    // 3) Holes
    final holes = Path();
    final holeInfos = <_HoleInfo>[];

    for (int i = 0; i < 10; i++) {
      final digit = (i + 1) % 10;
      final a = digitAngleFn(digit);

      final cx = center.dx + numberDist * cos(a);
      final cy = center.dy + numberDist * sin(a);

      holeInfos.add(_HoleInfo(Offset(cx, cy), a, holeWidth, holeHeight, digit));

      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: holeWidth,
          height: holeHeight,
        ),
        Radius.circular(holeWidth / 2),
      );

      final hp = Path()..addRRect(rr);

      final m = Matrix4.identity()
        ..setTranslationRaw(cx, cy, 0)
        ..rotateZ(a + pi / 2);

      holes.addPath(hp, Offset.zero, matrix4: m.storage);
    }

    // 4) Paint ring + punch holes
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Use gradient if provided, otherwise flat color
    if (theme.ringGradient != null) {
      final gradPaint = Paint()
        ..shader = theme.ringGradient!.createShader(
          Rect.fromCircle(center: center, radius: outerR),
        );
      canvas.drawPath(ring, gradPaint);
    } else {
      canvas.drawPath(ring, Paint()..color = theme.ringFillColor);
    }

    canvas.drawPath(holes, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 5) Ring outline
    canvas.drawPath(
      ring,
      Paint()
        ..color = theme.ringOutlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.ringOutlineStrokePx,
    );

    // 6) Hole outlines
    final defaultStroke = Paint()
      ..color = theme.holeOutlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.holeOutlineStrokePx;

    final activeStroke = Paint()
      ..color = theme.activeHoleOutlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.activeHoleOutlineStrokePx;

    final activeGlow = Paint()
      ..color = theme.activeGlowColor.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        theme.activeHoleGlowSigma,
      );

    for (final h in holeInfos) {
      final isActive = h.digit == activeDigit;

      canvas.save();
      canvas.translate(h.c.dx, h.c.dy);
      canvas.rotate(h.a + pi / 2);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: h.w, height: h.h),
        Radius.circular(h.w / 2),
      );

      if (theme.enableActiveGlow && isActive) {
        canvas.drawRRect(rrect, activeGlow);
      }

      canvas.drawRRect(rrect, isActive ? activeStroke : defaultStroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      numberDist != old.numberDist ||
      holeWidth != old.holeWidth ||
      holeHeight != old.holeHeight ||
      activeDigit != old.activeDigit ||
      theme != old.theme;
}

class _HoleInfo {
  final Offset c;
  final double a;
  final double w;
  final double h;
  final int digit;
  _HoleInfo(this.c, this.a, this.w, this.h, this.digit);
}
