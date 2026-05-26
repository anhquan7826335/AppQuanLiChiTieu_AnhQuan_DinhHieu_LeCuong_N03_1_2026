abstract class BaseEntity {
  int get id;

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType && other is BaseEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
