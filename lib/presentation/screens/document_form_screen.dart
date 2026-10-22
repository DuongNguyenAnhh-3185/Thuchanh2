import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/uuid_helper.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../service_locator.dart';

/// Màn hình Thêm mới / Chỉnh sửa tài liệu học tập
class DocumentFormScreen extends StatefulWidget {
  final DocumentEntity? initialDocument;

  const DocumentFormScreen({super.key, this.initialDocument});

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagsController;

  String? _selectedSubjectFk;
  String _selectedType = AppConstants.documentTypes.first;
  String _selectedStatus = AppConstants.statusNotStarted;
  int _priority = AppConstants.priorityMedium;
  List<SubjectEntity> _subjects = [];
  List<AttachmentEntity> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final doc = widget.initialDocument;
    _titleController = TextEditingController(text: doc?.title ?? '');
    _noteController = TextEditingController(text: doc?.note ?? '');
    _tagsController = TextEditingController(text: doc?.tags ?? '');
    _selectedSubjectFk = doc?.subjectFk;
    if (doc != null) {
      _selectedType = doc.documentType;
      _selectedStatus = doc.studyStatus;
      _priority = doc.priority;
      _attachments = List.from(doc.attachments);
    }
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final list = await ServiceLocator.instance.subjectService.getAllSubjects();
    setState(() {
      _subjects = list;
      if (_selectedSubjectFk == null && _subjects.isNotEmpty) {
        _selectedSubjectFk = _subjects.first.subjectPk;
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final List<AttachmentEntity> newAttachments = [];
        for (final f in result.files) {
          final fileName = f.name;
          final ext = f.extension ?? (fileName.contains('.') ? fileName.split('.').last : 'dat');
          final size = f.size;
          newAttachments.add(
            AttachmentEntity(
              attachmentPk: UuidHelper.generate(),
              documentFk: widget.initialDocument?.documentPk ?? '',
              fileName: fileName,
              fileExtension: ext.toLowerCase(),
              localPath: f.path ?? '/storage/emulated/0/Download/$fileName',
              fileSizeBytes: size,
              dateTimeCreated: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
        setState(() {
          _attachments.addAll(newAttachments);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã đính kèm ${result.files.length} tệp thành công!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn tệp: $e')),
      );
    }
  }

  void _addCustomAttachmentDialog() {
    final nameCtrl = TextEditingController(text: 'De_cuong_on_tap_chi_tiet.pdf');
    final sizeCtrl = TextEditingController(text: '2.5');
    String selectedExt = 'pdf';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.note_add_outlined, color: AppConstants.primaryColor),
              SizedBox(width: 8),
              Text('Thêm tệp đính kèm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên tệp',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.insert_drive_file_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedExt,
                decoration: const InputDecoration(
                  labelText: 'Định dạng tệp',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pdf', child: Text('PDF (Tài liệu chuẩn)')),
                  DropdownMenuItem(value: 'docx', child: Text('DOCX (Tài liệu Word)')),
                  DropdownMenuItem(value: 'pptx', child: Text('PPTX (Slide bài giảng)')),
                  DropdownMenuItem(value: 'xlsx', child: Text('XLSX (Bảng tính Excel)')),
                  DropdownMenuItem(value: 'zip', child: Text('ZIP (Mã nguồn/Nén)')),
                  DropdownMenuItem(value: 'png', child: Text('PNG (Ảnh sơ đồ)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedExt = val;
                      final base = nameCtrl.text.split('.').first;
                      nameCtrl.text = '$base.$val';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sizeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Dung lượng ước tính (MB)',
                  border: OutlineInputBorder(),
                  suffixText: 'MB',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final mb = double.tryParse(sizeCtrl.text.trim()) ?? 1.0;
                  final bytes = (mb * 1024 * 1024).toInt();
                  setState(() {
                    _attachments.add(
                      AttachmentEntity(
                        attachmentPk: UuidHelper.generate(),
                        documentFk: widget.initialDocument?.documentPk ?? '',
                        fileName: name,
                        fileExtension: selectedExt,
                        localPath: '/storage/emulated/0/Download/$name',
                        fileSizeBytes: bytes,
                        dateTimeCreated: DateTime.now().millisecondsSinceEpoch,
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Thêm tệp', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentIcon(String ext) {
    IconData icon;
    Color color;
    switch (ext.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'zip':
      case 'rar':
        icon = Icons.folder_zip;
        color = Colors.purple;
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
        icon = Icons.image;
        color = Colors.teal;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjectFk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn môn học!')),
      );
      return;
    }

    try {
      await ServiceLocator.instance.documentService.saveDocument(
        documentPk: widget.initialDocument?.documentPk,
        subjectFk: _selectedSubjectFk!,
        title: _titleController.text.trim(),
        documentType: _selectedType,
        note: _noteController.text.trim(),
        studyStatus: _selectedStatus,
        priority: _priority,
        tags: _tagsController.text.trim(),
        attachments: _attachments,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialDocument != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa tài liệu' : 'Thêm tài liệu mới'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Lưu',
            onPressed: _onSave,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề tài liệu *',
                        hintText: 'VD: Bài giảng Chương 3, Đề thi giữa kỳ...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề tài liệu!';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Chọn môn học
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedSubjectFk,
                      decoration: const InputDecoration(
                        labelText: 'Môn học *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      items: _subjects.map((sub) {
                        return DropdownMenuItem(
                          value: sub.subjectPk,
                          child: Text(
                            '${sub.code} - ${sub.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSubjectFk = val),
                    ),
                    const SizedBox(height: 16),

                    // Loại tài liệu
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Phân loại tài liệu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: AppConstants.documentTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                    const SizedBox(height: 16),

                    // Trạng thái học tập
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái học tập',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: AppConstants.studyStatuses.map((st) {
                        return DropdownMenuItem(
                          value: st,
                          child: Text(st, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedStatus = val!),
                    ),
                    const SizedBox(height: 16),

                    // Thẻ tags
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Thẻ từ khóa (Tags)',
                        hintText: 'VD: Chương 1, Thực hành, Ôn thi',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ghi chú / Mô tả
                    TextFormField(
                      controller: _noteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả & Ghi chú học tập',
                        hintText: 'Nội dung tóm tắt, lưu ý cần ôn luyện...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.notes),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // KHỐI QUẢN LÝ TỆP ĐÍNH KÈM (ATTACHMENTS)
                    // ==========================================
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withAlpha(50)),
                      ),
                      color: const Color(0xFFF8FAFC),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.attach_file, color: AppConstants.primaryColor, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tệp đính kèm (${_attachments.length})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _pickFiles,
                                      icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                                      label: const Text('Chọn tệp', style: TextStyle(fontSize: 12, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: AppConstants.primaryColor, size: 22),
                                      tooltip: 'Tạo tệp mẫu nhanh',
                                      onPressed: _addCustomAttachmentDialog,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_attachments.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withAlpha(60), style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.upload_file, size: 36, color: Colors.grey[400]),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Chưa có tệp đính kèm nào',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Bấm "Chọn tệp" để tải từ máy hoặc "+" để thêm tệp nhanh',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _attachments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, idx) {
                                  final att = _attachments[idx];
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.withAlpha(40)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(8),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        _buildAttachmentIcon(att.fileExtension),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                att.fileName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withAlpha(20),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      att.fileExtension.toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    DateHelper.formatFileSize(att.fileSizeBytes),
                                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                          tooltip: 'Gỡ tệp',
                                          onPressed: () {
                                            setState(() {
                                              _attachments.removeAt(idx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nút lưu
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _onSave,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          isEditing ? 'LƯU THAY ĐỔI' : 'LƯU TÀI LIỆU',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
