import 'package:flutter/material.dart';

/// The MindPal logo: the cursive "m" with a leaf and a warm dot, on a lavender
/// gradient tile. The letter and leaf are outlines stored as points (unit square),
/// drawn in code, so the logo is sharp at every size and needs no image file.
class LogoPainter extends CustomPainter {
  const LogoPainter();

  static const gradientColors = [Color(0xFFC6AEDB), Color(0xFF7B49A3)];
  static const letterColor = Color(0xFFFFF0CF);
  static const dotColor = Color(0xFFF98C45);
  static const leafColor = Color(0xFFA997BA);
  static const veinColor = Color(0xFF8A70B0);

  // Outline of the letter "m" (x, y pairs, 0..1).
  static const _letter = <double>[
  0.1992, 0.3594, 0.1992, 0.3623, 0.1943, 0.3672, 0.1836, 0.3906, 0.1797, 0.4141, 0.1797, 0.4287,
  0.1865, 0.4512, 0.1953, 0.4629, 0.1992, 0.4639, 0.2031, 0.4688, 0.2178, 0.4717, 0.2188, 0.4736,
  0.2432, 0.4717, 0.2598, 0.4629, 0.2598, 0.458, 0.251, 0.4443, 0.25, 0.4258, 0.2539, 0.4062,
  0.2568, 0.4053, 0.2578, 0.3994, 0.2686, 0.3828, 0.2891, 0.3623, 0.3018, 0.3555, 0.3203, 0.3516,
  0.3262, 0.3555, 0.3311, 0.3672, 0.3311, 0.3818, 0.3252, 0.4131, 0.3125, 0.4502, 0.3096, 0.4531,
  0.3008, 0.4766, 0.2725, 0.5332, 0.2686, 0.5459, 0.2646, 0.5498, 0.2646, 0.5537, 0.2627, 0.5547,
  0.2578, 0.5693, 0.2559, 0.5703, 0.2529, 0.583, 0.25, 0.5869, 0.25, 0.5918, 0.2471, 0.5938,
  0.2393, 0.623, 0.2383, 0.6396, 0.2363, 0.6436, 0.2363, 0.6748, 0.2383, 0.6787, 0.2383, 0.6885,
  0.2461, 0.7109, 0.249, 0.7129, 0.252, 0.7207, 0.2617, 0.7324, 0.2656, 0.7344, 0.2656, 0.7363,
  0.2812, 0.7432, 0.292, 0.7422, 0.3018, 0.7373, 0.3115, 0.7246, 0.3125, 0.7188, 0.3076, 0.7129,
  0.3057, 0.7061, 0.3047, 0.6553, 0.3076, 0.6367, 0.3066, 0.6328, 0.3125, 0.5967, 0.3145, 0.5947,
  0.3184, 0.5723, 0.3213, 0.5674, 0.3213, 0.5625, 0.3232, 0.5615, 0.3223, 0.5586, 0.3271, 0.5488,
  0.3301, 0.5342, 0.335, 0.5264, 0.3389, 0.5107, 0.3428, 0.5068, 0.3428, 0.502, 0.3506, 0.4883,
  0.3525, 0.4805, 0.3662, 0.457, 0.3711, 0.4443, 0.374, 0.4424, 0.374, 0.4385, 0.377, 0.4375,
  0.3779, 0.4326, 0.3838, 0.4258, 0.3867, 0.418, 0.3926, 0.4121, 0.3936, 0.4072, 0.4053, 0.3945,
  0.4062, 0.3906, 0.4102, 0.3887, 0.4219, 0.375, 0.4424, 0.3623, 0.4512, 0.3633, 0.4541, 0.3672,
  0.4521, 0.3975, 0.4258, 0.499, 0.4238, 0.5, 0.4092, 0.5537, 0.4092, 0.5615, 0.4072, 0.5625,
  0.4033, 0.5859, 0.4043, 0.5928, 0.4023, 0.5967, 0.4023, 0.6318, 0.4062, 0.6455, 0.4053, 0.6484,
  0.4111, 0.6641, 0.4219, 0.6797, 0.4355, 0.6904, 0.4541, 0.6973, 0.4834, 0.6963, 0.498, 0.6885,
  0.5059, 0.6816, 0.5068, 0.6768, 0.4941, 0.665, 0.4902, 0.6553, 0.4873, 0.6396, 0.4873, 0.6104,
  0.4893, 0.5859, 0.4912, 0.585, 0.4922, 0.5781, 0.4912, 0.5732, 0.4941, 0.5684, 0.4941, 0.5586,
  0.4971, 0.5547, 0.502, 0.5312, 0.5039, 0.5303, 0.5098, 0.5078, 0.5186, 0.4912, 0.5186, 0.4863,
  0.5234, 0.4805, 0.5254, 0.4727, 0.5342, 0.459, 0.5342, 0.4551, 0.5459, 0.4404, 0.5439, 0.4375,
  0.5488, 0.4355, 0.5498, 0.4316, 0.5537, 0.4297, 0.5576, 0.4219, 0.5791, 0.4023, 0.582, 0.4023,
  0.5938, 0.3945, 0.6104, 0.3916, 0.6182, 0.3936, 0.626, 0.3994, 0.6279, 0.4111, 0.6221, 0.4375,
  0.6182, 0.4453, 0.6182, 0.4502, 0.5977, 0.4951, 0.5977, 0.499, 0.5918, 0.5078, 0.5889, 0.5195,
  0.583, 0.5293, 0.582, 0.5371, 0.5732, 0.5537, 0.5723, 0.5615, 0.5674, 0.5703, 0.5625, 0.5928,
  0.5605, 0.5947, 0.5547, 0.6289, 0.5537, 0.6514, 0.5566, 0.6748, 0.5635, 0.6953, 0.5664, 0.6973,
  0.5781, 0.7178, 0.5801, 0.7178, 0.5938, 0.7334, 0.6182, 0.748, 0.6426, 0.7549, 0.6777, 0.7568,
  0.7178, 0.7529, 0.7354, 0.749, 0.7373, 0.7461, 0.749, 0.7432, 0.7568, 0.7383, 0.7578, 0.7354,
  0.7715, 0.7246, 0.7793, 0.7148, 0.79, 0.6865, 0.7881, 0.6689, 0.7812, 0.6631, 0.7734, 0.6641,
  0.7686, 0.6709, 0.7656, 0.6719, 0.7617, 0.6807, 0.752, 0.6904, 0.7412, 0.6963, 0.7393, 0.6992,
  0.7314, 0.7031, 0.7266, 0.7031, 0.7236, 0.7061, 0.709, 0.708, 0.707, 0.71, 0.6953, 0.7109,
  0.6738, 0.7061, 0.665, 0.6992, 0.6553, 0.6807, 0.6543, 0.667, 0.6523, 0.6631, 0.6533, 0.6416,
  0.6562, 0.6318, 0.6514, 0.6045, 0.6523, 0.5742, 0.6543, 0.5732, 0.6553, 0.5654, 0.6641, 0.542,
  0.6807, 0.5176, 0.6846, 0.5156, 0.7002, 0.499, 0.6992, 0.4961, 0.7012, 0.4951, 0.7021, 0.4854,
  0.7041, 0.4844, 0.707, 0.4658, 0.7109, 0.4551, 0.7158, 0.4209, 0.7158, 0.3984, 0.7119, 0.375,
  0.7031, 0.3623, 0.7031, 0.3594, 0.6992, 0.3584, 0.6982, 0.3555, 0.6846, 0.3438, 0.6709, 0.3359,
  0.666, 0.3359, 0.6631, 0.333, 0.6533, 0.332, 0.6523, 0.3301, 0.6436, 0.3281, 0.6162, 0.3291,
  0.6133, 0.332, 0.6064, 0.332, 0.582, 0.3438, 0.5566, 0.3623, 0.5449, 0.375, 0.543, 0.375,
  0.5283, 0.3916, 0.5234, 0.4004, 0.5117, 0.4121, 0.5117, 0.4014, 0.5156, 0.3945, 0.5244, 0.3604,
  0.5264, 0.3271, 0.5244, 0.3262, 0.5234, 0.3125, 0.5205, 0.3066, 0.5078, 0.293, 0.4951, 0.2881,
  0.4766, 0.2871, 0.4746, 0.2891, 0.4648, 0.29, 0.4502, 0.2979, 0.4473, 0.3018, 0.4424, 0.3037,
  0.4395, 0.3086, 0.4326, 0.3125, 0.4219, 0.3262, 0.418, 0.3281, 0.417, 0.332, 0.4141, 0.333,
  0.4111, 0.3389, 0.4053, 0.3438, 0.4053, 0.3467, 0.3896, 0.3662, 0.3867, 0.374, 0.3799, 0.3809,
  0.3789, 0.377, 0.3838, 0.3584, 0.3857, 0.3311, 0.3828, 0.3125, 0.377, 0.2998, 0.3672, 0.2881,
  0.3535, 0.2783, 0.3477, 0.2764, 0.3447, 0.2773, 0.3438, 0.2754, 0.3193, 0.2744, 0.292, 0.2812,
  0.2559, 0.3008, 0.2266, 0.3252, 0.2227, 0.332, 0.2197, 0.333, 0.2139, 0.3418, 0.21, 0.3438,
  0.207, 0.3506, 0.2031, 0.3535, 0.2031, 0.3564,
  ];

