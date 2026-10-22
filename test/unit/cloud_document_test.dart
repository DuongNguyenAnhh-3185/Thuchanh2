import 'package:flutter_test/flutter_test.dart';
import 'package:study_doc_manager/domain/entities/cloud_document.dart';

void main() {
  final row = <String, dynamic>{
    'id': '11111111-1111-4111-8111-111111111111',
    'owner_id': 'alice',
    'title': 'Kiến trúc Cloud',
    'description': 'Firebase và Supabase',
    'file_name': 'cloud.pdf',
    'storage_path': 'documents/alice/doc/cloud.pdf',
    'file_size_bytes': 2048,
    'mime_type': 'application/pdf',
    'created_at': '2026-10-13T01:00:00.000Z',
    'updated_at': '2026-10-13T02:00:00.000Z',
  };

  test('chủ sở hữu có quyền sửa và chia sẻ', () {
    final document = CloudDocument.fromMap(row, currentUserId: 'alice');
    expect(document.accessLevel, CloudAccessLevel.owner);
    expect(document.isOwner, isTrue);
    expect(document.canEdit, isTrue);
    expect(document.fileSizeBytes, 2048);
  });

  test('editor được sửa nhưng không trở thành chủ sở hữu', () {
    final document = CloudDocument.fromMap(
      row,
      currentUserId: 'bob',
      grantedAccess: 'editor',
    );
    expect(document.accessLevel, CloudAccessLevel.editor);
    expect(document.isOwner, isFalse);
    expect(document.canEdit, isTrue);
  });

  test('viewer chỉ có quyền đọc', () {
    final document = CloudDocument.fromMap(
      row,
      currentUserId: 'carol',
      grantedAccess: 'viewer',
    );
    expect(document.accessLevel, CloudAccessLevel.viewer);
    expect(document.isOwner, isFalse);
    expect(document.canEdit, isFalse);
  });
}
