import 'package:flutter/material.dart';
import '../models/family_member.dart';

/// Rút ngắn chuỗi âm lịch dài thành dạng dd/MM/yyyy
String _extractShortLunar(String lunarStr) {
  final dayMatch = RegExp(r'Ngày (\d+)').firstMatch(lunarStr);
  final monthMatch = RegExp(r'tháng (\d+)').firstMatch(lunarStr);
  final yearMatch = RegExp(r'năm (\d+)').firstMatch(lunarStr);
  if (dayMatch != null && monthMatch != null && yearMatch != null) {
    return '${dayMatch.group(1)}/${monthMatch.group(1)}/${yearMatch.group(1)}';
  }
  return lunarStr;
}

class MemberNode extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback onTap;
  final VoidCallback? onViewRole;
  final double nodeWidth;
  final bool showDivorced;
  final bool isEditMode;
  final bool isViewingAs;

  const MemberNode({
    super.key,
    required this.member,
    required this.onTap,
    this.onViewRole,
    this.nodeWidth = 120,
    this.showDivorced = false,
    this.isEditMode = false,
    this.isViewingAs = false,
  });

  static const Color _editBorderColor = Color(0xFFE67E22);

  @override
  Widget build(BuildContext context) {
    final bool isFemale = member.gender == 'female';
    final bool isDeceased = member.isDeceased;

    // Tính tuổi
    String? ageText;
    if (member.birthYear != null && member.birthYear!.isNotEmpty) {
      try {
        final birthYear = int.parse(member.birthYear!.replaceAll(RegExp(r'[^0-9]'), ''));
        final currentYear = DateTime.now().year;
        if (birthYear > 0 && birthYear <= currentYear) {
          ageText = '${currentYear - birthYear} tuổi';
        }
      } catch (_) {}
    }

    final nodeContent = _buildNodeContent(isFemale, isDeceased, ageText);

    if (!isEditMode) {
      // VIEW MODE: tap → hiện thông tin chi tiết, long press → menu xem role
      return SizedBox(
        width: nodeWidth,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onViewRole != null ? () => _showViewOptions(context) : null,
          child: nodeContent,
        ),
      );
    }

    // EDIT MODE: viền cam overlay, KHÔNG thay đổi kích thước node
    // Nút "+" được render riêng trong FamilyTreeWidget để fix hit testing
    return SizedBox(
      width: nodeWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Orange border frame — tràn ra ngoài node
          Positioned(
            left: -10,
            right: -10,
            top: -10,
            bottom: -10,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _editBorderColor, width: 2.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Node content (kích thước = nodeWidth, giữ nguyên vị trí)
          GestureDetector(
            onTap: onTap,
            child: nodeContent,
          ),
        ],
      ),
    );
  }

  Widget _buildNodeContent(bool isFemale, bool isDeceased, String? ageText) {
    return Opacity(
      opacity: isDeceased ? 0.5 : 1.0,
      child: SizedBox(
        width: nodeWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isFemale
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF8C8DC), Color(0xFFE8A0B8)],
                          )
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF5D0A0), Color(0xFFE0A860)],
                          ),
                    border: Border.all(
                      color: isViewingAs
                          ? const Color(0xFFE67E22)
                          : (isDeceased
                              ? const Color(0xFF999080)
                              : const Color(0xFFBFA980)),
                      width: isViewingAs ? 3 : 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isViewingAs
                            ? const Color(0xFFE67E22).withValues(alpha: 0.3)
                            : Colors.brown.withValues(alpha: 0.15),
                        blurRadius: isViewingAs ? 10 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isFemale ? Icons.face_3 : Icons.face,
                    size: 36,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (isDeceased)
                  Positioned(
                    top: 0,
                    right: 10,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                if (isViewingAs)
                  Positioned(
                    bottom: 0,
                    right: 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE67E22),
                      ),
                      child: const Icon(Icons.person_pin, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Relationship (role) - shown above name like in reference
            if (member.relationship.isNotEmpty)
              Text(
                member.relationship,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDeceased
                      ? const Color(0xFF8A6B6B)
                      : const Color(0xFF888888),
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            // Name - bold
            Text(
              member.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDeceased
                    ? const Color(0xFF7A6B5A)
                    : const Color(0xFF4A3728),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Birth year badge + age
            if (member.birthYear != null && member.birthYear!.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE67E22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      member.birthYear!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (ageText != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      ageText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFE67E22),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            // Death indicator
            if (isDeceased && member.deathYear != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  children: [
                    Text(
                      '✝ ${member.deathYear}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF666666),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.deathDateLunar != null && member.deathDateLunar!.isNotEmpty)
                      Text(
                        'Âm: ${_extractShortLunar(member.deathDateLunar!)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF8B6F47),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            // Divorced label
            if (showDivorced)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  'Ly thân',
                  style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show view options: Xem role or Xem thông tin
  void _showViewOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF6F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF5F0E8),
                    border: Border.all(color: const Color(0xFFBFA980), width: 2),
                  ),
                  child: const Icon(Icons.person_outline, color: Color(0xFFBFA980), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A3728),
                        ),
                      ),
                      if (member.relationship.isNotEmpty)
                        Text(
                          member.relationship,
                          style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9B2335), fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFDDD0C0)),
            const SizedBox(height: 8),
            // View role
            ListTile(
              leading: const Icon(Icons.person_pin, color: Color(0xFFE67E22)),
              title: const Text('Xem role (góc nhìn người này)'),
              subtitle: const Text(
                'Cập nhật cách gọi mọi người từ góc nhìn người này',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onViewRole?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF8B6F47)),
              title: const Text('Xem thông tin chi tiết'),
              onTap: () {
                Navigator.of(ctx).pop();
                onTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút "+" tròn cam — public để FamilyTreeWidget dùng được
class PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;

  const PlusButton({super.key, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFE67E22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE67E22).withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
