/// Thông tin vợ/chồng với trạng thái hôn nhân
class SpouseInfo {
  final String spouseId;
  bool isDivorced; // Đã ly thân

  SpouseInfo({
    required this.spouseId,
    this.isDivorced = false,
  });

  Map<String, dynamic> toJson() => {
    'spouseId': spouseId,
    'isDivorced': isDivorced,
  };

  factory SpouseInfo.fromJson(Map<String, dynamic> json) => SpouseInfo(
    spouseId: json['spouseId'] as String,
    isDivorced: json['isDivorced'] as bool? ?? false,
  );
}

class FamilyMember {
  final String id;
  String name;
  String gender; // 'male' or 'female'
  String? birthYear;
  String? deathYear;    // Ngày mất dương lịch (dd/MM/yyyy)
  String? deathDateLunar; // Ngày mất âm lịch (tự tính)
  String? info;
  String relationship; // Cách gọi: Cụ ông, Bà, Chú, Cô...
  List<SpouseInfo> spouses; // Hỗ trợ nhiều vợ/chồng
  List<String> childrenIds;
  String? parentId;
  int generation; // 0 = cụ, 1 = ông bà, 2 = cha mẹ, 3 = bản thân, 4 = con...
  int sortOrder; // Thứ tự sắp xếp trong hàng (cho edit mode reorder)
  double customXOffset; // Offset X tùy chỉnh khi kéo node tự do
  String familySide; // 'nội', 'ngoại', '' — transient, không lưu JSON

  FamilyMember({
    required this.id,
    this.name = '',
    this.gender = 'male',
    this.birthYear,
    this.deathYear,
    this.deathDateLunar,
    this.info,
    this.relationship = '',
    List<SpouseInfo>? spouses,
    List<String>? childrenIds,
    this.parentId,
    this.generation = 0,
    this.sortOrder = 0,
    this.customXOffset = 0.0,
  })  : spouses = spouses ?? [],
        childrenIds = childrenIds ?? [],
        familySide = '';

  /// Kiểm tra đã mất hay chưa
  bool get isDeceased => deathYear != null && deathYear!.isNotEmpty;

  /// Lấy vợ/chồng hiện tại (chưa ly thân)
  String? get currentSpouseId {
    for (final s in spouses) {
      if (!s.isDivorced) return s.spouseId;
    }
    return null;
  }

  /// Kiểm tra có vợ/chồng nào chưa ly thân không
  bool get hasActiveSpouse => spouses.any((s) => !s.isDivorced);

  /// Lấy tất cả spouse IDs
  List<String> get allSpouseIds => spouses.map((s) => s.spouseId).toList();

  /// Kiểm tra đã ly thân với spouse nào đó
  bool isDivorcedWith(String spouseId) {
    return spouses.any((s) => s.spouseId == spouseId && s.isDivorced);
  }

  /// Tính cách gọi dựa trên chênh lệch đời so với người đang xem
  /// [generationDiff] = selfGeneration - memberGeneration
  /// diff > 0 = thế hệ trên, diff < 0 = thế hệ dưới
  static String calculateRelationship({
    required int generationDiff,
    required String gender,
    bool isSpouse = false,
    bool isSelf = false,
  }) {
    if (isSelf) return 'Bản thân';

    if (isSpouse) {
      if (generationDiff >= 3) return gender == 'female' ? 'Cụ bà' : 'Cụ ông';
      if (generationDiff == 2) return gender == 'female' ? 'Bà' : 'Ông';
      if (generationDiff == 1) return gender == 'female' ? 'Mẹ' : 'Bố';
      if (generationDiff == 0) return gender == 'female' ? 'Vợ' : 'Chồng';
      if (generationDiff == -1) return gender == 'female' ? 'Con dâu' : 'Con rể';
      if (generationDiff == -2) return gender == 'female' ? 'Cháu dâu' : 'Cháu rể';
      return 'Dâu/Rể';
    }

    if (generationDiff >= 4) return gender == 'female' ? 'Kỵ bà' : 'Kỵ ông';
    if (generationDiff == 3) return gender == 'female' ? 'Cụ bà' : 'Cụ ông';
    if (generationDiff == 2) return gender == 'female' ? 'Bà' : 'Ông';
    if (generationDiff == 1) return gender == 'female' ? 'Mẹ' : 'Bố';
    if (generationDiff == 0) return gender == 'female' ? 'Chị/Em gái' : 'Anh/Em trai';
    if (generationDiff == -1) return gender == 'female' ? 'Con gái' : 'Con trai';
    if (generationDiff == -2) return 'Cháu';
    if (generationDiff == -3) return 'Chắt';
    if (generationDiff == -4) return 'Chút';
    return 'Hậu duệ';
  }

  String get displayName {
    if (name.isEmpty) return '...';
    return name;
  }

  String get displayRelationship {
    if (relationship.isEmpty) return '';
    return relationship;
  }

  String get fullDisplay {
    if (relationship.isEmpty) return displayName;
    return '$displayName ($relationship)';
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    'birthYear': birthYear,
    'deathYear': deathYear,
    'deathDateLunar': deathDateLunar,
    'info': info,
    'relationship': relationship,
    'spouses': spouses.map((s) => s.toJson()).toList(),
    'childrenIds': childrenIds,
    'parentId': parentId,
    'generation': generation,
    'sortOrder': sortOrder,
    'customXOffset': customXOffset,
  };

  /// Deserialize from JSON
  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    gender: json['gender'] as String? ?? 'male',
    birthYear: json['birthYear'] as String?,
    deathYear: json['deathYear'] as String?,
    deathDateLunar: json['deathDateLunar'] as String?,
    info: json['info'] as String?,
    relationship: json['relationship'] as String? ?? '',
    spouses: (json['spouses'] as List<dynamic>?)
        ?.map((s) => SpouseInfo.fromJson(s as Map<String, dynamic>))
        .toList(),
    childrenIds: (json['childrenIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    parentId: json['parentId'] as String?,
    generation: json['generation'] as int? ?? 0,
    sortOrder: json['sortOrder'] as int? ?? 0,
    customXOffset: (json['customXOffset'] as num?)?.toDouble() ?? 0.0,
  );
}
