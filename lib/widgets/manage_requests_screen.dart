import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/borrow_share_models.dart';
import '../services/borrow_share_service.dart';

/// Màn hình quản lý các yêu cầu mượn tài liệu gửi đến cho chủ sở hữu
class ManageRequestsScreen extends StatefulWidget {
  const ManageRequestsScreen({
    super.key,
    this.borrowService,
    this.isEmbedded = false,
  });

  final BorrowShareService? borrowService;
  final bool isEmbedded;

  @override
  State<ManageRequestsScreen> createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final BorrowShareService _service;
  late final TabController _tabController;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final DateFormat _shortDate = DateFormat('dd/MM/yyyy');

  List<BorrowRequestModel> _allRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _processingRequestId;

  final List<String> _tabs = [
    'Tất cả',
    'Chờ duyệt',
    'Đã duyệt',
    'Từ chối',
    'Đã trả',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.borrowService ?? BorrowShareService();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Vui lòng đăng nhập để xem danh sách yêu cầu.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requests = await _service.getAllRequestsForOwner(user.uid);
      if (mounted) {
        setState(() {
          _allRequests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('BorrowShareServiceException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<BorrowRequestModel> get _filteredRequests {
    return switch (_tabController.index) {
      1 => _allRequests.where((r) => r.isPending).toList(),
      2 => _allRequests.where((r) => r.isApproved).toList(),
      3 => _allRequests.where((r) => r.isRejected).toList(),
      4 => _allRequests.where((r) => r.isReturned).toList(),
      _ => _allRequests,
    };
  }

  Future<void> _updateStatus(BorrowRequestModel req, String newStatus) async {
    final statusName = switch (newStatus) {
      'approved' => 'Chấp nhận',
      'rejected' => 'Từ chối',
      'returned' => 'Đánh dấu đã hoàn trả',
      _ => newStatus,
    };

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận $statusName'),
        content: Text(
          'Bạn có chắc muốn $statusName yêu cầu mượn tài liệu "${req.documentTitle ?? 'này'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'rejected' ? Colors.red : Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(statusName),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingRequestId = req.id);

    try {
      await _service.updateBorrowStatus(
        requestId: req.id,
        newStatus: newStatus,
      );

      // Cập nhật trạng thái tại chỗ trong bộ nhớ UI tức thời
      if (mounted) {
        setState(() {
          final index = _allRequests.indexWhere((r) => r.id == req.id);
          if (index != -1) {
            final old = _allRequests[index];
            _allRequests[index] = BorrowRequestModel(
              id: old.id,
              documentId: old.documentId,
              requesterUid: old.requesterUid,
              status: newStatus,
              borrowDate: old.borrowDate,
              dueDate: old.dueDate,
              notes: old.notes,
              createdAt: old.createdAt,
              documentTitle: old.documentTitle,
              storageRoom: old.storageRoom,
              shelfCode: old.shelfCode,
              boxNumber: old.boxNumber,
              address: old.address,
              latitude: old.latitude,
              longitude: old.longitude,
              ownerId: old.ownerId,
              requesterEmail: old.requesterEmail,
              requesterName: old.requesterName,
            );
          }
          _processingRequestId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật trạng thái: $statusName thành công!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingRequestId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _seedTestData() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _isLoading = true);
    try {
      await _service.seedTestBorrowData(currentUid: user?.uid);
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã nạp thành công bộ dữ liệu mẫu mượn tài liệu!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nạp dữ liệu: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allRequests.where((r) => r.isPending).length;

    final tabsList = [
      Tab(text: 'Tất cả (${_allRequests.length})'),
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chờ duyệt'),
            if (pendingCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const Tab(text: 'Đã duyệt'),
      const Tab(text: 'Từ chối'),
      const Tab(text: 'Đã trả'),
    ];

    if (widget.isEmbedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.indigo.shade800,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.indigo,
                    tabs: tabsList,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add_check_circle_outlined, color: Colors.indigo),
                  tooltip: 'Nạp dữ liệu mượn mẫu (Test)',
                  onPressed: _seedTestData,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.indigo),
                  tooltip: 'Làm mới',
                  onPressed: _loadRequests,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Duyệt Yêu Cầu Mượn Tài Liệu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            tooltip: 'Nạp dữ liệu mượn mẫu (Test)',
            onPressed: _seedTestData,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadRequests,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: tabsList,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.indigo),
            SizedBox(height: 12),
            Text('Đang tải danh sách yêu cầu...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 54, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRequests,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filteredRequests;
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Không có yêu cầu nào trong mục này',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kéo xuống để làm mới danh sách',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _seedTestData,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Nạp dữ liệu mượn mẫu để test'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final req = list[index];
          return _buildRequestCard(req);
        },
      ),
    );
  }

  Widget _buildRequestCard(BorrowRequestModel req) {
    final isProcessing = _processingRequestId == req.id;
    final statusEnum = req.statusEnum;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: req.isPending ? Colors.orange.shade200 : Colors.grey.shade200,
          width: req.isPending ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card: Tiêu đề + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.documentTitle ?? 'Tài liệu #${req.documentId.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              req.locationSummary,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Badge trạng thái
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusEnum.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusEnum.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusEnum.icon, size: 14, color: statusEnum.color),
                      const SizedBox(width: 4),
                      Text(
                        statusEnum.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusEnum.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Thông tin người mượn & ngày mượn/hạn trả
            Row(
              children: [
                Expanded(
                  child: _buildMetaItem(
                    icon: Icons.person_outline,
                    label: 'Người mượn',
                    value: req.requesterName ?? req.requesterEmail ?? req.requesterUid.substring(0, 10),
                  ),
                ),
                Expanded(
                  child: _buildMetaItem(
                    icon: Icons.event_available,
                    label: 'Hạn trả',
                    value: req.dueDate != null ? _shortDate.format(req.dueDate!) : 'Chưa đặt',
                    valueColor: (req.dueDate != null && req.dueDate!.isBefore(DateTime.now()) && !req.isReturned)
                        ? Colors.red
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildMetaItem(
                    icon: Icons.access_time,
                    label: 'Ngày yêu cầu',
                    value: _dateFormat.format(req.createdAt),
                  ),
                ),
              ],
            ),

            // Ghi chú từ người mượn
            if (req.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.format_quote_rounded, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        req.notes,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (req.isPending || req.isApproved) ...[
              const SizedBox(height: 14),
              if (isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (req.isPending) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                        onPressed: () => _updateStatus(req, 'rejected'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Từ chối'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _updateStatus(req, 'approved'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Chấp nhận'),
                      ),
                    ] else if (req.isApproved) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade800,
                          side: BorderSide(color: Colors.blueGrey.shade400),
                        ),
                        onPressed: () => _updateStatus(req, 'returned'),
                        icon: const Icon(Icons.assignment_turned_in, size: 16),
                        label: const Text('Xác nhận đã trả sách'),
                      ),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
