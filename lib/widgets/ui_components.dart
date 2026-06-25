import 'package:flutter/material.dart';
import '../core/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const EmptyState({super.key, required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: textSecondary),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textSecondary)),
          const SizedBox(height: 6),
          Text(sub, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: textSecondary, height: 1.5)),
        ]),
      ),
    );
  }
}

class ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cl = 26.0, sw = 2.5, r = 6.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width; final h = size.height;
    // top-left
    canvas.drawLine(const Offset(0, cl), const Offset(0, r), paint);
    canvas.drawArc(const Rect.fromLTWH(0,0,r*2,r*2), 3.14, 1.57, false, paint);
    canvas.drawLine(const Offset(r, 0), const Offset(cl, 0), paint);
    // top-right
    canvas.drawLine(Offset(w-cl, 0), Offset(w-r, 0), paint);
    canvas.drawArc(Rect.fromLTWH(w-r*2,0,r*2,r*2), 4.71, 1.57, false, paint);
    canvas.drawLine(Offset(w, r), Offset(w, cl), paint);
    // bottom-right
    canvas.drawLine(Offset(w, h-cl), Offset(w, h-r), paint);
    canvas.drawArc(Rect.fromLTWH(w-r*2,h-r*2,r*2,r*2), 0, 1.57, false, paint);
    canvas.drawLine(Offset(w-r, h), Offset(w-cl, h), paint);
    // bottom-left
    canvas.drawLine(Offset(cl, h), Offset(r, h), paint);
    canvas.drawArc(Rect.fromLTWH(0,h-r*2,r*2,r*2), 1.57, 1.57, false, paint);
    canvas.drawLine(Offset(0, h-r), Offset(0, h-cl), paint); // Fixed compilation error from previous step
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
