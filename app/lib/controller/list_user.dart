// Danh sách và CRUD cho User
import '../entities/user.dart';
import 'entity_repository.dart';

class UserList extends EntityRepository<User> {
  UserList([List<User>? initial]) : super(initial);

  // Update: cập nhật 1 bản ghi có id cụ thể
  // Trả về true nếu cập nhật thành công, false nếu không tìm thấy id
  bool updateById(int id, {String? name, String? email, String? password}) {
    final existing = readById(id);
    if (existing == null) return false;

    existing.name = name ?? existing.name;
    existing.email = email ?? existing.email;
    existing.password = password ?? existing.password;
    return true;
  }
}
