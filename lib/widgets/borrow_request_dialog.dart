import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/borrow_share_service.dart';

/// Hộp thoại cho phép người dùng gửi yêu cầu mượn tài liệu vật lý
class BorrowRequestDialog extends StatefulWidget {
  const BorrowRequestDialog({
    super.key,
    required this.documentId,
    required this.documentTitle,
    this.ownerId,
    this.storageRoom,
    this.shelfCode,
    this.boxNumber,
    this.address,
    this.borrowService,
  });

  final String documentId;
  final String documentTitle;
  final String? ownerId;
  final String? storageRoom;
  final String? shelfCode;
  final String? boxNumber;
  final String? address;
  final BorrowShareService? borrowService;

  static Future<bool?> show(
    BuildContext context, {
    required String documentId,
    required String documentTitle,
    String? ownerId,
    String? storageRoom,
    String? shelfCode,
    String? boxNumber,
    String? address,
    BorrowShareService? borrowService,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BorrowRequestDialog(
        documentId: documentId,
        documentTitle: documentTitle,
        ownerId: ownerId,
        storageRoom: storageRoom,
        shelfCode: shelfCode,
        boxNumber: boxNumber,
        address: address,
        borrowService: borrowService,
      ),
    );
  }

  @override
  State<BorrowRequestDialog> createState() => _BorrowRequestDialogState();
}

class _BorrowRequestDialogState extends State<BorrowRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  late final BorrowShareService _service;
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 7));
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.borrowService ?? BorrowShareService();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDueDate.isAfter(now)
        ? _selectedDueDate
        : now.add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'CHỌN NGÀY DỰ KIẾN TRẢ TÀI LIỆU',
      confirmText: 'CHỌN',
      cancelText: 'HỦY',
    );

    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _submitBorrowRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Bạn cần đăng nhập tài khoản trước khi yêu cầu mượn.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await _service.requestBorrow(
        docId: widget.documentId,
        ownerId: widget.ownerId,
        requesterUid: user.uid,
        dueDate: _selectedDueDate,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã gửi yêu cầu mượn "${widget.documentTitle}". Vui lòng chờ chủ sở hữu duyệt!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('BorrowShareServiceException: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final hasLocation = (widget.storageRoom?.isNotEmpty == true) ||
        (widget.shelfCode?.isNotEmpty == true) ||
        (widget.boxNumber?.isNotEmpty == true);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tiêu đề Dialog
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_library_rounded,
                          color: Colors.indigo,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đăng ký Mượn Tài liệu',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Gửi yêu cầu mượn bản cứng đến người quản lý',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tóm tắt tài liệu & vị trí
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.documentTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasLocation) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: Colors.indigo.shade700,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Kho: ${[
                                    if (widget.storageRoom?.isNotEmpty == true) widget.storageRoom!,
                                    if (widget.shelfCode?.isNotEmpty == true) 'Kệ ${widget.shelfCode!}',
                                    if (widget.boxNumber?.isNotEmpty == true) 'Hộp ${widget.boxNumber!}',
                                  ].join(' - ')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.indigo.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Chọn Ngày dự kiến trả (DatePicker)
                  Text(
                    'Ngày dự kiến trả *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _submitting ? null : _pickDueDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateFormat.format(_selectedDueDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            'Thay đổi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nhập Ghi chú mượn
                  Text(
                    'Ghi chú mượn / Lý do',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    enabled: !_submitting,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nhập mục đích sử dụng, số điện thoại liên hệ...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  // Báo lỗi (nếu có)
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // Nút Hủy và Nút Gửi yêu cầu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submitting ? null : _submitBorrowRequest,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.send_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Gửi yêu cầu',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
