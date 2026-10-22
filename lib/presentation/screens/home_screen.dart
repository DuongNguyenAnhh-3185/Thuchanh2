import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/document_entity.dart';
import '../../service_locator.dart';
import '../controllers/document_controller.dart';
import '../widgets/document_card.dart';
import 'dashboard_screen.dart';
import 'document_detail_screen.dart';
import 'document_form_screen.dart';
import 'subject_list_screen.dart';
import 'trash_screen.dart';

/// Màn hình chính của ứng dụng Quản lý Tài liệu Học tập (CashewDoc)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DocumentController _controller;
  final TextEditingController _searchEditController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = DocumentController(
      documentService: ServiceLocator.instance.documentService,
      subjectService: ServiceLocator.instance.subjectService,
      searchService: ServiceLocator.instance.searchService,
    );
  }

  @override
  void dispose() {
    _searchEditController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openAddDocument() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DocumentFormScreen()),
    );
    if (result == true) {
      _controller.refreshFilteredList();
    }
  }

  void _openDocumentDetail(DocumentEntity doc) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentPk: doc.documentPk)),
    );
    if (result == true) {
      _controller.refreshFilteredList();
    }
  }

  void _confirmDelete(DocumentEntity doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài liệu'),
        content: Text('Bạn có chắc muốn chuyển tài liệu "${doc.title}" vào thùng rác?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _controller.softDelete(doc.documentPk);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa "${doc.title}"'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: AppConstants.primaryColor,
            title: const Text(
              'CashewDoc',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.cloud_sync, color: Colors.white),
                tooltip: 'Mở tài liệu Cloud trên Supabase',
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/'),
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white),
                tooltip: 'Thống kê học tập',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                tooltip: 'Tùy chọn & Sắp xếp',
                onSelected: (val) async {
                  if (val == 'subjects') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubjectListScreen()),
                    );
                  } else if (val == 'cloud') {
                    Navigator.pushReplacementNamed(context, '/');
                  } else if (val == 'trash') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                    _controller.refreshFilteredList();
                  } else if (val == 'seed') {
                    await ServiceLocator.instance.database.seedSampleDocuments(force: true);
                    await _controller.refreshFilteredList();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã nạp lại 11 tài liệu mẫu thành công!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else if (val.startsWith('sort_')) {
                    _controller.setSortBy(val.replaceFirst('sort_', ''));
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'subjects',
                    child: Row(
                      children: [
                        Icon(Icons.category_outlined, size: 20, color: AppConstants.primaryColor),
                        SizedBox(width: 10),
                        Text('Quản lý môn học'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'trash',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Thùng rác'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'seed',
                    child: Row(
                      children: [
                        Icon(Icons.auto_stories, size: 20, color: Colors.teal),
                        SizedBox(width: 10),
                        Text('Nạp lại dữ liệu mẫu'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cloud',
                    child: Row(
                      children: [
                        Icon(Icons.cloud_sync, size: 20, color: Color(0xFF1E88E5)),
                        SizedBox(width: 10),
                        Text('Đám mây Firebase'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'sort_date_desc',
                    child: Text('Sắp xếp: Mới cập nhật'),
                  ),
                  const PopupMenuItem(
                    value: 'sort_date_asc',
                    child: Text('Sắp xếp: Cũ nhất'),
                  ),
                  const PopupMenuItem(
                    value: 'sort_title_asc',
                    child: Text('Sắp xếp: Tiêu đề A - Z'),
                  ),
                  const PopupMenuItem(
                    value: 'sort_priority_desc',
                    child: Text('Sắp xếp: Ưu tiên cao'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Thanh tìm kiếm (Search Bar với debounce)
              Container(
                color: AppConstants.primaryColor,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchEditController,
                    onChanged: (val) => _controller.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên, môn, từ khóa...',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: AppConstants.primaryColor),
                      suffixIcon: _searchEditController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchEditController.clear();
                                _controller.setSearchQuery('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // Dải Chip Lọc Loại tài liệu
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      label: const Text('Tất cả'),
                      selected: _controller.selectedDocumentType == null,
                      onSelected: (_) => _controller.setSelectedType(null),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFFDBEAFE),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _controller.selectedDocumentType == null
                            ? AppConstants.primaryColor
                            : Colors.black87,
                        fontWeight: _controller.selectedDocumentType == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...AppConstants.documentTypes.map((type) {
                      final isSelected = _controller.selectedDocumentType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type.split(' ')[0]), // Lấy từ ngắn
                          selected: isSelected,
                          onSelected: (selected) {
                            _controller.setSelectedType(selected ? type : null);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFFDBEAFE),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppConstants.primaryColor : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Danh sách tài liệu
              Expanded(
                child: _controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _controller.documents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'Chưa có tài liệu học tập nào',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Bấm dấu (+) phía dưới để thêm tài liệu mới',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await ServiceLocator.instance.database.seedSampleDocuments(force: true);
                                    await _controller.refreshFilteredList();
                                  },
                                  icon: const Icon(Icons.download, size: 18),
                                  label: const Text('Nạp ngay 11 tài liệu mẫu (Đề thi, Bài tập...)'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _controller.documents.length,
                            itemBuilder: (context, index) {
                              final doc = _controller.documents[index];
                              return DocumentCard(
                                document: doc,
                                onTap: () => _openDocumentDetail(doc),
                                onToggleStatus: () => _controller.quickToggleStatus(doc),
                                onDelete: () => _confirmDelete(doc),
                              );
                            },
                          ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddDocument,
            backgroundColor: AppConstants.primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Thêm tài liệu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
