class Student {
  final int? id;
  final String indexNo;
  final String fullName;
  final String programme;
  final int level;

  const Student({
    this.id,
    required this.indexNo,
    required this.fullName,
    required this.programme,
    required this.level,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'indexNo': indexNo,
        'fullName': fullName,
        'programme': programme,
        'level': level,
      };

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        id: m['id'] as int?,
        indexNo: m['indexNo'] as String,
        fullName: m['fullName'] as String,
        programme: m['programme'] as String,
        level: m['level'] as int,
      );
}
