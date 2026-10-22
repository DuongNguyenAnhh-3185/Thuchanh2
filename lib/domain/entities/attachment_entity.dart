/// Thực thể Tệp đính kèm (Domain Entity)
class AttachmentEntity {
  final String attachmentPk; // UUID v4
  final String documentFk; // Khóa ngoại tới Document
  final String fileName; // Tên tệp
  final String fileExtension; // pdf, docx, pptx, zip, etc.
  final String localPath; // Đường dẫn lưu trữ cục bộ
  final int fileSizeBytes; // Dung lượng tệp
  final int dateTimeCreated;

  const AttachmentEntity({
    required this.attachmentPk,
    required this.documentFk,
    required this.fileName,
    required this.fileExtension,
    required this.localPath,
    required this.fileSizeBytes,
    required this.dateTimeCreated,
  });

  AttachmentEntity copyWith({
    String? attachmentPk,
    String? documentFk,
    String? fileName,
    String? fileExtension,
    String? localPath,
    int? fileSizeBytes,
    int? dateTimeCreated,
  }) {
    return AttachmentEntity(
      attachmentPk: attachmentPk ?? this.attachmentPk,
      documentFk: documentFk ?? this.documentFk,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      localPath: localPath ?? this.localPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      dateTimeCreated: dateTimeCreated ?? this.dateTimeCreated,
    );
  }
}