  // Visible part of the leaf (x, y pairs, 0..1). The letter is painted on top of it.
  static const _leaf = <double>[
  0.7764, 0.4609, 0.7344, 0.4775, 0.708, 0.4951, 0.7041, 0.4951, 0.7031, 0.4912, 0.7002, 0.501,
  0.6797, 0.5225, 0.6641, 0.5469, 0.6572, 0.5645, 0.6533, 0.585, 0.6533, 0.6084, 0.6562, 0.627,
  0.6592, 0.6318, 0.6592, 0.6357, 0.6562, 0.6387, 0.6602, 0.6387, 0.6748, 0.6592, 0.6777, 0.6562,
  0.6816, 0.6562, 0.6816, 0.6641, 0.6836, 0.6621, 0.7109, 0.6602, 0.7334, 0.6523, 0.7559, 0.6357,
  0.7656, 0.624, 0.7764, 0.6055, 0.7832, 0.5869, 0.7871, 0.5674, 0.7871, 0.542, 0.7783, 0.4951,
  ];

  static Path _smooth(List<double> p, double s) {
    final n = p.length ~/ 2;
    Offset at(int i) => Offset(p[(i % n) * 2] * s, p[(i % n) * 2 + 1] * s);
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final path = Path();
    final first = mid(at(n - 1), at(0));
    path.moveTo(first.dx, first.dy);
    for (var i = 0; i < n; i++) {
      final c = at(i);
      final e = mid(c, at(i + 1));
      path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Rect.fromLTWH(0, 0, s, s);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(0.28 * s)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ).createShader(rect),
    );

