import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_helper.dart';
import '../../domain/entities/document_entity.dart';
import '../../service_locator.dart';

/// Màn hình Thùng rác (Recycle Bin / Soft-Delete Manager)
/// Kế thừa cơ chế Cashew: xem danh sách tài liệu bị xóa mềm, hỗ trợ Khôi phục & Xóa vĩnh viễn
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<DocumentEntity> _deletedDocs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeletedDocs();
  }

  Future<void> _loadDeletedDocs() async {
    setState(() => _isLoading = true);
    final all = await ServiceLocator.instance.documentService.getAllDocuments(includeDeleted: true);
    setState(() {
      _deletedDocs = all.where((d) => d.isDeleted).toList();
      _isLoading = false;
    });
  }

  void _restore(DocumentEntity doc) async {
    await ServiceLocator.instance.documentService.restoreDocument(doc.documentPk);
    _loadDeletedDocs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã khôi phục thành công "${doc.title}"!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmPermanentDelete(DocumentEntity doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa vĩnh viễn?'),
        content: Text(
          'Tài liệu "${doc.title}" sẽ bị xóa hoàn toàn khỏi cơ sở dữ liệu và không thể khôi phục lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await ServiceLocator.instance.documentService.permanentlyDeleteDocument(doc.documentPk);
              _loadDeletedDocs();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa vĩnh viễn "${doc.title}"!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Xóa vĩnh viễn', style: TextStyle(color: Colors.white)),
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
        title: const Text('Thùng rác (Tài liệu đã xóa)'),
        backgroundColor: const Color(0xFF475569),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deletedDocs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Thùng rác trống',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Không có tài liệu nào bị xóa mềm',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _deletedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = _deletedDocs[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.withAlpha(40)),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    doc.subject?.code ?? 'MÔN HỌC',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  doc.documentType,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                const Spacer(),
                                Text(
                                  DateHelper.formatTimestamp(doc.dateTimeModified),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              doc.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _confirmPermanentDelete(doc),
                                  icon: const Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                                  label: const Text('Xóa hẳn', style: TextStyle(color: Colors.redAccent)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _restore(doc),
                                  icon: const Icon(Icons.restore, size: 18),
                                  label: const Text('Khôi phục'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
