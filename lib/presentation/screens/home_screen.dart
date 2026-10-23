import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/document_entity.dart';
import '../../service_locator.dart';
import '../../services/auth_service.dart';
import '../controllers/document_controller.dart';
import '../widgets/document_card.dart';
import '../widgets/responsive_content.dart';
import 'dashboard_screen.dart';
import 'document_detail_screen.dart';
import 'document_form_screen.dart';
import 'subject_list_screen.dart';
import 'trash_screen.dart';
import 'firebase_cloud_screen.dart';

/// Màn hình chính của ứng dụng Quản lý Tài liệu Học tập (CashewDoc)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DocumentController>(
      create: (_) => DocumentController(
        documentService: ServiceLocator.instance.documentService,
        subjectService: ServiceLocator.instance.subjectService,
        searchService: ServiceLocator.instance.searchService,
      ),
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  final TextEditingController _searchEditController = TextEditingController();
  int _selectedDestination = 0;

  DocumentController get _controller => context.read<DocumentController>();

  @override
  void dispose() {
    _searchEditController.dispose();
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
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(documentPk: doc.documentPk),
      ),
    );
    if (result == true) {
      _controller.refreshFilteredList();
    }
  }

  Future<void> _openDestination(int index) async {
    if (index == 0) return;

    final Widget screen = switch (index) {
      1 => const DashboardScreen(),
      2 => const SubjectListScreen(),
      3 => const TrashScreen(),
      4 => const FirebaseCloudScreen(),
      _ => const FirebaseCloudScreen(),
    };

    setState(() => _selectedDestination = index);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;

    setState(() => _selectedDestination = 0);
    if (index == 3) _controller.refreshFilteredList();
  }

  Future<void> _signOut() async {
    if (Firebase.apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase chưa được khởi tạo.')),
      );
      return;
    }
    await AuthService.instance.signOut();
  }

  void _confirmDelete(DocumentEntity doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài liệu'),
        content: Text(
          'Bạn có chắc muốn chuyển tài liệu "${doc.title}" vào thùng rác?',
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
    return Consumer<DocumentController>(
      builder: (context, _, _) {
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
                icon: const Icon(Icons.bar_chart, color: Colors.white),
                tooltip: 'Thống kê học tập',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Đăng xuất',
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _signOut,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                tooltip: 'Tùy chọn & Sắp xếp',
                onSelected: (val) async {
                  if (val == 'subjects') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubjectListScreen(),
                      ),
                    );
                  } else if (val == 'cloud') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FirebaseCloudScreen(),
                      ),
                    );
                  } else if (val == 'trash') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                    _controller.refreshFilteredList();
                  } else if (val == 'seed') {
                    await ServiceLocator.instance.database.seedSampleDocuments(
                      force: true,
                    );
                    await _controller.refreshFilteredList();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã nạp lại 11 tài liệu mẫu thành công!',
                          ),
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
                        Icon(
                          Icons.category_outlined,
                          size: 20,
                          color: AppConstants.primaryColor,
                        ),
                        SizedBox(width: 10),
                        Text('Quản lý môn học'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'trash',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          size: 20,
                          color: Colors.redAccent,
                        ),
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
                        Icon(
                          Icons.cloud_sync,
                          size: 20,
                          color: Color(0xFF1E88E5),
                        ),
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
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isWide)
                    NavigationRail(
                      selectedIndex: _selectedDestination,
                      extended: constraints.maxWidth >= 1400,
                      labelType: constraints.maxWidth >= 1400
                          ? null
                          : NavigationRailLabelType.all,
                      onDestinationSelected: _openDestination,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.folder_outlined),
                          selectedIcon: Icon(Icons.folder),
                          label: Text('Tài liệu'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.bar_chart_outlined),
                          selectedIcon: Icon(Icons.bar_chart),
                          label: Text('Thống kê'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.category_outlined),
                          selectedIcon: Icon(Icons.category),
                          label: Text('Môn học'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.delete_outline),
                          selectedIcon: Icon(Icons.delete),
                          label: Text('Thùng rác'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.cloud_outlined),
                          selectedIcon: Icon(Icons.cloud),
                          label: Text('Firebase'),
                        ),
                      ],
                    ),
                  if (isWide) const VerticalDivider(width: 1),
                  Expanded(
                    child: Center(
                      child: ResponsiveContent(
                        maxWidth: 1200,
                        child: Column(
                          children: [
                            // Thanh tìm kiếm (Search Bar với debounce)
                            Container(
                              color: AppConstants.primaryColor,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _searchEditController,
                                  onChanged: (val) =>
                                      _controller.setSearchQuery(val),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Tìm kiếm theo tên, môn, từ khóa...',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    border: InputBorder.none,
                                    icon: const Icon(
                                      Icons.search,
                                      color: AppConstants.primaryColor,
                                    ),
                                    suffixIcon:
                                        _searchEditController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 18,
                                            ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: [
                                  FilterChip(
                                    label: const Text('Tất cả'),
                                    selected:
                                        _controller.selectedDocumentType ==
                                        null,
                                    onSelected: (_) =>
                                        _controller.setSelectedType(null),
                                    backgroundColor: Colors.white,
                                    selectedColor: const Color(0xFFDBEAFE),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color:
                                          _controller.selectedDocumentType ==
                                              null
                                          ? AppConstants.primaryColor
                                          : Colors.black87,
                                      fontWeight:
                                          _controller.selectedDocumentType ==
                                              null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ...AppConstants.documentTypes.map((type) {
                                    final isSelected =
                                        _controller.selectedDocumentType ==
                                        type;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(
                                          type.split(' ')[0],
                                        ), // Lấy từ ngắn
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          _controller.setSelectedType(
                                            selected ? type : null,
                                          );
                                        },
                                        backgroundColor: Colors.white,
                                        selectedColor: const Color(0xFFDBEAFE),
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? AppConstants.primaryColor
                                              : Colors.black87,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                            if (_controller.availableTags.isNotEmpty)
                              SizedBox(
                                height: 48,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  children: [
                                    FilterChip(
                                      avatar: const Icon(Icons.tag, size: 16),
                                      label: const Text('Tất cả tag'),
                                      selected: _controller.selectedTag == null,
                                      onSelected: (_) =>
                                          _controller.setSelectedTag(null),
                                    ),
                                    const SizedBox(width: 8),
                                    ..._controller.availableTags.map((tag) {
                                      final isSelected =
                                          _controller.selectedTag == tag;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: FilterChip(
                                          avatar: const Icon(
                                            Icons.tag,
                                            size: 16,
                                          ),
                                          label: Text(tag),
                                          selected: isSelected,
                                          onSelected: (selected) =>
                                              _controller.setSelectedTag(
                                                selected ? tag : null,
                                              ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),

                            if (_controller.recommendations.isNotEmpty)
                              SizedBox(
                                height: 126,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        6,
                                      ),
                                      child: Text(
                                        'Gợi ý cho bạn',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        children: _controller.recommendations
                                            .map(
                                              (document) => SizedBox(
                                                width: 230,
                                                child: Card(
                                                  child: ListTile(
                                                    leading: const Icon(
                                                      Icons.auto_awesome,
                                                      color: AppConstants
                                                          .primaryColor,
                                                    ),
                                                    title: Text(
                                                      document.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    subtitle: Text(
                                                      document.tags,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    onTap: () =>
                                                        _openDocumentDetail(
                                                          document,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Danh sách tài liệu
                            Expanded(
                              child: _controller.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : _controller.documents.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.folder_open,
                                            size: 64,
                                            color: Colors.grey[400],
                                          ),
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
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppConstants.primaryColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () async {
                                              await ServiceLocator
                                                  .instance
                                                  .database
                                                  .seedSampleDocuments(
                                                    force: true,
                                                  );
                                              await _controller
                                                  .refreshFilteredList();
                                            },
                                            icon: const Icon(
                                              Icons.download,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Nạp ngay 11 tài liệu mẫu (Đề thi, Bài tập...)',
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columns =
                                            constraints.maxWidth >= 1000
                                            ? 3
                                            : constraints.maxWidth >= 640
                                            ? 2
                                            : 1;
                                        final itemCount =
                                            _controller.documents.length;
                                        DocumentCard buildCard(int index) {
                                          final doc =
                                              _controller.documents[index];
                                          return DocumentCard(
                                            document: doc,
                                            onTap: () =>
                                                _openDocumentDetail(doc),
                                            onToggleStatus: () => _controller
                                                .quickToggleStatus(doc),
                                            onDelete: () => _confirmDelete(doc),
                                          );
                                        }

                                        if (columns == 1) {
                                          return ListView.builder(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            itemCount: itemCount,
                                            itemBuilder: (_, index) =>
                                                buildCard(index),
                                          );
                                        }

                                        return GridView.builder(
                                          padding: const EdgeInsets.all(12),
                                          itemCount: itemCount,
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: columns,
                                                crossAxisSpacing: 8,
                                                mainAxisSpacing: 4,
                                                childAspectRatio: columns == 3
                                                    ? 1.55
                                                    : 1.4,
                                              ),
                                          itemBuilder: (_, index) =>
                                              buildCard(index),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddDocument,
            backgroundColor: AppConstants.primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Thêm tài liệu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