    // soft ground shadow under the letter
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0.50 * s, 0.757 * s), width: 0.64 * s, height: 0.05 * s),
      Paint()
        ..color = const Color(0xFF5B3880).withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.014 * s),
    );

    canvas.drawCircle(Offset(0.725 * s, 0.249 * s), 0.065 * s, Paint()..color = dotColor);

    canvas.drawPath(_smooth(_leaf, s), Paint()..color = leafColor);
    final vein = Paint()
      ..color = veinColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.006 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0.673 * s, 0.683 * s), Offset(0.757 * s, 0.488 * s), vein);
    canvas.drawLine(Offset(0.708 * s, 0.586 * s), Offset(0.690 * s, 0.549 * s), vein);
    canvas.drawLine(Offset(0.717 * s, 0.581 * s), Offset(0.781 * s, 0.552 * s), vein);

    canvas.drawPath(_smooth(_letter, s), Paint()..color = letterColor);
  }

  @override
  bool shouldRepaint(LogoPainter oldDelegate) => false;
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 64, this.shadow = true});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MindPal logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: const Color(0xFF7B49A3).withValues(alpha: 0.32),
                    blurRadius: size * 0.3,
                    offset: Offset(0, size * 0.1),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(painter: const LogoPainter(), size: Size(size, size)),
      ),
    );
  }
}

/// Logo and the word "MindPal" side by side.
class MindPalWordmark extends StatelessWidget {
  const MindPalWordmark({super.key, this.logoSize = 36});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoMark(size: logoSize, shadow: false),
        const SizedBox(width: 10),
        Text(
          'MindPal',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: logoSize * 0.6),
        ),
      ],
    );
  }
}
