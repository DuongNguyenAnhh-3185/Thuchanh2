import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_document_service.dart';

/// Màn hình quản lý tài liệu đám mây Supabase (PostgreSQL Realtime)
class SupabaseCloudScreen extends StatefulWidget {
  const SupabaseCloudScreen({super.key});

  @override
  State<SupabaseCloudScreen> createState() => _SupabaseCloudScreenState();
}

class _SupabaseCloudScreenState extends State<SupabaseCloudScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();
  String _selectedType = AppConstants.documentTypes.first;
  String _selectedStatus = AppConstants.statusNotStarted;
  int _priority = AppConstants.priorityMedium;
  bool _isSubmitting = false;
  bool? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final ok = await SupabaseDocumentService.instance.testConnection();
    if (mounted) setState(() => _connectionStatus = ok);
  }

  Future<void> _submitDocument(User? user) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề tài liệu!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseDocumentService.instance.insertDocument(
        title: title,
        documentType: _selectedType,
        studyStatus: _selectedStatus,
        note: _noteController.text.trim(),
        tags: _tagsController.text.trim(),
        priority: _priority,
        ownerEmail: user?.email ?? 'anonymous',
        ownerName: user?.displayName ?? 'Người dùng',
      );
      _titleController.clear();
      _noteController.clear();
      _tagsController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu tài liệu lên Supabase thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi Supabase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteDocument(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa tài liệu "$title" khỏi Supabase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseDocumentService.instance.deleteDocument(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "$title" khỏi Supabase')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnap) {
        final user = authSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Supabase Cloud'),
            backgroundColor: const Color(0xFF1A9F5A), // Supabase green
            foregroundColor: Colors.white,
            actions: [
              // Trạng thái kết nối
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Tooltip(
                  message: _connectionStatus == null
                      ? 'Đang kiểm tra kết nối...'
                      : _connectionStatus!
                          ? 'Supabase: Đã kết nối'
                          : 'Supabase: Lỗi kết nối',
                  child: Icon(
                    _connectionStatus == null
                        ? Icons.cloud_queue
                        : _connectionStatus!
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                    color: _connectionStatus == null
                        ? Colors.white70
                        : _connectionStatus!
                            ? Colors.greenAccent
                            : Colors.redAccent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Kiểm tra lại kết nối',
                onPressed: _checkConnection,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card thông tin kết nối Supabase
                    _buildConnectionCard(),
                    const SizedBox(height: 16),
                    // Card thêm tài liệu mới
                    _buildAddDocumentCard(user),
                    const SizedBox(height: 16),
                    // Card danh sách realtime
                    _buildRealtimeListCard(user),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storage, color: Color(0xFF1A9F5A)),
                SizedBox(width: 8),
                Text(
                  'Thông tin kết nối Supabase',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            _infoRow(
              'URL',
              AppConstants.supabaseUrl,
              Icons.link,
            ),
            const SizedBox(height: 8),
            _infoRow(
              'Publishable Key',
              '${AppConstants.supabasePublishableKey.substring(0, 24)}...',
              Icons.vpn_key_outlined,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.circle, size: 12),
                const SizedBox(width: 8),
                const Text(
                  'Trạng thái: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                if (_connectionStatus == null)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    _connectionStatus!
                        ? '✅ Kết nối thành công'
                        : '❌ Không thể kết nối — Kiểm tra bảng cloud_documents',
                    style: TextStyle(
                      color: _connectionStatus! ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAddDocumentCard(User? user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF1A9F5A)),
                SizedBox(width: 8),
                Text(
                  'Thêm tài liệu mới lên Supabase',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề tài liệu *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Phân loại tài liệu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: AppConstants.documentTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trạng thái học tập',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: AppConstants.studyStatuses
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStatus = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Thẻ từ khóa (Tags)',
                hintText: 'VD: Chương 1, Ôn thi, Thực hành',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Độ ưu tiên:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Thấp')),
                    ButtonSegment(value: 2, label: Text('TB')),
                    ButtonSegment(value: 3, label: Text('Cao')),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A9F5A),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSubmitting ? null : () => _submitDocument(user),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isSubmitting
                      ? 'Đang lưu lên Supabase...'
                      : 'Lưu lên Supabase PostgreSQL',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeListCard(User? user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.view_list_outlined, color: Colors.blueGrey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tài liệu trên Supabase (Realtime Stream)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseDocumentService.instance.watchDocuments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Lỗi kết nối Supabase:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hãy tạo bảng cloud_documents trong Supabase.\nXem hướng dẫn SQL bên dưới.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Chưa có tài liệu nào trên Supabase.\nThêm tài liệu đầu tiên bằng form phía trên!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final id = doc['id']?.toString() ?? '';
                    final title = doc['title']?.toString() ?? 'Không tiêu đề';
                    final docType =
                        doc['document_type']?.toString() ?? 'Tài liệu';
                    final status =
                        doc['study_status']?.toString() ?? 'Chưa học';
                    final tags = doc['tags']?.toString() ?? '';
                    final ownerName =
                        doc['owner_name']?.toString() ?? 'Người dùng';
                    final createdAt = doc['created_at']?.toString() ?? '';
                    final dateStr = createdAt.isNotEmpty
                        ? createdAt.substring(0, 16).replaceAll('T', ' ')
                        : 'Vừa xong';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE8F5E9),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF1A9F5A),
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$docType · $status'),
                          Text(
                            'Chủ sở hữu: $ownerName · $dateStr',
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (tags.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              children: tags
                                  .split(',')
                                  .where((t) => t.trim().isNotEmpty)
                                  .map(
                                    (t) => Chip(
                                      label: Text(
                                        '#${t.trim()}',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor:
                                          const Color(0xFFE8F5E9),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: 'Xóa khỏi Supabase',
                        onPressed: () => _deleteDocument(id, title),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

