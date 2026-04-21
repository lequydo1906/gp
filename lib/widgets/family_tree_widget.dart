import 'package:flutter/material.dart';
import '../models/family_member.dart';
import '../providers/family_provider.dart';
import 'member_node.dart';
import 'member_info_dialog.dart';

class FamilyTreeWidget extends StatefulWidget {
  final FamilyProvider provider;
  final VoidCallback onUpdate;

  const FamilyTreeWidget({
    super.key,
    required this.provider,
    required this.onUpdate,
  });

  @override
  State<FamilyTreeWidget> createState() => _FamilyTreeWidgetState();
}

class _FamilyTreeWidgetState extends State<FamilyTreeWidget> {
  // Layout constants — GIỐNG NHAU cho cả 2 chế độ
  static const double nodeWidth = 120.0;
  static const double nodeHeight = 150.0;
  static const double horizontalSpacing = 30.0;
  static const double verticalSpacing = 70.0;
  static const double coupleSpacing = 10.0;

  // Drag state (edit mode)
  String? _draggingId;
  Offset _dragDelta = Offset.zero;



  final TransformationController _transformController =
      TransformationController();

  FamilyProvider get provider => widget.provider;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (provider.members.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu'));
    }

    final Map<String, Offset> positions = {};

    final selfRoot = _findRootOf('self');
    if (selfRoot == null) {
      return const Center(child: Text('Chưa có dữ liệu'));
    }
    _layoutSubtree(selfRoot, positions, 0);
    _layoutAncestries(positions);
    _layoutOrphanDescendants(positions);
    _resolveOverlaps(positions);

    // Áp dụng custom offsets
    for (final id in positions.keys.toList()) {
      final customX = provider.getCustomXOffset(id);
      if (customX != 0) {
        positions[id] = Offset(positions[id]!.dx + customX, positions[id]!.dy);
      }
    }

    // Drag delta real-time
    if (_draggingId != null && positions.containsKey(_draggingId)) {
      positions[_draggingId!] = Offset(
        positions[_draggingId!]!.dx + _dragDelta.dx,
        positions[_draggingId!]!.dy,
      );
    }

