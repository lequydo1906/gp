import 'package:flutter/material.dart';
import '../models/family_member.dart';
import '../providers/family_provider.dart';

class MemberInfoDialog extends StatefulWidget {
  final FamilyMember member;
  final FamilyProvider provider;

  const MemberInfoDialog({
    super.key,
    required this.member,
    required this.provider,
  });

  @override
  State<MemberInfoDialog> createState() => _MemberInfoDialogState();
}

class _MemberInfoDialogState extends State<MemberInfoDialog> {
  late TextEditingController _nameController;
  late TextEditingController _birthYearController;
  late TextEditingController _deathYearController;
  late TextEditingController _infoController;
  late String _gender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.name);
    _birthYearController = TextEditingController(text: widget.member.birthYear ?? '');
    _deathYearController = TextEditingController(text: widget.member.deathYear ?? '');
    _infoController = TextEditingController(text: widget.member.info ?? '');
    _gender = widget.member.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthYearController.dispose();
    _deathYearController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  void _save() {
    widget.provider.updateMember(
      widget.member.id,
      name: _nameController.text,
      gender: _gender,
      birthYear: _birthYearController.text.isEmpty ? null : _birthYearController.text,
      deathYear: _deathYearController.text.isEmpty ? null : _deathYearController.text,
      info: _infoController.text.isEmpty ? null : _infoController.text,
    );
    Navigator.of(context).pop();
  }

  void _toggleDivorce(String spouseId, bool isDivorced) {
    if (isDivorced) {
      widget.provider.reconcileSpouse(widget.member.id, spouseId);
    } else {
      widget.provider.divorceSpouse(widget.member.id, spouseId);
    }
    setState(() {});
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${widget.member.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              widget.provider.removeMember(widget.member.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showMemorialCard() {
    final m = widget.member;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF2C2420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✝', style: TextStyle(fontSize: 32, color: Color(0xFFD4AF37))),
              const SizedBox(height: 12),
              Text(
                m.displayName,
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold,
                  color: Color(0xFFF5F0E8), letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              if (m.relationship.isNotEmpty)
                Text(
                  '(${m.relationship})',
                  style: const TextStyle(fontSize: 14, color: Color(0xFFD4AF37), fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 16),
              Container(height: 1, width: 100, color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              if (m.birthYear != null && m.birthYear!.isNotEmpty)
                _memorialInfo('Sinh', m.birthYear!),
              if (m.deathYear != null && m.deathYear!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _memorialInfo('Mất (Dương)', m.deathYear!),
              ],
              if (m.deathDateLunar != null && m.deathDateLunar!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _memorialInfo('Mất (Âm)', m.deathDateLunar!),
              ],
              if (m.info != null && m.info!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(m.info!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFCCC0B0), fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 20),
              const Text('🪷', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng', style: TextStyle(color: Color(0xFFD4AF37))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memorialInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF999080), fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFFF5F0E8), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewingAsId = widget.provider.viewingAsId;
    final viewingMember = widget.provider.getMember(viewingAsId);
    final genDiff = (viewingMember?.generation ?? 3) - widget.member.generation;
    final relationship = FamilyMember.calculateRelationship(
      generationDiff: genDiff,
      gender: _gender,
      isSelf: widget.member.id == viewingAsId,
    );
    final isDeceased = widget.member.isDeceased;
    final spouses = widget.provider.getSpouses(widget.member.id);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFAF6F0),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDeceased ? const Color(0xFFD8D0C5) : const Color(0xFFF5F0E8),
                      border: Border.all(color: const Color(0xFFBFA980), width: 2),
                    ),
                    child: Icon(Icons.person_outline,
                      color: isDeceased ? const Color(0xFF999080) : const Color(0xFFBFA980), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thông tin thành viên',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3728))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B2335).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Cách gọi: $relationship',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF9B2335), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFDDD0C0)),
              const SizedBox(height: 12),
              // Gender selector
              Row(
                children: [
                  const Text('Giới tính:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A3728))),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Nam'),
                    selected: _gender == 'male',
                    selectedColor: const Color(0xFFBFA980),
                    onSelected: (_) => setState(() => _gender = 'male'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Nữ'),
                    selected: _gender == 'female',
                    selectedColor: const Color(0xFFF3E0F0),
                    onSelected: (_) => setState(() => _gender = 'female'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(controller: _nameController, label: 'Họ và tên', icon: Icons.person),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildTextField(
                    controller: _birthYearController, label: 'Năm sinh',
                    icon: Icons.cake, keyboardType: TextInputType.text,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(
                    controller: _deathYearController, label: 'Ngày mất (dd/MM/yyyy)',
                    icon: Icons.event, keyboardType: TextInputType.text,
                  )),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Nhập ngày mất dạng dd/MM/yyyy để tính âm lịch',
                style: TextStyle(fontSize: 10, color: Color(0xFF999080))),
              const SizedBox(height: 10),
              _buildTextField(controller: _infoController, label: 'Thông tin thêm', icon: Icons.info_outline, maxLines: 3),
              const SizedBox(height: 16),

              // Spouse list
              if (spouses.isNotEmpty) ...[
                const Divider(color: Color(0xFFDDD0C0)),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Vợ/Chồng:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A3728))),
                ),
                const SizedBox(height: 6),
                ...spouses.map((spouse) {
                  final isDivorced = widget.member.isDivorcedWith(spouse.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDivorced ? Colors.red.withValues(alpha: 0.05) : const Color(0xFFBF6B7B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDivorced ? Colors.red.withValues(alpha: 0.2) : const Color(0xFFBF6B7B).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(isDivorced ? Icons.heart_broken : Icons.favorite, size: 16,
                          color: isDivorced ? Colors.red.shade300 : const Color(0xFFBF6B7B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(spouse.displayName,
                            style: TextStyle(fontSize: 13,
                              color: isDivorced ? Colors.red.shade400 : const Color(0xFF4A3728),
                              fontWeight: FontWeight.w500)),
                        ),
                        Text(isDivorced ? 'Ly thân' : 'Chung sống',
                          style: TextStyle(fontSize: 10,
                            color: isDivorced ? Colors.red.shade400 : const Color(0xFF5B8C5A),
                            fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 24,
                          child: Switch(
                            value: isDivorced,
                            onChanged: (_) => _toggleDivorce(spouse.id, isDivorced),
                            activeThumbColor: Colors.red.shade400,
                            inactiveTrackColor: const Color(0xFF5B8C5A).withValues(alpha: 0.3),
                            inactiveThumbColor: const Color(0xFF5B8C5A),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 4),
              // Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (isDeceased)
                    _buildActionButton(
                      icon: Icons.article_outlined,
                      label: 'Danh thiếp',
                      color: const Color(0xFF6B5B4A),
                      onTap: _showMemorialCard,
                    ),
                  if (widget.member.id != 'self')
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Xóa',
                      color: Colors.red.shade400,
                      onTap: _delete,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Save/Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy', style: TextStyle(color: Color(0xFF8B7355))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B6F47),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFBFA980), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDD0C0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDD0C0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF8B6F47), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: const TextStyle(color: Color(0xFF8B7355), fontSize: 13),
      ),
      style: const TextStyle(color: Color(0xFF4A3728), fontSize: 14),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
