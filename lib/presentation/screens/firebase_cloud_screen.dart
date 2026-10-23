import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/supabase_config.dart';

import '../../domain/entities/cloud_document.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_workspace_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/supabase_service.dart';
import '../widgets/location_map_button.dart';

/// Không gian tài liệu đa nền tảng: Firebase Auth + Supabase Database/Storage.
class FirebaseCloudScreen extends StatefulWidget {
  const FirebaseCloudScreen({super.key});

  @override
  State<FirebaseCloudScreen> createState() => _FirebaseCloudScreenState();
}

class _FirebaseCloudScreenState extends State<FirebaseCloudScreen> {
  CloudWorkspaceService? _service;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<void>? _changesSubscription;
  Timer? _realtimeDebounce;
  Timer? _permissionRefresh;

  List<CloudDocument> _documents = const [];
  Timer? _searchDebounce;
  String? _loadedUserId;
  String? _error;
  bool _loading = false;
  bool _busy = false;
  bool _signingIn = false;
  int _loadGeneration = 0;
  bool _firebaseReady = false;
  bool _cloudReady = false;
  bool _tokenVerificationFailed = false;

  CloudWorkspaceService get _cloudService => _service!;

  @override
  void initState() {
    super.initState();
    _firebaseReady = Firebase.apps.isNotEmpty;
    if (!_firebaseReady) {
      _error = 'Firebase chưa khởi tạo thành công trên nền tảng này.';
      return;
    }
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
        onError: (Object error) {
          debugPrint('Firebase Messaging foreground stream failed: $error');
        },
      );
    }
    _service = CloudWorkspaceService()
      ..onNotificationWarning = (message) {
        if (mounted) _showMessage(message, isError: true);
      };
    _authSubscription = AuthService.instance.authStateChanges.listen(
      _handleAuthChanged,
    );
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    _realtimeDebounce?.cancel();
    _permissionRefresh?.cancel();
    _authSubscription?.cancel();
    _messageSubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleAuthChanged(User? user) {
    if (!mounted) return;
    if (user != null && _loadedUserId == user.uid) return;
    _cloudReady = false;
    _loadGeneration++;
    _changesSubscription?.cancel();
    _changesSubscription = null;
    _permissionRefresh?.cancel();
    _permissionRefresh = null;
    _realtimeDebounce?.cancel();
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
    _loadedUserId = user.uid;
    setState(() => _documents = const []);
    unawaited(_bootstrapCloud());
  }

  Future<void> _bootstrapCloud() async {
    if (!_firebaseReady) {
      setState(
        () => _error = 'Firebase chưa khởi tạo thành công trên nền tảng này.',
      );
      return;
    }
    if (!SupabaseService.isInitialized) {
      setState(() {
        _error = 'Supabase chưa được cấu hình bằng --dart-define.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _cloudReady = false;
      _tokenVerificationFailed = false;
      _error = null;
    });
    try {
      // Retry with a newly issued token after changes to third-party auth.
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      await _cloudService.syncCurrentUser();
      if (!mounted || userId != FirebaseAuth.instance.currentUser?.uid) return;
      _changesSubscription ??= _cloudService.watchChanges().listen(
        (_) {
          _realtimeDebounce?.cancel();
          _realtimeDebounce = Timer(const Duration(milliseconds: 200), () {
            if (mounted) unawaited(_searchDocuments());
          });
        },
        onError: (Object error) {
          debugPrint('Realtime workspace error: $error');
        },
      );
      // Permission revocation may remove visibility of the event itself.
      _permissionRefresh ??= Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && !_busy) unawaited(_searchDocuments());
      });
      try {
        final notificationWarning = await PushNotificationService.instance
            .registerCurrentDevice(SupabaseService.client);
        if (notificationWarning != null && mounted) {
          _showMessage(notificationWarning, isError: true);
        }
      } catch (error) {
        if (mounted) {
          _showMessage(
            'Cloud đã kết nối nhưng đăng ký thông báo thất bại: '
            '${_messageOf(error)}',
            isError: true,
          );
        }
      }
      await _loadDocuments();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _messageOf(error);
          _cloudReady = false;
          _tokenVerificationFailed =
              error is PostgrestException && error.code == 'PGRST301';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!mounted) return;
    final notification = message.notification;
    final title = notification?.title?.trim();
    final body = notification?.body?.trim();
    final text = [
      if (title != null && title.isNotEmpty) title,
      if (body != null && body.isNotEmpty) body,
    ].join(': ');
    if (text.isNotEmpty) _showMessage(text);
  }

  Future<void> _loadDocuments() async {
    final generation = ++_loadGeneration;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final documents = await _cloudService.getDocuments(
      query: _searchController.text,
    );
    if (mounted &&
        generation == _loadGeneration &&
        userId == FirebaseAuth.instance.currentUser?.uid) {
      setState(() {
        _documents = documents;
        _cloudReady = true;
        _tokenVerificationFailed = false;
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

  Future<void> _signOut() async {
    var notificationWarning = false;
    if (SupabaseService.isInitialized) {
      try {
        await PushNotificationService.instance.unregisterCurrentDevice(
          SupabaseService.client,
        );
      } catch (error) {
        notificationWarning = true;
        debugPrint('FCM token removal failed during sign-out: $error');
      }
    }
    try {
      await AuthService.instance.signOut();
      if (notificationWarning && mounted) {
        _showMessage(
          'Đã đăng xuất nhưng chưa gỡ được token thông báo; '
          'token sẽ được chuyển khi tài khoản khác đăng nhập.',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) _showMessage(_messageOf(error), isError: true);
    }
  }

  Future<void> _editInterests() async {
    final controller = TextEditingController();
    try {
      controller.text = (await _cloudService.getInterests()).join(', ');
      if (!mounted) return;
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tag sở thích'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Ví dụ: Flutter, SQL, thiết kế',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Lưu'),
            ),
          ],
        ),
      );
      if (value != null) {
        await _cloudService.saveInterests(value);
        if (mounted) _showMessage('Đã lưu sở thích để gợi ý tài liệu.');
      }
    } catch (error) {
      if (mounted) _showMessage(_messageOf(error), isError: true);
    } finally {
      // Dialog route animations may still be using the controller.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
    }
  }

  Future<void> _showUploadDialog() async {
    final request = await showDialog<_UploadRequest>(
      context: context,
      builder: (_) => const _UploadDocumentDialog(),
    );
    if (request == null) return;
    await _runAction(() async {
      await _cloudService.uploadDocument(
        file: request.file,
        title: request.title,
        description: request.description,
        tags: request.tags,
        physicalLocation: request.physicalLocation,
        latitude: request.latitude,
        longitude: request.longitude,
        isBorrowable: request.isBorrowable,
      );
    }, successMessage: 'Đã tải tệp và metadata lên Supabase.');
  }

  Future<void> _showEditDialog(CloudDocument document) async {
    final result = await showDialog<_EditRequest>(
      context: context,
      builder: (_) => _EditDocumentDialog(document: document),
    );
    if (result == null) return;
    await _runAction(
      () => _cloudService.updateDocument(
        documentId: document.id,
        title: result.title,
        description: result.description,
        tags: result.tags,
        physicalLocation: result.physicalLocation,
        latitude: result.latitude,
        longitude: result.longitude,
        isBorrowable: result.isBorrowable,
      ),
      successMessage: 'Đã cập nhật thông tin tài liệu.',
    );
  }

  Future<void> _download(CloudDocument document) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await _cloudService.downloadDocument(document);
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
    final user = _firebaseReady ? FirebaseAuth.instance.currentUser : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu Cloud · Supabase'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn tài liệu Cloud',
            onSelected: (value) async {
              switch (value) {
                case 'local':
                  Navigator.pushReplacementNamed(context, '/local');
                case 'catalog':
                  await showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _BorrowCatalogDialog(service: _cloudService),
                  );
                case 'requests':
                  await showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _BorrowRequestsDialog(service: _cloudService),
                  );
                case 'interests':
                  await _editInterests();
                case 'refresh':
                  await _bootstrapCloud();
                case 'logout':
                  await _signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'local',
                child: Text('Thư viện cục bộ'),
              ),
              if (user != null && _cloudReady) ...[
                const PopupMenuItem(
                  value: 'catalog',
                  child: Text('Khám phá & gợi ý tài liệu'),
                ),
                const PopupMenuItem(
                  value: 'requests',
                  child: Text('Yêu cầu mượn'),
                ),
                const PopupMenuItem(
                  value: 'interests',
                  child: Text('Tag sở thích'),
                ),
                const PopupMenuItem(value: 'refresh', child: Text('Làm mới')),
              ],
              if (user != null)
                PopupMenuItem(
                  value: 'logout',
                  enabled: !_busy,
                  child: const Text('Đăng xuất'),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: user != null && _cloudReady
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
                child: !_firebaseReady
                    ? _buildFirebaseUnavailable()
                    : user == null
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
                'Đăng nhập Google để lưu tài liệu trên Supabase Storage và quản lý quyền bằng Supabase RLS.',
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

  Widget _buildFirebaseUnavailable() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Firebase Cloud chưa sẵn sàng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(_error ?? 'Kiểm tra cấu hình Firebase cho nền tảng này.'),
              const SizedBox(height: 12),
              const Text(
                'Thư viện cục bộ vẫn hoạt động. Cấu hình Android/Web trong '
                'firebase_options.dart để bật đăng nhập và chia sẻ Cloud.',
                textAlign: TextAlign.center,
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
                  'Xem CLOUD_SETUP.md để triển khai schema, RLS, Storage và Firebase Messaging.',
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
            hintText: 'Tìm tiêu đề, mô tả, tên tệp hoặc tag...',
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
              subtitle: _tokenVerificationFailed
                  ? Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://supabase.com/dashboard/project/${Uri.parse(SupabaseConfig.url).host.split('.').first}/auth/third-party',
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text(
                            'Mở cấu hình Firebase trên Supabase',
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _bootstrapCloud,
                          child: const Text('Kiểm tra lại kết nối'),
                        ),
                      ],
                    )
                  : null,
              trailing: _tokenVerificationFailed
                  ? null
                  : TextButton(
                      onPressed: _loading ? null : _bootstrapCloud,
                      child: const Text('Thử lại'),
                    ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && !_cloudReady
              ? const Center(child: Text('Chưa kết nối được dữ liệu Cloud.'))
              : _documents.isEmpty
              ? const _EmptyDocuments()
              : RefreshIndicator(
                  onRefresh: _bootstrapCloud,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: _documents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _DocumentTile(
                      document: _documents[index],
                      disabled: _busy,
                      onDownload: () => _download(_documents[index]),
                      onEdit: () => _showEditDialog(_documents[index]),
                      onShare: () => showDialog<void>(
                        context: context,
                        builder: (_) => _ShareDocumentDialog(
                          document: _documents[index],
                          service: _cloudService,
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
    if (error is PostgrestException && error.code == 'PGRST301') {
      return 'Supabase tại ${SupabaseConfig.url} chưa xác minh được Firebase ID token (PGRST301). '
          'Kiểm tra kết nối Firebase với Project ID device-streaming-33cac12e '
          'trong Third-Party Auth của đúng project này. '
          'Nếu kết nối đã tồn tại, cần kiểm tra trạng thái và cấu hình khóa xác minh phía Supabase.';
    }
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
                  if (document.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: document.tags
                          .map(
                            (tag) => Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('#$tag'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (document.physicalLocation.isNotEmpty ||
                      (document.latitude != null && document.longitude != null))
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.physicalLocation.isEmpty
                                ? '${document.latitude}, ${document.longitude}'
                                : document.physicalLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        LocationMapButton(
                          location: document.physicalLocation,
                          latitude: document.latitude,
                          longitude: document.longitude,
                        ),
                      ],
                    ),
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
  const _UploadRequest({
    required this.file,
    required this.title,
    required this.description,
    required this.tags,
    required this.physicalLocation,
    required this.latitude,
    required this.longitude,
    required this.isBorrowable,
  });
  final PlatformFile file;
  final String title;
  final String description;
  final List<String> tags;
  final String physicalLocation;
  final double? latitude;
  final double? longitude;
  final bool isBorrowable;
}

class _UploadDocumentDialog extends StatefulWidget {
  const _UploadDocumentDialog();

  @override
  State<_UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<_UploadDocumentDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  final _location = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  bool _isBorrowable = false;
  PlatformFile? _file;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    _location.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null || !mounted) return;
      final size = file.lengthSync() ?? await file.length();
      if (!mounted) return;
      setState(() {
        _file = file;
        _error = size != null && size > CloudWorkspaceService.maxFileSizeBytes
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
    final latitudeText = _latitude.text.trim();
    final longitudeText = _longitude.text.trim();
    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if ((latitudeText.isNotEmpty && latitude == null) ||
        (longitudeText.isNotEmpty && longitude == null) ||
        (latitude == null) != (longitude == null) ||
        (latitude != null &&
            (!latitude.isFinite || latitude < -90 || latitude > 90)) ||
        (longitude != null &&
            (!longitude.isFinite || longitude < -180 || longitude > 180))) {
      setState(
        () => _error = 'Tọa độ phải hợp lệ và cần nhập đủ cả hai giá trị.',
      );
      return;
    }
    Navigator.pop(
      context,
      _UploadRequest(
        file: _file!,
        title: _title.text.trim(),
        description: _description.text.trim(),
        tags: _tags.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
        physicalLocation: _location.text.trim(),
        latitude: latitude,
        longitude: longitude,
        isBorrowable: _isBorrowable,
      ),
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
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Thẻ (phân cách bằng dấu phẩy)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Vị trí tài liệu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _latitude,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Vĩ độ (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _longitude,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Kinh độ (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              LocationMapButton(
                location: _location.text,
                latitude: double.tryParse(_latitude.text),
                longitude: double.tryParse(_longitude.text),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isBorrowable,
                onChanged: (value) =>
                    setState(() => _isBorrowable = value ?? false),
                title: const Text('Cho phép người khác yêu cầu mượn'),
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
  const _EditRequest({
    required this.title,
    required this.description,
    required this.tags,
    required this.physicalLocation,
    required this.latitude,
    required this.longitude,
    required this.isBorrowable,
  });
  final String title;
  final String description;
  final List<String> tags;
  final String physicalLocation;
  final double? latitude;
  final double? longitude;
  final bool isBorrowable;
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
  late final TextEditingController _tags;
  late final TextEditingController _location;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late bool _isBorrowable;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.document.title);
    _description = TextEditingController(text: widget.document.description);
    _tags = TextEditingController(text: widget.document.tags.join(', '));
    _location = TextEditingController(text: widget.document.physicalLocation);
    _latitude = TextEditingController(
      text: widget.document.latitude?.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: widget.document.longitude?.toString() ?? '',
    );
    _isBorrowable = widget.document.isBorrowable;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    _location.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tiêu đề tài liệu.');
      return;
    }
    final latitudeText = _latitude.text.trim();
    final longitudeText = _longitude.text.trim();
    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if ((latitudeText.isNotEmpty && latitude == null) ||
        (longitudeText.isNotEmpty && longitude == null) ||
        (latitude == null) != (longitude == null) ||
        (latitude != null &&
            (!latitude.isFinite || latitude < -90 || latitude > 90)) ||
        (longitude != null &&
            (!longitude.isFinite || longitude < -180 || longitude > 180))) {
      setState(
        () => _error = 'Tọa độ phải hợp lệ và cần nhập đủ cả hai giá trị.',
      );
      return;
    }
    Navigator.pop(
      context,
      _EditRequest(
        title: _title.text.trim(),
        description: _description.text.trim(),
        tags: _tags.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
        physicalLocation: _location.text.trim(),
        latitude: latitude,
        longitude: longitude,
        isBorrowable: _isBorrowable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cập nhật tài liệu'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
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
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Thẻ (phân cách bằng dấu phẩy)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Vị trí tài liệu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _latitude,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Vĩ độ (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _longitude,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Kinh độ (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              LocationMapButton(
                location: _location.text,
                latitude: double.tryParse(_latitude.text),
                longitude: double.tryParse(_longitude.text),
              ),
              if (widget.document.isOwner)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isBorrowable,
                  onChanged: (value) =>
                      setState(() => _isBorrowable = value ?? false),
                  title: const Text('Cho phép người khác yêu cầu mượn'),
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
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

class _BorrowCatalogDialog extends StatefulWidget {
  const _BorrowCatalogDialog({required this.service});

  final CloudWorkspaceService service;

  @override
  State<_BorrowCatalogDialog> createState() => _BorrowCatalogDialogState();
}

class _BorrowCatalogDialogState extends State<_BorrowCatalogDialog> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _documents = const [];
  String? _error;
  bool _recommended = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await widget.service.searchBorrowableDocuments(
        query: _query.text,
        recommended: _recommended,
      );
      if (mounted) {
        setState(() {
          _documents = results;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(Map<String, dynamic> document) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _BorrowMessageDialog(),
    );
    if (message == null) return;
    setState(() => _saving = true);
    try {
      await widget.service.requestBorrow(
        documentId: document['id'] as String,
        message: message,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu mượn tài liệu.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tài liệu mở cho mượn'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: SizedBox(
          width: 620,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Gợi ý theo sở thích và lịch sử'),
                contentPadding: EdgeInsets.zero,
                value: _recommended,
                onChanged: (value) {
                  setState(() => _recommended = value);
                  unawaited(_load());
                },
              ),
              TextField(
                controller: _query,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  labelText: 'Tìm theo tên, mô tả hoặc tag',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: _load,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _documents.isEmpty
                    ? const Center(
                        child: Text('Chưa có tài liệu nào mở cho mượn.'),
                      )
                    : ListView.builder(
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final document = _documents[index];
                          final tags =
                              (document['tags'] as List<dynamic>? ?? const [])
                                  .map((tag) => tag.toString())
                                  .join(', ');
                          final location =
                              document['physical_location'] as String? ?? '';
                          final latitude = (document['latitude'] as num?)
                              ?.toDouble();
                          final longitude = (document['longitude'] as num?)
                              ?.toDouble();
                          return Card(
                            child: ListTile(
                              title: Text(document['title'] as String? ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chủ sở hữu: ${document['owner_name'] ?? ''}',
                                  ),
                                  if (tags.isNotEmpty) Text('Tag: $tags'),
                                  if (_recommended)
                                    Text(
                                      'Điểm phù hợp: ${document['score'] ?? 0}',
                                    ),
                                  if (location.isNotEmpty)
                                    Text('Vị trí: $location'),
                                  if (location.isNotEmpty ||
                                      (latitude != null && longitude != null))
                                    LocationMapButton(
                                      location: location,
                                      latitude: latitude,
                                      longitude: longitude,
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'Yêu cầu mượn',
                                onPressed: _saving
                                    ? null
                                    : () => _request(document),
                                icon: const Icon(Icons.handshake_outlined),
                              ),
                            ),
                          );
                        },
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

class _BorrowRequestsDialog extends StatefulWidget {
  const _BorrowRequestsDialog({required this.service});

  final CloudWorkspaceService service;

  @override
  State<_BorrowRequestsDialog> createState() => _BorrowRequestsDialogState();
}

class _BorrowRequestsDialogState extends State<_BorrowRequestsDialog> {
  List<CloudBorrowRequest> _requests = const [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<void>? _changes;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _load();
    _changes = widget.service.watchChanges().listen(
      (_) {
        if (mounted) unawaited(_load());
      },
      onError: (Object error) {
        debugPrint('Borrow request realtime error: $error');
      },
    );
    _fallback = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_saving) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    _fallback?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final requests = await widget.service.getBorrowRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(
    CloudBorrowRequest request, {
    required bool approve,
  }) async {
    setState(() => _saving = true);
    try {
      await widget.service.respondToBorrowRequest(request, approve: approve);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return AlertDialog(
      title: const Text('Yêu cầu mượn tài liệu'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: SizedBox(
          width: 620,
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _requests.isEmpty
                    ? const Center(child: Text('Chưa có yêu cầu mượn nào.'))
                    : ListView.separated(
                        itemCount: _requests.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final request = _requests[index];
                          final incoming = request.isIncomingFor(userId);
                          return ListTile(
                            title: Text(request.documentTitle),
                            subtitle: Text(
                              '${incoming ? 'Người yêu cầu' : 'Mã chủ sở hữu'}: '
                              '${incoming ? request.requesterName : request.ownerId}'
                              '${request.message.isEmpty ? '' : '\n${request.message}'}'
                              '\nTrạng thái: ${request.status}',
                            ),
                            isThreeLine: true,
                            trailing: incoming && request.status == 'pending'
                                ? Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'Chấp nhận và cấp quyền xem',
                                        onPressed: _saving
                                            ? null
                                            : () => _respond(
                                                request,
                                                approve: true,
                                              ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.green,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Từ chối',
                                        onPressed: _saving
                                            ? null
                                            : () => _respond(
                                                request,
                                                approve: false,
                                              ),
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
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

class _BorrowMessageDialog extends StatefulWidget {
  const _BorrowMessageDialog();

  @override
  State<_BorrowMessageDialog> createState() => _BorrowMessageDialogState();
}

class _BorrowMessageDialogState extends State<_BorrowMessageDialog> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gửi yêu cầu mượn'),
      content: TextField(
        controller: _message,
        maxLength: 1000,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Lời nhắn cho chủ sở hữu (tùy chọn)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _message.text.trim()),
          child: const Text('Gửi yêu cầu'),
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
