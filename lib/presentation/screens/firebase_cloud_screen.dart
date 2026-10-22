import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/cloud_document.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_workspace_service.dart';
import '../../services/supabase_service.dart';

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
        );
      },
      successMessage: 'Đã tải tệp lên Firebase và lưu metadata trên Supabase.',
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
      ),
      successMessage: 'Đã cập nhật thông tin tài liệu.',
    );
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
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
          backgroundImage: user.photoURL == null
              ? null
              : NetworkImage(user.photoURL!),
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
  });

  final CloudDocument document;
  final bool disabled;
  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final VoidCallback onShare;

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
  const _UploadRequest(this.file, this.title, this.description);
  final PlatformFile file;
  final String title;
  final String description;
}

class _UploadDocumentDialog extends StatefulWidget {
  const _UploadDocumentDialog();

  @override
  State<_UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<_UploadDocumentDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  PlatformFile? _file;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      final file = result?.files.singleOrNull;
      if (file == null || !mounted) return;
      final size = file.size;
      if (!mounted) return;
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
    Navigator.pop(
      context,
      _UploadRequest(_file!, _title.text.trim(), _description.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tải tài liệu mới'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_file?.name ?? 'Chọn tệp (tối đa 25 MB)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
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
        FilledButton(onPressed: _submit, child: const Text('Tải lên')),
      ],
    );
  }
}

class _EditRequest {
  const _EditRequest(this.title, this.description);
  final String title;
  final String description;
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

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.document.title);
    _description = TextEditingController(text: widget.document.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cập nhật tài liệu'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _EditRequest(_title.text.trim(), _description.text.trim()),
            );
          },
          child: const Text('Lưu'),
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
                value: _level,
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
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _level = value!),
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
