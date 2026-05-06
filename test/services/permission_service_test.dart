import 'package:flutter_test/flutter_test.dart';
import 'package:sycebnl_accounting/services/permission_service.dart';

void main() {
  group('PermissionService helpers', () {
    test('returns true for numeric and boolean permissions', () {
      final permissions = {
        'lecture': 1,
        'ajout': true,
        'modification': 0,
        'suppression': false,
      };

      expect(PermissionService.canRead(permissions), isTrue);
      expect(PermissionService.canCreate(permissions), isTrue);
      expect(PermissionService.canEdit(permissions), isFalse);
      expect(PermissionService.canDelete(permissions), isFalse);
      expect(PermissionService.hasAnyPermission(permissions), isTrue);
    });

    test('returns false when no permission is granted', () {
      const permissions = {
        'lecture': 0,
        'ajout': 0,
        'modification': 0,
        'suppression': 0,
      };

      expect(PermissionService.hasAnyPermission(permissions), isFalse);
    });
  });
}
