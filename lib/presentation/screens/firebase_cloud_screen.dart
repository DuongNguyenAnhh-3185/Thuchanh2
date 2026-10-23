import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/cloud_document.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_workspace_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/borrow_request_dialog.dart';
import '../../widgets/document_location_dialog.dart';
import '../../widgets/documents_map_overview_widget.dart';
import '../../widgets/manage_requests_screen.dart';
import '../../widgets/recommended_documents_widget.dart';

/// Không gian tài liệu đa nền tảng: Firebase Auth/Storage + Supabase/RLS.
class FirebaseCloudScreen extends StatefulWidget {
  const FirebaseCloudScreen({super.key});

  @override
  State<FirebaseCloudScreen> createState() => _FirebaseCloudScreenState();
}

class _FirebaseCloudScreenState extends State<FirebaseCloudScreen> {
  final CloudWorkspaceService _service = CloudWorkspaceService();
  final TextEditingController _searchController = TextEditingController();
  late final StreamSubscription<User?> _authSubscription;

  List<CloudDocument> _documents = const [];
  Timer? _searchDebounce;
  String? _loadedUserId;
  String? _error;
  bool _loading = false;
  bool _busy = false;
  bool _signingIn = false;
  int _loadGeneration = 0;
  int _selectedTabIndex = 0; // 0: Tất cả, 1: Gợi ý cho bạn, 2: Yêu cầu mượn, 3: Bản đồ vị trí

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.instance.authStateChanges.listen(
      _handleAuthChanged,
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleAuthChanged(User? user) {
    if (!mounted) return;
    _loadGeneration++;
    _searchDebounce?.cancel();
    if (user == null) {
      setState(() {
        _loadedUserId = null;
        _documents = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    if (_loadedUserId == user.uid) return;
    _loadedUserId = user.uid;
    setState(() => _documents = const []);
    unawaited(_bootstrapCloud());
  }

  Future<void> _bootstrapCloud() async {
    if (!SupabaseService.isInitialized) {
      setState(() {
        _error = 'Supabase chưa được cấu hình bằng --dart-define.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.syncCurrentUser();
      await _loadDocuments();
    } catch (error) {
      if (mounted) setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDocuments() async {
    final generation = ++_loadGeneration;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final documents = await _service.getDocuments(
      query: _searchController.text,
    );
    if (mounted &&
        generation == _loadGeneration &&
        userId == FirebaseAuth.instance.currentUser?.uid) {
      setState(() {
        _documents = documents;
        _error = null;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_searchDocuments());
    });
  }

  Future<void> _searchDocuments() async {
    try {
      await _loadDocuments();
    } catch (error) {
      if (mounted) setState(() => _error = _messageOf(error));
    }
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null && mounted) {
        _showMessage('Bạn đã hủy đăng nhập Google.');
      }
    } catch (error) {
      if (mounted) _showMessage(_messageOf(error), isError: true);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _showUploadDialog() async {
    final request = await showDialog<_UploadRequest>(
      context: context,
      builder: (_) => const _UploadDocumentDialog(),
    );
    if (request == null) return;
    await _runAction(
      () async {
        await _service.uploadDocument(
          file: request.file,
          title: request.title,
          description: request.description,
          storageRoom: request.storageRoom,
          shelfCode: request.shelfCode,
          boxNumber: request.boxNumber,
          address: request.address,
          latitude: request.latitude,
          longitude: request.longitude,
        );
      },
      successMessage: 'Đã tải tệp lên Firebase và lưu vị trí lưu trữ trên Supabase.',
    );
  }

  Future<void> _showEditDialog(CloudDocument document) async {
    final result = await showDialog<_EditRequest>(
      context: context,
      builder: (_) => _EditDocumentDialog(document: document),
    );
    if (result == null) return;
    await _runAction(
      () => _service.updateDocument(
        documentId: document.id,
        title: result.title,
        description: result.description,
        storageRoom: result.storageRoom,
        shelfCode: result.shelfCode,
        boxNumber: result.boxNumber,
        address: result.address,
        latitude: result.latitude,
        longitude: result.longitude,
      ),
      successMessage: 'Đã cập nhật thông tin và vị trí tài liệu.',
    );
  }

  void _openLocationDialog(CloudDocument doc) {
    DocumentLocationDialog.show(
      context,
      document: doc,
      onSaveLocation: ({
        required String storageRoom,
        required String shelfCode,
        required String boxNumber,
        required String address,
        required double latitude,
        required double longitude,
      }) async {
        await _service.updateDocument(
          documentId: doc.id,
          title: doc.title,
          description: doc.description,
          storageRoom: storageRoom,
          shelfCode: shelfCode,
          boxNumber: boxNumber,
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
        await _loadDocuments();
      },
      onBorrow: () => BorrowRequestDialog.show(
        context,
        documentId: doc.id,
        documentTitle: doc.title,
        ownerId: doc.ownerId,
        storageRoom: doc.storageRoom,
        shelfCode: doc.shelfCode,
        boxNumber: doc.boxNumber,
        address: doc.address,
      ),
    );
  }

  Future<void> _assignDefaultLocations() async {
    final withoutCoords = _documents.where((d) =>
        d.latitude == null ||
        d.longitude == null ||
        d.latitude == 0.0 ||
        d.longitude == 0.0).toList();

    if (withoutCoords.isEmpty) {
      _showMessage('Tất cả tài liệu đã có tọa độ ghim trên bản đồ.');
      return;
    }

    setState(() => _busy = true);
    try {
      int idx = 0;
      for (final doc in withoutCoords) {
        // Tọa độ Hà Nội với độ lệch nhỏ để các marker hiển thị tách biệt đẹp mắt
        final offset = (idx % 6) * 0.0035;
        final lat = 21.0285 + ((idx % 2 == 0 ? 1 : -1) * offset);
        final lng = 105.8542 + ((idx % 3 == 0 ? 1 : -1) * offset);
        final room = doc.storageRoom?.isNotEmpty == true ? doc.storageRoom! : 'Phòng P.${101 + idx}';
        final shelf = doc.shelfCode?.isNotEmpty == true ? doc.shelfCode! : 'Kệ K.${(idx % 5) + 1}';
        final box = doc.boxNumber?.isNotEmpty == true ? doc.boxNumber! : 'Hộp ${(idx % 10) + 1}';

        await _service.updateDocument(
          documentId: doc.id,
          title: doc.title,
          description: doc.description,
          storageRoom: room,
          shelfCode: shelf,
          boxNumber: box,
          address: doc.address?.isNotEmpty == true ? doc.address : 'Thư viện Trung tâm Hà Nội',
          latitude: lat,
          longitude: lng,
        );
        idx++;
      }
      await _loadDocuments();
      if (mounted) {
        _showMessage('Đã gán tọa độ và vị trí kho lưu trữ mẫu cho ${withoutCoords.length} tài liệu thành công!');
      }
    } catch (e) {
      if (mounted) _showMessage('Lỗi gán tọa độ mẫu: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(CloudDocument document) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await _service.downloadDocument(document);
      if (saved && mounted) {
        _showMessage('Tệp đã được tải xuống an toàn.');
      }
    } catch (error) {
      if (mounted) _showMessage(_messageOf(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
    bool reload = true,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (reload) await _loadDocuments();
      if (mounted) _showMessage(successMessage);
    } catch (error) {
      if (mounted) _showMessage(_messageOf(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu Cloud · Supabase'),
        actions: [
          IconButton(
            tooltip: 'Mở dữ liệu SQLite cục bộ',
            onPressed: () => Navigator.pushReplacementNamed(context, '/local'),
            icon: const Icon(Icons.storage_outlined),
          ),
          if (user != null)
            IconButton(
              tooltip: 'Duyệt yêu cầu mượn tài liệu',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageRequestsScreen()),
              ),
              icon: const Icon(Icons.mark_email_unread_outlined),
            ),
          if (user != null)
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _loading ? null : _bootstrapCloud,
              icon: const Icon(Icons.refresh),
            ),
          if (user != null)
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: _busy ? null : AuthService.instance.signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      floatingActionButton: user != null && SupabaseService.isInitialized
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _showUploadDialog,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Tải tài liệu'),
            )
          : null,
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: user == null
                    ? _buildSignedOut()
                    : !SupabaseService.isInitialized
                        ? _buildConfigurationRequired(user)
                        : _buildWorkspace(user),
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignedOut() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_done_outlined,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                'Quản lý tài liệu đa nền tảng',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Đăng nhập Google để tải tệp lên Firebase Storage và quản lý quyền chia sẻ bằng Supabase RLS.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _signingIn ? null : _signIn,
                icon: _signingIn
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.account_circle_outlined),
                label: const Text('Đăng nhập bằng Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationRequired(User user) {
    return ListView(
      children: [
        _UserCard(user: user),
        const SizedBox(height: 16),
        Card(
          color: Colors.amber.shade50,
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_suggest_outlined, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Cần cấu hình Supabase',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SelectableText(
                  'flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co '
                  '--dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>',
                ),
                SizedBox(height: 8),
                Text(
                  'Xem CLOUD_SETUP.md để triển khai schema, RLS và Firebase Rules.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspace(User user) {
    return Column(
      children: [
        _UserCard(user: user),
        const SizedBox(height: 12),
        _buildTabBar(),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_selectedTabIndex) {
            1 => const RecommendedDocumentsWidget(),
            2 => const ManageRequestsScreen(isEmbedded: true),
            3 => DocumentsMapOverviewWidget(
                documents: _documents,
                onViewDocument: (doc) => _openLocationDialog(doc),
                onEditLocation: (doc) => _openLocationDialog(doc),
                onBorrowDocument: (doc) => BorrowRequestDialog.show(
                  context,
                  documentId: doc.id,
                  documentTitle: doc.title,
                  ownerId: doc.ownerId,
                  storageRoom: doc.storageRoom,
                  shelfCode: doc.shelfCode,
                  boxNumber: doc.boxNumber,
                  address: doc.address,
                ),
                onAssignDefaultLocations: _assignDefaultLocations,
              ),
            _ => _buildAllDocumentsTab(),
          },
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final mappedCount = _documents
        .where((d) =>
            d.latitude != null &&
            d.longitude != null &&
            d.latitude != 0.0 &&
            d.longitude != 0.0)
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<int>(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
        segments: [
          ButtonSegment<int>(
            value: 0,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text('Tất cả (${_documents.length})'),
          ),
          const ButtonSegment<int>(
            value: 1,
            icon: Icon(Icons.auto_awesome_outlined),
            label: Text('Gợi ý cho bạn'),
          ),
          const ButtonSegment<int>(
            value: 2,
            icon: Icon(Icons.swap_horiz_outlined),
            label: Text('Yêu cầu mượn'),
          ),
          ButtonSegment<int>(
            value: 3,
            icon: const Icon(Icons.map_outlined),
            label: Text('Bản đồ vị trí ($mappedCount)'),
          ),
        ],
        selected: {_selectedTabIndex},
        onSelectionChanged: (newSelection) {
          setState(() => _selectedTabIndex = newSelection.first);
        },
      ),
    );
  }

  Widget _buildAllDocumentsTab() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Tìm theo tiêu đề, mô tả hoặc tên tệp...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: Text(_error!),
              trailing: TextButton(
                onPressed: _bootstrapCloud,
                child: const Text('Thử lại'),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
                  ? const _EmptyDocuments()
                  : RefreshIndicator(
                      onRefresh: _bootstrapCloud,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: _documents.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, index) => _DocumentTile(
                          document: _documents[index],
                          disabled: _busy,
                          onDownload: () => _download(_documents[index]),
                          onEdit: () => _showEditDialog(_documents[index]),
                          onShare: () => showDialog<void>(
                            context: context,
                            builder: (_) => _ShareDocumentDialog(
                              document: _documents[index],
                              service: _service,
                            ),
                          ),
                          onViewLocation: () =>
                              _openLocationDialog(_documents[index]),
                          onBorrow: () => BorrowRequestDialog.show(
                            context,
                            documentId: _documents[index].id,
                            documentTitle: _documents[index].title,
                            ownerId: _documents[index].ownerId,
                            storageRoom: _documents[index].storageRoom,
                            shelfCode: _documents[index].shelfCode,
                            boxNumber: _documents[index].boxNumber,
                            address: _documents[index].address,
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }



  static String _messageOf(Object error) {
    if (error is CloudOperationException) return error.message;
    final text = error.toString();
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('PostgrestException(message: ', 'Supabase: ');
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              user.photoURL == null ? null : NetworkImage(user.photoURL!),
          child: user.photoURL == null
              ? Text((user.displayName ?? user.email ?? 'U')[0].toUpperCase())
              : null,
        ),
        title: Text(user.displayName ?? 'Người dùng Google'),
        subtitle: Text(user.email ?? user.uid),
        trailing: const Tooltip(
          message: 'Firebase Authentication',
          child: Icon(Icons.verified_user_outlined, color: Colors.green),
        ),
      ),
    );
  }
}

class _EmptyDocuments extends StatelessWidget {
  const _EmptyDocuments();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Chưa có tài liệu phù hợp.'),
          SizedBox(height: 4),
          Text(
            'Hãy tải tài liệu mới hoặc chờ người khác chia sẻ với bạn.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.disabled,
    required this.onDownload,
    required this.onEdit,
    required this.onShare,
    this.onViewLocation,
    this.onBorrow,
  });

  final CloudDocument document;
  final bool disabled;
  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback? onViewLocation;
  final VoidCallback? onBorrow;

  @override
  Widget build(BuildContext context) {
    final color = document.isOwner ? Colors.blue : Colors.teal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.shade50,
              child: Icon(Icons.description_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (document.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      document.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                        icon: Icons.attach_file,
                        text: document.fileName,
                      ),
                      _InfoChip(
                        icon: Icons.data_usage,
                        text: _formatBytes(document.fileSizeBytes),
                      ),
                      _InfoChip(
                        icon: document.isOwner ? Icons.person : Icons.group,
                        text: document.accessLevel.label,
                        color: color,
                      ),
                      if (document.storageRoom != null && document.storageRoom!.isNotEmpty)
                        _InfoChip(
                          icon: Icons.inventory_2_outlined,
                          text: document.storageRoom!,
                          color: Colors.indigo,
                        ),
                      if (document.tags.isNotEmpty)
                        ...document.tags.take(3).map(
                          (t) => _InfoChip(
                            icon: Icons.tag,
                            text: t,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Dòng badge vị trí vật lý của tài liệu
                  Builder(
                    builder: (context) {
                      final hasRoom = document.storageRoom?.isNotEmpty == true;
                      final hasShelf = document.shelfCode?.isNotEmpty == true;
                      final hasBox = document.boxNumber?.isNotEmpty == true;
                      final String locText;
                      if (hasRoom || hasShelf) {
                        final parts = <String>[];
                        if (hasRoom) parts.add(document.storageRoom!);
                        if (hasShelf) parts.add(document.shelfCode!);
                        if (hasBox) parts.add('Hộp ${document.boxNumber}');
                        locText = '📍 ${parts.join(" - ")}';
                      } else {
                        locText = '📍 Chưa cấu hình vị trí lưu kho';
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (hasRoom || hasShelf) ? const Color(0xFFEEF2FF) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (hasRoom || hasShelf) ? const Color(0xFFC7D2FE) : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          locText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (hasRoom || hasShelf) ? Colors.indigo.shade900 : Colors.grey.shade700,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Xem bản đồ / Định vị'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo.shade800,
                          side: BorderSide(color: Colors.indigo.shade300),
                          backgroundColor: Colors.indigo.shade50.withValues(alpha: 0.6),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onViewLocation,
                      ),
                      if (!document.isOwner)
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.local_library_outlined, size: 16, color: Colors.green),
                          label: const Text(
                            'Gửi yêu cầu mượn',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF0FDF4),
                            side: const BorderSide(color: Color(0xFFBBF7D0)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: onBorrow,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cập nhật: ${_formatDate(document.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !disabled,
              onSelected: (value) {
                if (value == 'download') onDownload();
                if (value == 'edit') onEdit();
                if (value == 'share') onShare();
                if (value == 'location') onViewLocation?.call();
                if (value == 'borrow') onBorrow?.call();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Tải xuống'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'location',
                  child: ListTile(
                    leading: Icon(Icons.location_on_outlined, color: Colors.indigo),
                    title: Text('Vị trí & Bản đồ'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!document.isOwner)
                  const PopupMenuItem(
                    value: 'borrow',
                    child: ListTile(
                      leading: Icon(Icons.local_library_outlined, color: Colors.green),
                      title: Text('Đăng ký mượn tài liệu'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (document.canEdit)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Sửa thông tin'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (document.isOwner)
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('Chia sẻ & phân quyền'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final MaterialColor? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (color ?? Colors.grey).shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color?.shade700 ?? Colors.grey.shade700),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _UploadRequest {
  const _UploadRequest({
    required this.file,
    required this.title,
    required this.description,
    this.storageRoom,
    this.shelfCode,
    this.boxNumber,
    this.address,
    this.latitude,
    this.longitude,
  });

  final PlatformFile file;
  final String title;
  final String description;
  final String? storageRoom;
  final String? shelfCode;
  final String? boxNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
}

class _UploadDocumentDialog extends StatefulWidget {
  const _UploadDocumentDialog();

  @override
  State<_UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<_UploadDocumentDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _storageRoom = TextEditingController(text: 'Phòng A1');
  final _shelfCode = TextEditingController(text: 'Kệ B2');
  final _boxNumber = TextEditingController(text: 'Hộp 01');
  final _address = TextEditingController(text: 'Thư viện Trung tâm Hà Nội');
  final _latitude = TextEditingController(text: '21.0285');
  final _longitude = TextEditingController(text: '105.8542');

  PlatformFile? _file;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _storageRoom.dispose();
    _shelfCode.dispose();
    _boxNumber.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _setDefaultHanoi() {
    setState(() {
      _storageRoom.text = 'Phòng A1';
      _shelfCode.text = 'Kệ B2';
      _boxNumber.text = 'Hộp 01';
      _address.text = 'Thư viện Trung tâm Hà Nội';
      _latitude.text = '21.0285';
      _longitude.text = '105.8542';
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      final size = file.size;
      setState(() {
        _file = file;
        _error = size > CloudWorkspaceService.maxFileSizeBytes
            ? 'Tệp vượt quá giới hạn 25 MB.'
            : null;
        if (_title.text.trim().isEmpty) {
          _title.text = file.name.contains('.')
              ? file.name.substring(0, file.name.lastIndexOf('.'))
              : file.name;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _submit() {
    if (_file == null || _title.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng chọn tệp và nhập tiêu đề.');
      return;
    }

    // Nếu người dùng không nhập tọa độ, mặc định gán Hà Nội: 21.0285, 105.8542
    final lat = double.tryParse(_latitude.text.trim()) ?? 21.0285;
    final lng = double.tryParse(_longitude.text.trim()) ?? 105.8542;

    Navigator.pop(
      context,
      _UploadRequest(
        file: _file!,
        title: _title.text.trim(),
        description: _description.text.trim(),
        storageRoom: _storageRoom.text.trim().isNotEmpty ? _storageRoom.text.trim() : 'Phòng A1',
        shelfCode: _shelfCode.text.trim().isNotEmpty ? _shelfCode.text.trim() : 'Kệ B2',
        boxNumber: _boxNumber.text.trim().isNotEmpty ? _boxNumber.text.trim() : 'Hộp 01',
        address: _address.text.trim().isNotEmpty ? _address.text.trim() : 'Thư viện Trung tâm Hà Nội',
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: Colors.indigo),
          SizedBox(width: 8),
          Text('Tải tài liệu & Định vị lưu trữ'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề tài liệu *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 2,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Mô tả nội dung',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_file?.name ?? 'Chọn tệp từ máy (tối đa 25 MB)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Khối Thông tin vị trí vật lý
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.indigo),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Vị trí lưu kho & Tọa độ Bản đồ GPS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _setDefaultHanoi,
                          icon: const Icon(Icons.gps_fixed, size: 14),
                          label: const Text('Gán mặc định HN', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _storageRoom,
                            decoration: const InputDecoration(
                              labelText: 'Phòng lưu trữ',
                              hintText: 'VD: Phòng A1',
                              prefixIcon: Icon(Icons.meeting_room_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _shelfCode,
                            decoration: const InputDecoration(
                              labelText: 'Mã kệ',
                              hintText: 'VD: Kệ B2',
                              prefixIcon: Icon(Icons.shelves, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _boxNumber,
                            decoration: const InputDecoration(
                              labelText: 'Số hộp',
                              hintText: 'VD: Hộp 01',
                              prefixIcon: Icon(Icons.all_inbox_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _address,
                            decoration: const InputDecoration(
                              labelText: 'Địa chỉ / Cơ sở',
                              hintText: 'VD: Thư viện ĐH',
                              prefixIcon: Icon(Icons.place_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latitude,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Vĩ độ (Latitude)',
                              hintText: '21.0285',
                              prefixIcon: Icon(Icons.explore_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _longitude,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Kinh độ (Longitude)',
                              hintText: '105.8542',
                              prefixIcon: Icon(Icons.explore_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('Tải lên & Lưu vị trí'),
        ),
      ],
    );
  }
}

class _EditRequest {
  const _EditRequest({
    required this.title,
    required this.description,
    this.storageRoom,
    this.shelfCode,
    this.boxNumber,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String description;
  final String? storageRoom;
  final String? shelfCode;
  final String? boxNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
}

class _EditDocumentDialog extends StatefulWidget {
  const _EditDocumentDialog({required this.document});
  final CloudDocument document;

  @override
  State<_EditDocumentDialog> createState() => _EditDocumentDialogState();
}

class _EditDocumentDialogState extends State<_EditDocumentDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _storageRoom;
  late final TextEditingController _shelfCode;
  late final TextEditingController _boxNumber;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _title = TextEditingController(text: doc.title);
    _description = TextEditingController(text: doc.description);
    _storageRoom = TextEditingController(text: doc.storageRoom ?? 'Phòng A1');
    _shelfCode = TextEditingController(text: doc.shelfCode ?? 'Kệ B2');
    _boxNumber = TextEditingController(text: doc.boxNumber ?? 'Hộp 01');
    _address = TextEditingController(
      text: doc.address?.isNotEmpty == true ? doc.address! : 'Thư viện Trung tâm Hà Nội',
    );
    _latitude = TextEditingController(
      text: (doc.latitude != null && doc.latitude != 0.0)
          ? doc.latitude!.toStringAsFixed(6)
          : '21.0285',
    );
    _longitude = TextEditingController(
      text: (doc.longitude != null && doc.longitude != 0.0)
          ? doc.longitude!.toStringAsFixed(6)
          : '105.8542',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _storageRoom.dispose();
    _shelfCode.dispose();
    _boxNumber.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _setDefaultHanoi() {
    setState(() {
      _storageRoom.text = 'Phòng A1';
      _shelfCode.text = 'Kệ B2';
      _boxNumber.text = 'Hộp 01';
      _address.text = 'Thư viện Trung tâm Hà Nội';
      _latitude.text = '21.0285';
      _longitude.text = '105.8542';
    });
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;

    final lat = double.tryParse(_latitude.text.trim()) ?? 21.0285;
    final lng = double.tryParse(_longitude.text.trim()) ?? 105.8542;

    Navigator.pop(
      context,
      _EditRequest(
        title: _title.text.trim(),
        description: _description.text.trim(),
        storageRoom: _storageRoom.text.trim(),
        shelfCode: _shelfCode.text.trim(),
        boxNumber: _boxNumber.text.trim(),
        address: _address.text.trim(),
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_location_alt_outlined, color: Colors.indigo),
          SizedBox(width: 8),
          Text('Cập nhật tài liệu & Vị trí kho'),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 2,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Khối Vị trí lưu kho
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.indigo),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Vị trí lưu kho & Tọa độ GPS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _setDefaultHanoi,
                          icon: const Icon(Icons.gps_fixed, size: 14),
                          label: const Text('Mặc định HN', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _storageRoom,
                            decoration: const InputDecoration(
                              labelText: 'Phòng lưu trữ',
                              prefixIcon: Icon(Icons.meeting_room_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _shelfCode,
                            decoration: const InputDecoration(
                              labelText: 'Mã kệ',
                              prefixIcon: Icon(Icons.shelves, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _boxNumber,
                            decoration: const InputDecoration(
                              labelText: 'Số hộp',
                              prefixIcon: Icon(Icons.all_inbox_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _address,
                            decoration: const InputDecoration(
                              labelText: 'Địa chỉ / Cơ sở',
                              prefixIcon: Icon(Icons.place_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latitude,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Vĩ độ (Latitude)',
                              prefixIcon: Icon(Icons.explore_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _longitude,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Kinh độ (Longitude)',
                              prefixIcon: Icon(Icons.explore_outlined, size: 18),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Lưu thay đổi'),
        ),
      ],
    );
  }
}

class _ShareDocumentDialog extends StatefulWidget {
  const _ShareDocumentDialog({required this.document, required this.service});

  final CloudDocument document;
  final CloudWorkspaceService service;

  @override
  State<_ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<_ShareDocumentDialog> {
  final _email = TextEditingController();
  CloudAccessLevel _level = CloudAccessLevel.viewer;
  List<DocumentPermission> _permissions = const [];
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final permissions = await widget.service.getPermissions(
        widget.document.id,
      );
      if (mounted) {
        setState(() {
          _permissions = permissions;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    if (_email.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.shareDocument(
        documentId: widget.document.id,
        email: _email.text,
        accessLevel: _level,
      );
      _email.clear();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(DocumentPermission permission) async {
    setState(() => _saving = true);
    try {
      await widget.service.revokePermission(
        documentId: widget.document.id,
        permission: permission,
      );
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Chia sẻ “${widget.document.title}”'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email người nhận',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CloudAccessLevel>(
                initialValue: _level,
                decoration: const InputDecoration(
                  labelText: 'Quyền truy cập',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: CloudAccessLevel.viewer,
                    child: Text('Chỉ xem và tải xuống'),
                  ),
                  DropdownMenuItem(
                    value: CloudAccessLevel.editor,
                    child: Text('Xem và sửa thông tin'),
                  ),
                ],
                onChanged:
                    _saving ? null : (value) => setState(() => _level = value!),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _share,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Cấp quyền'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const Divider(height: 28),
              const Text(
                'Người đang có quyền',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_permissions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Tài liệu chưa được chia sẻ.'),
                )
              else
                ..._permissions.map(
                  (permission) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      permission.displayName.isEmpty
                          ? permission.email
                          : permission.displayName,
                    ),
                    subtitle: Text(
                      '${permission.email} · ${permission.accessLevel.label}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Thu hồi quyền',
                      onPressed: _saving ? null : () => _revoke(permission),
                      icon: const Icon(
                        Icons.person_remove_outlined,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