    // Normalize
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final pos in positions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy > maxY) maxY = pos.dy;
    }
    const padding = 80.0;
    final offsetX = -minX + padding;
    final offsetY = -minY + padding;
    final totalWidth = maxX - minX + nodeWidth + padding * 2;
    final totalHeight = maxY - minY + nodeHeight + verticalSpacing + padding * 2;


    return InteractiveViewer(
      transformationController: _transformController,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(500),
      minScale: 0.01,
      maxScale: 100.0,
      panEnabled: _draggingId == null,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Connection lines
            CustomPaint(
              size: Size(totalWidth, totalHeight),
              painter: _TreeLinePainter(
                provider: provider,
                positions: positions,
                offset: Offset(offsetX, offsetY),
                nodeWidth: nodeWidth,
                nodeHeight: nodeHeight,
              ),
            ),
            // Member nodes
            ...positions.entries.map((entry) {
              final member = provider.getMember(entry.key);
              if (member == null) return const SizedBox();

              final nodeChild = MemberNode(
                member: member,
                isEditMode: provider.isEditMode,
                isViewingAs: provider.viewingAsId == member.id,
                onTap: () => _showMemberDialog(context, member),
                onViewRole: () {
                  provider.setViewingAs(member.id);
                  widget.onUpdate();
                },
                nodeWidth: nodeWidth,
                showDivorced: member.spouses.any((s) => s.isDivorced),
              );

              final isDragging = _draggingId == member.id;

              // EDIT MODE: free drag
              if (provider.isEditMode) {
                return Positioned(
                  left: entry.value.dx + offsetX,
                  top: entry.value.dy + offsetY,
                  child: GestureDetector(
                    onPanStart: (_) {
                      setState(() {
                        _draggingId = member.id;
                        _dragDelta = Offset.zero;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _dragDelta += Offset(details.delta.dx, 0);
                      });
                    },
                    onPanEnd: (_) {
                      final currentOffset = provider.getCustomXOffset(member.id);
                      provider.updateCustomXOffset(
                          member.id, currentOffset + _dragDelta.dx);
                      setState(() {
                        _draggingId = null;
                        _dragDelta = Offset.zero;
                      });
                    },
                    child: Opacity(
                      opacity: isDragging ? 0.8 : 1.0,
                      child: nodeChild,
                    ),
                  ),
                );
              }

              // VIEW MODE
              return Positioned(
                left: entry.value.dx + offsetX,
                top: entry.value.dy + offsetY,
                child: nodeChild,
              );
            }),
            // ======== PLUS BUTTONS (edit mode only) ========
            if (provider.isEditMode)
              ...positions.entries.expand((entry) {
                final member = provider.getMember(entry.key);
                if (member == null) return <Widget>[];
                final px = entry.value.dx + offsetX;
                final py = entry.value.dy + offsetY;
                const double btnSize = 28;
                const double btnHalf = btnSize / 2;
                const double avatarCenterY = 35; // avatar center from node top
                return [
                  // TOP "+" — thêm bố/mẹ
                  Positioned(
                    left: px + nodeWidth / 2 - btnHalf,
                    top: py - btnSize + 6,
                    child: PlusButton(
                      onTap: () {
                        provider.addBothParents(member.id);
                        widget.onUpdate();
                      },
                      tooltip: 'Thêm bố/mẹ',
                    ),
                  ),
                  // BOTTOM "+" — thêm con
                  Positioned(
                    left: px + nodeWidth / 2 - btnHalf,
                    top: py + nodeHeight - 6,
                    child: PlusButton(
                      onTap: () {
                        provider.addChild(member.id);
                        widget.onUpdate();
                      },
                      tooltip: 'Thêm con',
                    ),
                  ),
                  // LEFT "+" — thêm vợ/chồng hoặc anh/chị/em
                  Positioned(
                    left: px - btnSize + 6,
                    top: py + avatarCenterY - btnHalf,
                    child: PlusButton(
                      onTap: () => _showAddLeftRightDialog(context, member, isLeft: true),
                      tooltip: 'Thêm vợ/chồng hoặc anh/chị/em',
                    ),
                  ),
                  // RIGHT "+" — thêm vợ/chồng hoặc anh/chị/em
                  Positioned(
                    left: px + nodeWidth - 6,
                    top: py + avatarCenterY - btnHalf,
                    child: PlusButton(
                      onTap: () => _showAddLeftRightDialog(context, member, isLeft: false),
                      tooltip: 'Thêm vợ/chồng hoặc anh/chị/em',
                    ),
                  ),
                ];
              }),
          ],
        ),
      ),
    );
  }

  // ============ DIALOG ============

  void _showAddLeftRightDialog(BuildContext context, FamilyMember member,
      {required bool isLeft}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isLeft ? 'Thêm bên trái' : 'Thêm bên phải',
          style: const TextStyle(color: Color(0xFF4A3728), fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogOption(
              icon: Icons.favorite,
              label: 'Thêm vợ/chồng',
              color: const Color(0xFFBF6B7B),
              onTap: () {
                Navigator.of(ctx).pop();
                provider.addSpouse(member.id);
                widget.onUpdate();
              },
            ),
            const SizedBox(height: 8),
            _DialogOption(
              icon: Icons.people,
              label: 'Thêm anh/chị/em',
              color: member.parentId != null && provider.getMember(member.parentId!) != null
                  ? const Color(0xFF4A7AB5)
                  : const Color(0xFF999999),
              onTap: () {
                Navigator.of(ctx).pop();
                if (member.parentId == null || provider.getMember(member.parentId!) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hãy thêm bố/mẹ trước (nút + phía trên) rồi mới thêm anh/chị/em'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                provider.addSibling(member.id, insertAfter: !isLeft);
                widget.onUpdate();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============ HELPERS ============

  FamilyMember? _findRootOf(String memberId) {
    String? cur = memberId;
    while (cur != null) {
      final m = provider.getMember(cur);
      if (m == null) return null;
      if (m.parentId != null && provider.getMember(m.parentId!) != null) {
        cur = m.parentId;
      } else {
        return m;
      }
    }
    return null;
  }

  double _genY(int generation) => generation * (nodeHeight + verticalSpacing);

  // ============ LAYOUT ============

  double _layoutSubtree(
      FamilyMember member, Map<String, Offset> pos, double startX) {
    if (pos.containsKey(member.id)) return 0;

    final y = _genY(member.generation);
    final children = provider.getChildren(member.id);
    final spouses = provider
        .getSpouses(member.id)
        .where((s) => !pos.containsKey(s.id))
        .toList();

    double coupleWidth = nodeWidth;
    for (final sp in spouses) {
      coupleWidth += coupleSpacing + nodeWidth;
      if (sp.parentId != null && provider.getMember(sp.parentId!) != null) {
        final spSibCount = provider
            .getChildren(sp.parentId!)
            .where((c) => c.id != sp.id && !pos.containsKey(c.id))
            .length;
        coupleWidth += spSibCount * (nodeWidth + horizontalSpacing);
      }
    }

    final allChildren = <FamilyMember>[...children];
    for (final sp in spouses) {
      for (final c in provider.getChildren(sp.id)) {
        if (!allChildren.any((e) => e.id == c.id)) allChildren.add(c);
      }
    }

    allChildren.sort((a, b) {
      final aHas = provider.getSpouses(a.id).any(
          (s) => s.parentId != null && provider.getMember(s.parentId!) != null);
      final bHas = provider.getSpouses(b.id).any(
          (s) => s.parentId != null && provider.getMember(s.parentId!) != null);
      if (aHas && !bHas) return 1;
      if (!aHas && bHas) return -1;
      return a.sortOrder.compareTo(b.sortOrder);
    });

    if (allChildren.isEmpty) {
      _placeCoupleBlock(member, spouses, pos, startX, y);
      return coupleWidth;
    }

    double cx = startX;
    final childWidths = <double>[];
    for (final child in allChildren) {
      final cw = _layoutSubtree(child, pos, cx);
      if (cw > 0) {
        childWidths.add(cw);
        cx += cw + horizontalSpacing;
      }
    }
    double totalChildrenWidth = childWidths.fold(0.0, (a, b) => a + b) +
        (childWidths.length - 1) * horizontalSpacing;
    if (totalChildrenWidth < 0) totalChildrenWidth = 0;

    if (coupleWidth >= totalChildrenWidth) {
      _placeCoupleBlock(member, spouses, pos, startX, y);
      final childOffset = (coupleWidth - totalChildrenWidth) / 2;
      if (childOffset > 0) _shiftPositions(allChildren, pos, childOffset);
    } else {
      final coupleX = startX + (totalChildrenWidth - coupleWidth) / 2;
      _placeCoupleBlock(member, spouses, pos, coupleX, y);
    }

    return totalChildrenWidth > coupleWidth ? totalChildrenWidth : coupleWidth;
  }

  void _shiftPositions(
      List<FamilyMember> members, Map<String, Offset> pos, double dx) {
    for (final m in members) {
      if (pos.containsKey(m.id)) {
        pos[m.id] = Offset(pos[m.id]!.dx + dx, pos[m.id]!.dy);
      }
      for (final sp in provider.getSpouses(m.id)) {
        if (pos.containsKey(sp.id)) {
          pos[sp.id] = Offset(pos[sp.id]!.dx + dx, pos[sp.id]!.dy);
        }
      }
      final kids = provider.getChildren(m.id);
      if (kids.isNotEmpty) _shiftPositions(kids, pos, dx);
    }
  }

  void _placeCoupleBlock(FamilyMember member, List<FamilyMember> spouses,
      Map<String, Offset> pos, double startX, double y) {
    if (!pos.containsKey(member.id)) pos[member.id] = Offset(startX, y);
    double x = startX + nodeWidth + coupleSpacing;
    for (final sp in spouses) {
      if (!pos.containsKey(sp.id)) pos[sp.id] = Offset(x, y);
      x += nodeWidth;
      if (sp.parentId != null && provider.getMember(sp.parentId!) != null) {
        final siblings = provider
            .getChildren(sp.parentId!)
            .where((c) => c.id != sp.id && !pos.containsKey(c.id))
            .toList();
        for (final sib in siblings) {
          x += horizontalSpacing;
          pos[sib.id] = Offset(x, _genY(sib.generation));
          x += nodeWidth;
          for (final sibSp in provider.getSpouses(sib.id)) {
            if (!pos.containsKey(sibSp.id) && sibSp.parentId == null) {
              x += coupleSpacing;
              pos[sibSp.id] = Offset(x, _genY(sib.generation));
              x += nodeWidth;
            }
          }
        }
      }
      x += coupleSpacing;
    }
  }

  /// Sau khi _layoutAncestries đặt các bố/mẹ + spouse,
  /// tìm và layout con cái chưa được đặt (ví dụ: con của vợ mới ông ngoại)
  /// Đặt con ngay DƯỚI parent, không đẩy ra cuối hàng
  void _layoutOrphanDescendants(Map<String, Offset> pos) {
    bool changed = true;
    int safety = 20;
    while (changed && safety-- > 0) {
      changed = false;
      for (final id in pos.keys.toList()) {
        final m = provider.getMember(id);
        if (m == null) continue;

        // Thu thập tất cả con chưa được đặt (bao gồm con của các spouse)
        final unpositionedChildren = <FamilyMember>[];

        // Con trực tiếp
        for (final cId in m.childrenIds) {
          if (!pos.containsKey(cId)) {
            final c = provider.getMember(cId);
            if (c != null) unpositionedChildren.add(c);
          }
        }

        // Con của các spouse (shared children)
        for (final sp in provider.getSpouses(m.id)) {
          for (final cId in (provider.getMember(sp.id)?.childrenIds ?? <String>[])) {
            if (!pos.containsKey(cId) &&
                !unpositionedChildren.any((u) => u.id == cId)) {
              final c = provider.getMember(cId);
              if (c != null) unpositionedChildren.add(c);
            }
          }
        }

        if (unpositionedChildren.isEmpty) continue;

        // Đặt con ngay dưới parent — căn giữa với parent
        final parentPos = pos[id]!;
        final childY = _genY(unpositionedChildren.first.generation);

        // Tính tổng chiều rộng cần cho tất cả children
        final totalChildWidth = unpositionedChildren.length * nodeWidth +
            (unpositionedChildren.length - 1) * horizontalSpacing;

        // Bắt đầu từ giữa parent trừ nửa tổng chiều rộng
        double cx = parentPos.dx + nodeWidth / 2 - totalChildWidth / 2;

        for (final child in unpositionedChildren) {
          if (!pos.containsKey(child.id)) {
            pos[child.id] = Offset(cx, childY);
            cx += nodeWidth + horizontalSpacing;

            // Cũng đặt spouse của child nếu có
            for (final childSp in provider.getSpouses(child.id)) {
              if (!pos.containsKey(childSp.id)) {
                pos[childSp.id] = Offset(cx, childY);
                cx += nodeWidth + coupleSpacing;
              }
            }
          }
        }
        changed = true;
      }
    }
  }

  void _layoutAncestries(Map<String, Offset> pos) {
    bool changed = true;
    int safety = 30;
    while (changed && safety-- > 0) {
      changed = false;
      for (final id in pos.keys.toList()) {
        final m = provider.getMember(id);
        if (m == null || m.parentId == null) continue;
        if (pos.containsKey(m.parentId!)) continue;
        final parent = provider.getMember(m.parentId!);
        if (parent == null) continue;

        final positionedChildren = provider
            .getChildren(parent.id)
            .where((c) => pos.containsKey(c.id))
            .toList();
        if (positionedChildren.isEmpty) continue;

        final childCenters = positionedChildren
            .map((c) => pos[c.id]!.dx + nodeWidth / 2)
            .toList();
        final avgCenter =
            childCenters.reduce((a, b) => a + b) / childCenters.length;
        final parentY = _genY(parent.generation);
        double parentX = avgCenter - nodeWidth / 2;

        final nodesAtSameY = pos.entries
            .where((e) => (e.value.dy - parentY).abs() < 5)
            .map((e) => e.value.dx)
            .toList();
        nodesAtSameY.sort();

        // Chỉ đẩy khi thực sự trùng — giữ parentX gần ideal center nhất có thể
        for (final existingX in nodesAtSameY) {
          if (parentX >= existingX - nodeWidth - horizontalSpacing + 0.5 &&
              parentX <= existingX + nodeWidth + horizontalSpacing - 0.5) {
            // Overlap thực sự — đẩy ra khỏi vùng trùng
            parentX = existingX + nodeWidth + horizontalSpacing;
          }
        }

        pos[parent.id] = Offset(parentX, parentY);

        double spX = parentX + nodeWidth + coupleSpacing;
        for (final sp in provider.getSpouses(parent.id)) {
          if (!pos.containsKey(sp.id)) {
            for (final existingX in nodesAtSameY) {
              if ((spX - existingX).abs() < nodeWidth + horizontalSpacing / 2) {
                spX = existingX + nodeWidth + horizontalSpacing;
              }
            }
            pos[sp.id] = Offset(spX, parentY);
            spX += nodeWidth + coupleSpacing;
          }
        }
        changed = true;
      }
    }
  }

  /// Giải quyết overlap + cân bằng parent-children
  void _resolveOverlaps(Map<String, Offset> pos) {
    for (int pass = 0; pass < 10; pass++) {
      bool anyChange = false;

      // 1) Nhóm theo Y level
      final byY = <double, List<String>>{};
      for (final e in pos.entries) {
        final y = (e.value.dy / 10).round() * 10.0;
        byY.putIfAbsent(y, () => []).add(e.key);
      }

      // 2) Fix overlaps tại mỗi Y level
      for (final ids in byY.values) {
        if (ids.length < 2) continue;
        ids.sort((a, b) => pos[a]!.dx.compareTo(pos[b]!.dx));
        for (int i = 1; i < ids.length; i++) {
          final prevX = pos[ids[i - 1]]!.dx;
          final curX = pos[ids[i]]!.dx;
          final isCouple = _areSpouses(ids[i - 1], ids[i]);
          final minGap = nodeWidth + (isCouple ? coupleSpacing : horizontalSpacing);
          if (curX - prevX < minGap - 0.5) {
            final shift = minGap - (curX - prevX);
            for (int j = i; j < ids.length; j++) {
              pos[ids[j]] = Offset(pos[ids[j]]!.dx + shift, pos[ids[j]]!.dy);
            }
            anyChange = true;
          }
        }
      }

      // 3) Recenter: Cân parent ở giữa các children
      //    Chỉ recenter "primary parent" — bỏ qua spouse nodes
      //    (spouse nên giữ nguyên vị trí cạnh partner, không tự dịch)
      for (final id in pos.keys.toList()) {
        final m = provider.getMember(id);
        if (m == null || m.childrenIds.isEmpty) continue;

        // Bỏ qua nếu node này là spouse của ai đó đã có trong positions
        // (node spouse không nên tự recenter — partner sẽ kéo theo)
        bool isSecondarySpouse = false;
        for (final sp in m.spouses) {
          final partner = provider.getMember(sp.spouseId);
          if (partner != null && pos.containsKey(partner.id)) {
            // Nếu partner cũng có children, partner là primary → bỏ qua node này
            if (partner.childrenIds.isNotEmpty) {
              isSecondarySpouse = true;
              break;
            }
          }
        }
        if (isSecondarySpouse) continue;

        final childIds = m.childrenIds.where((c) => pos.containsKey(c)).toList();
        if (childIds.isEmpty) continue;

        // Collect ALL children (bao gồm children của spouse) để tính center chính xác
        final allChildIds = <String>{...childIds};
        for (final sp in provider.getSpouses(m.id)) {
          for (final cId in (provider.getMember(sp.id)?.childrenIds ?? <String>[])) {
            if (pos.containsKey(cId)) allChildIds.add(cId);
          }
        }

        final xs = allChildIds.map((c) => pos[c]!.dx).toList();
        final minX = xs.reduce((a, b) => a < b ? a : b);
        final maxX = xs.reduce((a, b) => a > b ? a : b);
        final childrenCenter = (minX + maxX + nodeWidth) / 2;

        // Couple width (member + các spouse)
        final spouses = provider.getSpouses(m.id)
            .where((s) => pos.containsKey(s.id)).toList();
        double coupleW = nodeWidth;
        for (final _ in spouses) {
          coupleW += coupleSpacing + nodeWidth;
        }

        final idealX = childrenCenter - coupleW / 2;
        final curX = pos[m.id]!.dx;
        if ((idealX - curX).abs() > 1) {
          pos[m.id] = Offset(idealX, pos[m.id]!.dy);
          double spX = idealX + nodeWidth + coupleSpacing;
          for (final sp in spouses) {
            pos[sp.id] = Offset(spX, pos[sp.id]!.dy);
            spX += nodeWidth + coupleSpacing;
          }
          anyChange = true;
        }
      }

      if (!anyChange) break;
    }
  }

  bool _areSpouses(String id1, String id2) {
    final m = provider.getMember(id1);
    return m?.spouses.any((s) => s.spouseId == id2) ?? false;
  }

  void _showMemberDialog(BuildContext context, FamilyMember member) {
    showDialog(
      context: context,
      builder: (ctx) => MemberInfoDialog(member: member, provider: provider),
    ).then((_) => widget.onUpdate());
  }
}

// ============ DIALOG OPTION ============

class _DialogOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DialogOption(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ============ CONNECTION LINES ============

class _TreeLinePainter extends CustomPainter {
  final FamilyProvider provider;
  final Map<String, Offset> positions;
  final Offset offset;
  final double nodeWidth;
  final double nodeHeight;

  _TreeLinePainter({
    required this.provider,
    required this.positions,
    required this.offset,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Bên nội (self's family) — brown
    final paintNoi = Paint()
      ..color = const Color(0xFFBFA980)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    // Bên ngoại (wife's family) — teal
    final paintNgoai = Paint()
      ..color = const Color(0xFF5B9EA6)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final divPaint = Paint()
      ..color = const Color(0xFFCC6666)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final drawnSpouse = <String>{};

    Paint linePaint(String? side) =>
        side == 'ngoại' ? paintNgoai : paintNoi;

    final double halfNode = nodeWidth / 2;
    const double avatarCenterY = 35;
    const double avatarRadius = 35;

    for (final entry in positions.entries) {
      final member = provider.getMember(entry.key);
      if (member == null) continue;
      final p = entry.value + offset;
      final cx = p.dx + halfNode;

      // Spouse lines
      for (final si in member.spouses) {
        final key = entry.key.compareTo(si.spouseId) < 0
            ? '${entry.key}_${si.spouseId}'
            : '${si.spouseId}_${entry.key}';
        if (drawnSpouse.contains(key) ||
            !positions.containsKey(si.spouseId)) {
          continue;
        }
        drawnSpouse.add(key);

        final sp = positions[si.spouseId]! + offset;
        final scx = sp.dx + halfNode;
        final lineY = p.dy + avatarCenterY;
        final usePaint = si.isDivorced ? divPaint : linePaint(member.familySide);

        final double leftEnd = cx + avatarRadius;
        final double rightStart = scx - avatarRadius;

        canvas.drawLine(
            Offset(leftEnd, lineY), Offset(rightStart, lineY), usePaint);

        if (si.isDivorced) {
          final mx = (leftEnd + rightStart) / 2;
          canvas.drawLine(Offset(mx - 6, lineY - 6),
              Offset(mx + 6, lineY + 6), divPaint);
          canvas.drawLine(Offset(mx + 6, lineY - 6),
              Offset(mx - 6, lineY + 6), divPaint);
        }
      }

      // Parent -> Children lines
      if (member.childrenIds.isNotEmpty) {
        double dropX = cx;
        // Dùng spouse bất kỳ (kể cả ly thân) để tính dropX — đường nối con không đổi khi ly thân
        final allSpouses = provider.getSpouses(member.id);
        final firstSpouse = allSpouses.isNotEmpty ? allSpouses.first : null;
        if (firstSpouse != null && positions.containsKey(firstSpouse.id)) {
          final spPos = positions[firstSpouse.id]! + offset;
          dropX = (cx + spPos.dx + halfNode) / 2;
        }

        final spouseLineY = p.dy + avatarCenterY;
        final bottomY = p.dy + nodeHeight;

        final childPositions = member.childrenIds
            .where((id) => positions.containsKey(id))
            .map((id) => positions[id]! + offset)
            .toList();
        if (childPositions.isEmpty) continue;

        final firstChildY = childPositions.first.dy;
        final barY = bottomY + (firstChildY - bottomY) / 2;

        // Nối liền từ spouse line → bar
        final parentPaint = linePaint(member.familySide);
        canvas.drawLine(
            Offset(dropX, spouseLineY), Offset(dropX, barY), parentPaint);

        final childCenters =
            childPositions.map((cp) => cp.dx + halfNode).toList();
        childCenters.add(dropX);
        final leftX = childCenters.reduce((a, b) => a < b ? a : b);
        final rightX = childCenters.reduce((a, b) => a > b ? a : b);
        canvas.drawLine(Offset(leftX, barY), Offset(rightX, barY), parentPaint);

        for (final cp in childPositions) {
          final childCx = cp.dx + halfNode;
          canvas.drawLine(
              Offset(childCx, barY), Offset(childCx, cp.dy), parentPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
