import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/family_provider.dart';
import '../widgets/family_tree_widget.dart';

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  late FamilyProvider _provider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _provider = FamilyProvider();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _initData();
  }

  Future<void> _initData() async {
    await _provider.init();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _exportBackup() async {
    final path = await _provider.exportToFile();
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu backup tại:\n$path'),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF5B8C5A),
          action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Nhập gia phả', style: TextStyle(color: Color(0xFF4A3728))),
          ],
        ),
        content: const Text(
          'Dữ liệu hiện tại sẽ bị thay thế bởi file backup.\nBạn có chắc chắn?',
          style: TextStyle(color: Color(0xFF4A3728)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF8B7355))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B6F47),
              foregroundColor: Colors.white,
            ),
            child: const Text('Nhập'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final success = await _provider.importFromFile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Nhập gia phả thành công!' : 'Nhập gia phả thất bại!'),
        backgroundColor: success ? const Color(0xFF5B8C5A) : Colors.red,
      ),
    );
    if (success) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F0E8), Color(0xFFEDE5D8), Color(0xFFE8DFD0)],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            CustomPaint(
              size: Size.infinite,
              painter: _BackgroundPatternPainter(),
            ),
            // Family tree
            Positioned.fill(
              child: SafeArea(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF8B6F47)),
                      )
                    : FamilyTreeWidget(
                        provider: _provider,
                        onUpdate: _refresh,
                      ),
              ),
            ),
            // Top-right: View/Edit toggle + menu
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Column(
                children: [
                  // View mode button
                  _ModeButton(
                    icon: Icons.visibility,
                    isActive: !_provider.isEditMode,
                    tooltip: 'Chế độ xem',
                    onTap: () {
                      _provider.setEditMode(false);
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 6),
                  // Edit mode button
                  _ModeButton(
                    icon: Icons.edit,
                    isActive: _provider.isEditMode,
                    tooltip: 'Chế độ sửa',
                    onTap: () {
                      _provider.setEditMode(true);
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Viewing perspective indicator
                  if (_provider.viewingAsId != 'self')
                    GestureDetector(
                      onTap: () {
                        _provider.resetViewingAs();
                        _refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9B2335).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_pin, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              _provider.getMember(_provider.viewingAsId)?.displayName ?? '...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.close, size: 12, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Export button
                  _SmallActionButton(
                    icon: Icons.upload_file,
                    color: const Color(0xFF5B8C5A),
                    onTap: _exportBackup,
                    tooltip: 'Xuất backup',
                  ),
                  const SizedBox(height: 6),
                  // Import button
                  _SmallActionButton(
                    icon: Icons.download,
                    color: const Color(0xFF4A7AB5),
                    onTap: _importBackup,
                    tooltip: 'Nhập backup',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFE67E22)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isActive
                  ? const Color(0xFFE67E22)
                  : const Color(0xFFDDD0C0),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isActive ? Colors.white : const Color(0xFF8B6F47),
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _SmallActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// Vẽ hoa văn nền trang trí
class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFA980).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFFBFA980).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (double y = -20; y < size.height + 100; y += 180) {
      for (double x = -20; x < size.width + 100; x += 180) {
        _drawLeafPattern(canvas, Offset(x, y), paint, strokePaint);
      }
    }
  }

  void _drawLeafPattern(Canvas canvas, Offset center, Paint fillPaint, Paint strokePaint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - 25);
    path.quadraticBezierTo(center.dx + 15, center.dy - 15, center.dx, center.dy);
    path.quadraticBezierTo(center.dx - 15, center.dy - 15, center.dx, center.dy - 25);
    path.moveTo(center.dx + 25, center.dy);
    path.quadraticBezierTo(center.dx + 15, center.dy + 15, center.dx, center.dy);
    path.quadraticBezierTo(center.dx + 15, center.dy - 15, center.dx + 25, center.dy);
    path.moveTo(center.dx, center.dy + 25);
    path.quadraticBezierTo(center.dx - 15, center.dy + 15, center.dx, center.dy);
    path.quadraticBezierTo(center.dx + 15, center.dy + 15, center.dx, center.dy + 25);
    path.moveTo(center.dx - 25, center.dy);
    path.quadraticBezierTo(center.dx - 15, center.dy - 15, center.dx, center.dy);
    path.quadraticBezierTo(center.dx - 15, center.dy + 15, center.dx - 25, center.dy);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final smallPath = Path();
    const s = 15.0;
    smallPath.moveTo(center.dx + s, center.dy - s);
    smallPath.quadraticBezierTo(center.dx + s * 0.7, center.dy - s * 0.3, center.dx, center.dy);
    smallPath.quadraticBezierTo(center.dx + s * 0.3, center.dy - s * 0.7, center.dx + s, center.dy - s);
    smallPath.moveTo(center.dx - s, center.dy - s);
    smallPath.quadraticBezierTo(center.dx - s * 0.7, center.dy - s * 0.3, center.dx, center.dy);
    smallPath.quadraticBezierTo(center.dx - s * 0.3, center.dy - s * 0.7, center.dx - s, center.dy - s);
    smallPath.moveTo(center.dx + s, center.dy + s);
    smallPath.quadraticBezierTo(center.dx + s * 0.7, center.dy + s * 0.3, center.dx, center.dy);
    smallPath.quadraticBezierTo(center.dx + s * 0.3, center.dy + s * 0.7, center.dx + s, center.dy + s);
    smallPath.moveTo(center.dx - s, center.dy + s);
    smallPath.quadraticBezierTo(center.dx - s * 0.7, center.dy + s * 0.3, center.dx, center.dy);
    smallPath.quadraticBezierTo(center.dx - s * 0.3, center.dy + s * 0.7, center.dx - s, center.dy + s);
    canvas.drawPath(smallPath, fillPaint);
    canvas.drawPath(smallPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
