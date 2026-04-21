import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/family_member.dart';
import '../utils/lunar_calendar.dart';

class FamilyProvider extends ChangeNotifier {
  final Map<String, FamilyMember> _members = {};
  String? _rootId;
  String? _internalFilePath;
  String _viewingAsId = 'self'; // Mặc định xem từ góc nhìn bản thân
  bool _isEditMode = false;
  int _idCounter = 0; // Đảm bảo ID duy nhất khi bấm nhanh
  // Lưu offset X tùy chỉnh khi kéo node tự do trong edit mode
  final Map<String, double> _customXOffsets = {};

  Map<String, FamilyMember> get members => _members;
  String? get rootId => _rootId;
  FamilyMember? get root => _rootId != null ? _members[_rootId] : null;
  FamilyMember? getMember(String id) => _members[id];
  String get viewingAsId => _viewingAsId;
  bool get isEditMode => _isEditMode;
  Map<String, double> get customXOffsets => _customXOffsets;

  FamilyProvider();

  // ===================== INIT =====================

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _internalFilePath = '${dir.path}/giapha_data.json';
      final file = File(_internalFilePath!);
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        if (jsonStr.trim().isNotEmpty && _loadFromJsonStr(jsonStr) && _members.isNotEmpty) {
          recalculateAllRelationships();
          _loadCustomXOffsets();
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Init load error: $e');
    }
    _initDefaultSelf();
    notifyListeners();
    _autoSave();
  }

  void _initDefaultSelf() {
    _members.clear();
    final self = FamilyMember(
      id: 'self', name: '', gender: 'male',
      generation: 3, relationship: 'Bản thân',
    );
    _members['self'] = self;
    _rootId = 'self';
  }

  // ===================== VIEW/EDIT MODE =====================

  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  void setEditMode(bool value) {
    _isEditMode = value;
    notifyListeners();
  }

  // ===================== CUSTOM POSITION (FREE DRAG) =====================

  /// Cập nhật offset X tùy chỉnh cho 1 member (kéo tự do) — lưu vào model + auto-save
  void updateCustomXOffset(String memberId, double offsetX) {
    _customXOffsets[memberId] = offsetX;
    // Đồng bộ vào model để persist qua JSON
    final member = _members[memberId];
    if (member != null) {
      member.customXOffset = offsetX;
      _autoSave(); // Tự động lưu
    }
  }

  /// Lấy offset X tùy chỉnh (ưu tiên model, fallback map)
  double getCustomXOffset(String memberId) {
    // Ưu tiên từ map (realtime drag), rồi từ model (persisted)
    if (_customXOffsets.containsKey(memberId)) {
      return _customXOffsets[memberId]!;
    }
    return _members[memberId]?.customXOffset ?? 0.0;
  }

  /// Load custom offsets từ model vào map khi init
  void _loadCustomXOffsets() {
    _customXOffsets.clear();
    for (final m in _members.values) {
      if (m.customXOffset != 0.0) {
        _customXOffsets[m.id] = m.customXOffset;
      }
    }
  }

  // ===================== VIEWING PERSPECTIVE =====================

  /// Chuyển góc nhìn sang member khác — tất cả role cập nhật theo
  void setViewingAs(String memberId) {
    if (!_members.containsKey(memberId)) return;
    _viewingAsId = memberId;
    recalculateAllRelationships();
    notifyListeners();
  }

  /// Reset về góc nhìn bản thân
  void resetViewingAs() {
    _viewingAsId = 'self';
    recalculateAllRelationships();
    notifyListeners();
  }

  // ===================== RELATIONSHIPS =====================

  void recalculateAllRelationships() {
    final viewing = _members[_viewingAsId];
    if (viewing == null) return;

    // 1) Xác định bố/mẹ trực tiếp
    FamilyMember? father, mother;
    if (viewing.parentId != null) {
      final p = _members[viewing.parentId!];
      if (p != null) {
        if (p.gender == 'male') {
          father = p;
          for (final sp in p.spouses) {
            final s = _members[sp.spouseId];
            if (s != null) { mother = s; break; }
          }
        } else {
          mother = p;
          for (final sp in p.spouses) {
            final s = _members[sp.spouseId];
            if (s != null && s.gender == 'male') { father = s; break; }
          }
        }
      }
    }

    // 2) Thu thập dòng tộc bên nội/ngoại
    final paternalLine = <String>{};
    final maternalLine = <String>{};
    if (father != null) _collectLineage(father.id, paternalLine);
    if (mother != null) _collectLineage(mother.id, maternalLine);

    // 3) Tính spouse IDs
    final spouseIds = <String>{};
    for (final m in _members.values) {
      for (final s in m.spouses) spouseIds.add(s.spouseId);
    }

    // 4) Gán relationship cho từng member
    for (final member in _members.values) {
      member.relationship = _calcPathRelationship(
        viewing, member, father, mother,
        paternalLine, maternalLine, spouseIds,
      );
    }

    // 5) Đánh dấu bên nội/ngoại cho line coloring
    _markFamilySides();
  }

  // ===================== PATH-BASED RELATIONSHIP =====================

  String _calcPathRelationship(
    FamilyMember viewing, FamilyMember target,
    FamilyMember? father, FamilyMember? mother,
    Set<String> paternalLine, Set<String> maternalLine,
    Set<String> allSpouseIds,
  ) {
    if (target.id == viewing.id) return 'Bản thân';
    final genDiff = viewing.generation - target.generation;
    final isMale = target.gender == 'male';
    final isSpouse = allSpouseIds.contains(target.id);

    // Vợ/Chồng trực tiếp
    if (viewing.spouses.any((s) => s.spouseId == target.id)) {
      return isMale ? 'Chồng' : 'Vợ';
    }

    // ---- GEN +1: Bố/Mẹ, Chú/Bác/Cô, Cậu/Dì ----
    if (genDiff == 1) {
      if (target.id == father?.id) return 'Bố';
      if (target.id == mother?.id) return 'Mẹ';
      if (target.id == viewing.parentId) return isMale ? 'Bố' : 'Mẹ';
      // Spouse of parentId = other parent
      if (viewing.parentId != null) {
        final p = _members[viewing.parentId!];
        if (p != null && p.spouses.any((s) => s.spouseId == target.id)) {
          return isMale ? 'Bố' : 'Mẹ';
        }
      }
      if (!isSpouse) {
        // Anh/chị/em ruột của bố → Chú/Bác/Cô
        if (father != null && _shareParent(target.id, father.id)) {
          if (isMale) {
            return target.sortOrder < father.sortOrder ? 'Bác trai' : 'Chú';
          }
          return 'Cô';
        }
        // Anh/chị/em ruột của mẹ → Cậu/Dì
        if (mother != null && _shareParent(target.id, mother.id)) {
          return isMale ? 'Cậu' : 'Dì';
        }
      } else {
        // Spouse of uncle/aunt → Thím/Mợ/Dượng/Bác gái
        for (final sp in target.spouses) {
          final partner = _members[sp.spouseId];
          if (partner == null) continue;
          if (father != null && _shareParent(partner.id, father.id)) {
            if (!isMale) {
              return partner.sortOrder < father.sortOrder ? 'Bác gái' : 'Thím';
            }
            return 'Dượng';
          }
          if (mother != null && _shareParent(partner.id, mother.id)) {
            return isMale ? 'Dượng' : 'Mợ';
          }
        }
      }
      return isMale ? 'Bố' : 'Mẹ';
    }

    // ---- GEN +2: Ông/Bà nội/ngoại ----
    if (genDiff == 2) {
      if (paternalLine.contains(target.id) || _isSpouseOfAny(target.id, paternalLine)) {
        return isMale ? 'Ông nội' : 'Bà nội';
      }
      if (maternalLine.contains(target.id) || _isSpouseOfAny(target.id, maternalLine)) {
        return isMale ? 'Ông ngoại' : 'Bà ngoại';
      }
      return isMale ? 'Ông' : 'Bà';
    }

    // ---- GEN +3/+4: Cụ/Kỵ ----
    if (genDiff == 3) return isMale ? 'Cụ ông' : 'Cụ bà';
    if (genDiff >= 4) return isMale ? 'Kỵ ông' : 'Kỵ bà';

    // ---- GEN 0: Anh/Chị/Em ----
    if (genDiff == 0) {
      if (isSpouse) return isMale ? 'Anh/Em rể' : 'Chị/Em dâu';
      return isMale ? 'Anh/Em trai' : 'Chị/Em gái';
    }

    // ---- GEN -1: Con ----
    if (genDiff == -1) {
      if (isSpouse) return isMale ? 'Con rể' : 'Con dâu';
      return isMale ? 'Con trai' : 'Con gái';
    }

    // ---- GEN -2/-3/-4: Cháu/Chắt/Chút ----
    if (genDiff == -2) return 'Cháu';
    if (genDiff == -3) return 'Chắt';
    if (genDiff == -4) return 'Chút';
    if (genDiff < -4) return 'Hậu duệ';
    // ---- FALLBACK: Họ hàng theo đời ----
    if (genDiff > 0) {
      return 'Họ hàng bề trên ($genDiff đời)';
    }
    if (genDiff < 0) {
      return 'Họ hàng bề dưới (${-genDiff} đời)';
    }
    return 'Họ hàng';
  }

  bool _shareParent(String id1, String id2) {
    final m1 = _members[id1], m2 = _members[id2];
    if (m1 == null || m2 == null) return false;
    return m1.parentId != null && m1.parentId == m2.parentId;
  }

  bool _isSpouseOfAny(String targetId, Set<String> ids) {
    for (final id in ids) {
      final m = _members[id];
      if (m != null && m.spouses.any((s) => s.spouseId == targetId)) return true;
    }
    return false;
  }

  void _collectLineage(String id, Set<String> lineage) {
    String? cur = id;
    while (cur != null && _members.containsKey(cur)) {
      lineage.add(cur);
      cur = _members[cur]!.parentId;
    }
  }

  // ===================== FAMILY SIDE MARKING =====================

  void _markFamilySides() {
    for (final m in _members.values) m.familySide = '';
    final viewing = _members[_viewingAsId];
    if (viewing == null) return;

    // Self + self's entire tree → 'nội'
    _markSide(viewing.id, 'nội');

    // Spouse's tree → 'ngoại'
    for (final sp in viewing.spouses) {
      if (_members.containsKey(sp.spouseId)) {
        _markSideUp(sp.spouseId, 'ngoại');
      }
    }
  }

  void _markSide(String id, String side) {
    final m = _members[id];
    if (m == null || (m.familySide.isNotEmpty && m.familySide != side)) return;
    m.familySide = side;
    // Up
    if (m.parentId != null) {
      _markSide(m.parentId!, side);
      final parent = _members[m.parentId!];
      if (parent != null) {
        for (final sp in parent.spouses) {
          final s = _members[sp.spouseId];
          if (s != null && s.familySide.isEmpty) {
            s.familySide = side;
            if (s.parentId != null) _markSide(s.parentId!, side);
          }
        }
        for (final sibId in parent.childrenIds) {
          if (_members.containsKey(sibId) && _members[sibId]!.familySide.isEmpty) {
            _members[sibId]!.familySide = side;
          }
        }
      }
    }
    // Down
    for (final childId in m.childrenIds) {
      final c = _members[childId];
      if (c != null && c.familySide.isEmpty) {
        c.familySide = side;
      }
    }
  }

  void _markSideUp(String id, String side) {
    final m = _members[id];
    if (m == null || m.familySide == 'nội') return;
    m.familySide = side;
    if (m.parentId != null) {
      _markSideUp(m.parentId!, side);
      final parent = _members[m.parentId!];
      if (parent != null) {
        for (final sp in parent.spouses) {
          if (_members.containsKey(sp.spouseId) && _members[sp.spouseId]!.familySide.isEmpty) {
            _members[sp.spouseId]!.familySide = side;
          }
        }
        for (final sibId in parent.childrenIds) {
          if (_members.containsKey(sibId) && _members[sibId]!.familySide.isEmpty) {
            _members[sibId]!.familySide = side;
          }
        }
      }
    }
  }

  // ===================== AUTO-SAVE =====================

  Future<void> _autoSave() async {
    if (_internalFilePath == null) return;
    try {
      await File(_internalFilePath!).writeAsString(exportToJson());
    } catch (e) {
      debugPrint('Auto-save error: $e');
    }
  }

  // ===================== UPDATE =====================

  void updateMember(String id, {
    String? name, String? gender, String? birthYear,
    String? deathYear, String? info,
  }) {
    final member = _members[id];
    if (member == null) return;
    if (name != null) member.name = name;
    if (gender != null) {
      member.gender = gender;
      recalculateAllRelationships();
    }
    if (birthYear != null) member.birthYear = birthYear;
    if (deathYear != null) {
      member.deathYear = deathYear;
      member.deathDateLunar = deathYear.isNotEmpty ? _calcLunar(deathYear) : null;
    }
    if (info != null) member.info = info;
    notifyListeners();
    _autoSave();
  }

  String? _calcLunar(String dateStr) {
    try {
      final p = dateStr.split('/');
      if (p.length == 3) return LunarCalendar.formatLunar(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      if (p.length == 1) return LunarCalendar.formatLunar(1, 1, int.parse(p[0]));
    } catch (_) {}
    return null;
  }

  String _uniqueId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  // ===================== ADD CHILD =====================
  String addChild(String memberId) {
    final parent = _members[memberId];
    if (parent == null) return '';
    final childId = _uniqueId('member');
    final child = FamilyMember(
      id: childId, name: '', gender: 'male',
      generation: parent.generation + 1,
      relationship: '', parentId: memberId,
      sortOrder: parent.childrenIds.length,
    );
    _members[childId] = child;
    parent.childrenIds.add(childId);
    recalculateAllRelationships();
    notifyListeners();
    _autoSave();
    return childId;
  }

  // ===================== ADD SPOUSE =====================
  String addSpouse(String memberId) {
    final member = _members[memberId];
    if (member == null) return '';
    final spouseId = _uniqueId('spouse');
    final spouseGender = member.gender == 'male' ? 'female' : 'male';
    final spouse = FamilyMember(
      id: spouseId, name: '', gender: spouseGender,
      generation: member.generation, relationship: '',
      spouses: [SpouseInfo(spouseId: memberId, isDivorced: false)],
    );
    _members[spouseId] = spouse;
    member.spouses.add(SpouseInfo(spouseId: spouseId, isDivorced: false));
    recalculateAllRelationships();
    notifyListeners();
    _autoSave();
    return spouseId;
  }

  // ===================== ADD PARENT (BỐ + MẸ) =====================
  /// Thêm bố/mẹ cho member — nếu đã có bố → thêm mẹ (vợ/chồng cho bố)
  String addParent(String memberId) {
    final member = _members[memberId];
    if (member == null) return '';

    if (member.parentId != null && _members.containsKey(member.parentId)) {
      return addSpouse(member.parentId!);
    }

    final parentId = _uniqueId('parent');
    final parent = FamilyMember(
      id: parentId, name: '', gender: 'male',
      generation: member.generation - 1,
      relationship: '', childrenIds: [memberId],
    );
    _members[parentId] = parent;
    member.parentId = parentId;
    _updateRoot();
    recalculateAllRelationships();
    notifyListeners();
    _autoSave();
    return parentId;
  }

  /// Thêm cả bố lẫn mẹ cùng lúc
  List<String> addBothParents(String memberId) {
    final member = _members[memberId];
    if (member == null) return [];

    if (member.parentId != null && _members.containsKey(member.parentId)) {
      // Đã có bố → chỉ thêm mẹ nếu chưa có
      final parent = _members[member.parentId!]!;
      if (parent.spouses.isEmpty) {
        final momId = addSpouse(member.parentId!);
        return [member.parentId!, momId];
      }
      return [member.parentId!];
    }

    final fatherId = _uniqueId('parent');
    final motherId = _uniqueId('spouse');

    final father = FamilyMember(
      id: fatherId, name: '', gender: 'male',
      generation: member.generation - 1,
      relationship: '',
      childrenIds: [memberId],
      spouses: [SpouseInfo(spouseId: motherId, isDivorced: false)],
    );

    final mother = FamilyMember(
      id: motherId, name: '', gender: 'female',
      generation: member.generation - 1,
      relationship: '',
      spouses: [SpouseInfo(spouseId: fatherId, isDivorced: false)],
    );

    _members[fatherId] = father;
    _members[motherId] = mother;
    member.parentId = fatherId;
    _updateRoot();
    recalculateAllRelationships();
    notifyListeners();
    _autoSave();
    return [fatherId, motherId];
  }

  // ===================== ADD SIBLING =====================
  /// Thêm anh/chị/em ngay cạnh [memberId].
  /// [insertAfter] = true → chèn bên phải, false → chèn bên trái.
  /// Yêu cầu: node đã có bố/mẹ (dùng nút "+" phía trên để thêm bố/mẹ trước).
  String addSibling(String memberId, {bool insertAfter = true}) {
    final member = _members[memberId];
    if (member == null) return '';

    // Nếu chưa có bố/mẹ → không thể thêm anh/chị/em
    if (member.parentId == null || !_members.containsKey(member.parentId)) {
      return '';
    }

    final parentId = member.parentId!;
    final parent = _members[parentId]!;

    // Tìm vị trí của member trong danh sách children (theo sortOrder)
    final siblings = parent.childrenIds
        .map((id) => _members[id])
        .whereType<FamilyMember>()
        .toList();
    siblings.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Xác định vị trí chèn
    final memberIndex = siblings.indexWhere((s) => s.id == memberId);
    final insertIndex = insertAfter ? memberIndex + 1 : memberIndex;

    // Đẩy sortOrder của các sibling từ insertIndex trở đi lên 1
    for (int i = insertIndex; i < siblings.length; i++) {
      siblings[i].sortOrder = i + 1;
    }

    final siblingId = _uniqueId('member');
    final sibling = FamilyMember(
      id: siblingId, name: '', gender: 'male',
      generation: member.generation, relationship: '',
      parentId: parentId,
      sortOrder: insertIndex,
    );
    _members[siblingId] = sibling;
    parent.childrenIds.add(siblingId);
    recalculateAllRelationships();
    notifyListeners();
    _autoSave();
    return siblingId;
  }

  // ===================== REORDER IN ROW =====================
  /// Swap vị trí 2 member cùng hàng (siblings cùng bố)
  void swapSiblingOrder(String id1, String id2) {
    final m1 = _members[id1];
    final m2 = _members[id2];
    if (m1 == null || m2 == null) return;

    // Swap sortOrder
    final tmp = m1.sortOrder;
    m1.sortOrder = m2.sortOrder;
    m2.sortOrder = tmp;

    // Nếu cùng bố, swap trong childrenIds
    if (m1.parentId != null && m1.parentId == m2.parentId) {
      final parent = _members[m1.parentId!];
      if (parent != null) {
        final i1 = parent.childrenIds.indexOf(id1);
        final i2 = parent.childrenIds.indexOf(id2);
        if (i1 >= 0 && i2 >= 0) {
          parent.childrenIds[i1] = id2;
          parent.childrenIds[i2] = id1;
        }
      }
    }

    notifyListeners();
    _autoSave();
  }

  // ===================== ROOT =====================

  void _updateRoot() {
    String? cur = 'self';
    while (cur != null && _members.containsKey(cur)) {
      final m = _members[cur]!;
      if (m.parentId != null && _members.containsKey(m.parentId)) {
        cur = m.parentId;
      } else {
        break;
      }
    }
    _rootId = cur;
  }

  List<FamilyMember> getAllRoots() {
    final rootIds = <String>{};
    for (final m in _members.values) {
      var cur = m.id;
      while (true) {
        final member = _members[cur];
        if (member == null) break;
        if (member.parentId != null && _members.containsKey(member.parentId)) {
          cur = member.parentId!;
        } else {
          break;
        }
      }
      rootIds.add(cur);
    }
    final selfRoot = _findRootOf('self');
    final sorted = rootIds.toList();
    sorted.sort((a, b) {
      if (a == selfRoot) return -1;
      if (b == selfRoot) return 1;
      return 0;
    });
    return sorted.map((id) => _members[id]).whereType<FamilyMember>().toList();
  }

  String? _findRootOf(String memberId) {
    String? cur = memberId;
    while (cur != null && _members.containsKey(cur)) {
      final m = _members[cur]!;
      if (m.parentId != null && _members.containsKey(m.parentId)) {
        cur = m.parentId;
      } else {
        return cur;
      }
    }
    return cur;
  }

  // ===================== DIVORCE =====================

  void divorceSpouse(String memberId, String spouseId) {
    for (final s in _members[memberId]?.spouses ?? <SpouseInfo>[]) {
      if (s.spouseId == spouseId) s.isDivorced = true;
    }
    for (final s in _members[spouseId]?.spouses ?? <SpouseInfo>[]) {
      if (s.spouseId == memberId) s.isDivorced = true;
    }
    notifyListeners();
    _autoSave();
  }

  void reconcileSpouse(String memberId, String spouseId) {
    for (final s in _members[memberId]?.spouses ?? <SpouseInfo>[]) {
      if (s.spouseId == spouseId) s.isDivorced = false;
    }
    for (final s in _members[spouseId]?.spouses ?? <SpouseInfo>[]) {
      if (s.spouseId == memberId) s.isDivorced = false;
    }
    notifyListeners();
    _autoSave();
  }

  // ===================== DELETE =====================

  void removeMember(String id) {
    final member = _members[id];
    if (member == null) return;
    if (member.parentId != null) _members[member.parentId]?.childrenIds.remove(id);
    for (final s in member.spouses) {
      _members[s.spouseId]?.spouses.removeWhere((si) => si.spouseId == id);
    }
    // Không xóa con — chỉ bỏ liên kết parentId
    for (final childId in member.childrenIds) {
      final child = _members[childId];
      if (child != null) child.parentId = null;
    }
    _members.remove(id);
    _updateRoot();
    notifyListeners();
    _autoSave();
  }

  // ===================== GETTERS =====================

  List<FamilyMember> getChildren(String parentId) {
    final children = _members[parentId]?.childrenIds
        .map((id) => _members[id]).whereType<FamilyMember>().toList() ?? [];
    children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return children;
  }

  List<FamilyMember> getSpouses(String memberId) {
    return _members[memberId]?.spouses
        .map((s) => _members[s.spouseId]).whereType<FamilyMember>().toList() ?? [];
  }

  FamilyMember? getActiveSpouse(String memberId) {
    final member = _members[memberId];
    if (member == null) return null;
    for (final s in member.spouses) {
      if (!s.isDivorced && _members.containsKey(s.spouseId)) return _members[s.spouseId];
    }
    return null;
  }

  // ===================== JSON BACKUP =====================

  String exportToJson() {
    final data = {
      'rootId': _rootId,
      'members': _members.values.map((m) => m.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'version': 1,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  bool _loadFromJsonStr(String jsonStr) {
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final membersList = data['members'] as List<dynamic>;
      _members.clear();
      for (final mj in membersList) {
        final member = FamilyMember.fromJson(mj as Map<String, dynamic>);
        _members[member.id] = member;
      }
      _rootId = data['rootId'] as String?;
      return true;
    } catch (e) {
      debugPrint('Load JSON error: $e');
      return false;
    }
  }

  bool importFromJson(String jsonStr) {
    if (_loadFromJsonStr(jsonStr)) {
      recalculateAllRelationships();
      notifyListeners();
      _autoSave();
      return true;
    }
    return false;
  }

  Future<String?> exportToFile() async {
    try {
      final jsonStr = exportToJson();
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Chọn vị trí lưu backup gia phả',
        fileName: 'giapha_backup.json',
        type: FileType.custom, allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );
      if (result == null) return null;
      final file = File(result);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsString(jsonStr);
      }
      return result;
    } catch (e) {
      debugPrint('Export error: $e');
      try {
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/giapha_export_${DateTime.now().millisecondsSinceEpoch}.json');
        await f.writeAsString(exportToJson());
        return f.path;
      } catch (_) { return null; }
    }
  }

  Future<bool> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return false;
      final jsonStr = await File(result.files.single.path!).readAsString();
      return importFromJson(jsonStr);
    } catch (e) {
      debugPrint('Import error: $e');
      return false;
    }
  }
}
