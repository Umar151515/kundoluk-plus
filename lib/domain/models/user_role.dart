enum UserRole { student, teacher, parent, admin, unknown }

extension UserRoleX on UserRole {
  static UserRole fromApiValue(String? rawRole) {
    final normalized = (rawRole ?? '').trim().toLowerCase();

    switch (normalized) {
      case 'student':
      case 'pupil':
      case 'ученик':
        return UserRole.student;
      case 'teacher':
      case 'учитель':
        return UserRole.teacher;
      case 'parent':
      case 'родитель':
        return UserRole.parent;
      case 'admin':
      case 'administrator':
      case 'администратор':
        return UserRole.admin;
      default:
        return UserRole.unknown;
    }
  }
}
