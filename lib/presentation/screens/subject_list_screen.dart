import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/subject_entity.dart';
import '../../service_locator.dart';

/// Màn hình Quản lý danh sách Môn học
class SubjectListScreen extends StatefulWidget {
  const SubjectListScreen({super.key});

  @override
  State<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends State<SubjectListScreen> {
  List<SubjectEntity> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    final list = await ServiceLocator.instance.subjectService.getAllSubjects();
    setState(() {
      _subjects = list;
      _isLoading = false;
    });
  }

  void _showAddSubjectDialog([SubjectEntity? editSubject]) {
    final codeCtrl = TextEditingController(text: editSubject?.code ?? '');
    final nameCtrl = TextEditingController(text: editSubject?.name ?? '');
    final instCtrl = TextEditingController(text: editSubject?.instructor ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editSubject == null ? 'Thêm môn học mới' : 'Sửa môn học'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã môn học *',
                  hintText: 'VD: MOB101',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên môn học *',
                  hintText: 'VD: Phát triển ứng dụng di động',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instCtrl,
                decoration: const InputDecoration(
                  labelText: 'Giảng viên phụ trách',
                  hintText: 'VD: Thầy Trọng',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              await ServiceLocator.instance.subjectService.saveSubject(
                subjectPk: editSubject?.subjectPk,
                code: codeCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                instructor: instCtrl.text.trim(),
              );
              _loadSubjects();
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Danh mục Môn học'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final sub = _subjects[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withAlpha(40)),
                  ),
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFDBEAFE),
                      child: const Icon(Icons.school, color: AppConstants.primaryColor),
                    ),
                    title: Text(
                      '${sub.code} - ${sub.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: sub.instructor.isNotEmpty
                        ? Text('GV: ${sub.instructor}')
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showAddSubjectDialog(sub),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubjectDialog(),
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
