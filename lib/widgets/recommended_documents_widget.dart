import 'package:flutter/material.dart';
import '../data/models/borrow_share_models.dart';
import '../services/recommendation_service.dart';
import 'borrow_request_dialog.dart';
import 'document_location_widget.dart';

/// Widget hiển thị danh sách ngang hoặc grid các tài liệu được thuật toán AI/SQL RPC gợi ý
class RecommendedDocumentsWidget extends StatefulWidget {
  const RecommendedDocumentsWidget({
    super.key,
    this.recommendationService,
    this.limit = 10,
    this.onDocumentTap,
    this.isGrid = false,
  });

  final RecommendationService? recommendationService;
  final int limit;
  final void Function(RecommendedDocumentModel doc)? onDocumentTap;
  final bool isGrid;

  @override
  State<RecommendedDocumentsWidget> createState() => _RecommendedDocumentsWidgetState();
}

class _RecommendedDocumentsWidgetState extends State<RecommendedDocumentsWidget> {
  late final RecommendationService _service;

  List<RecommendedDocumentModel> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.recommendationService ?? RecommendationService();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.getRecommendedDocuments(limit: widget.limit);
      if (mounted) {
        setState(() {
          _recommendations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showLocationSheet(RecommendedDocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: DocumentLocationWidget(
                  latitude: doc.latitude,
                  longitude: doc.longitude,
                  room: doc.storageRoom,
                  shelf: doc.shelfCode,
                  box: doc.boxNumber,
                  address: doc.address,
                  title: doc.title,
                  mapHeight: 280,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openBorrowDialog(doc);
              },
              icon: const Icon(Icons.local_library_rounded),
              label: const Text(
                'Mượn tài liệu này',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBorrowDialog(RecommendedDocumentModel doc) {
    BorrowRequestDialog.show(
      context,
      documentId: doc.id,
      documentTitle: doc.title,
      ownerId: doc.ownerId,
      storageRoom: doc.storageRoom,
      shelfCode: doc.shelfCode,
      boxNumber: doc.boxNumber,
      address: doc.address,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header phần gợi ý
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade600, Colors.orange.shade700],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gợi ý Tài liệu cho bạn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Dựa trên chủ đề quan tâm & lịch sử mượn tài liệu',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Làm mới gợi ý',
                onPressed: _loadRecommendations,
              ),
            ],
          ),
        ),

        // Nội dung danh sách
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
            SizedBox(height: 10),
            Text(
              'Đang phân tích tags để đề xuất tài liệu...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Không thể tải gợi ý lúc này.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: _loadRecommendations,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.indigo.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chưa có dữ liệu gợi ý. Hãy mượn hoặc xem thêm tài liệu để hệ thống ghi nhận chủ đề bạn yêu thích!',
                style: TextStyle(fontSize: 12, color: Colors.indigo.shade900),
              ),
            ),
          ],
        ),
      );
    }

    // Horizontal Scrollable Cards
    return SizedBox(
      height: 240,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final doc = _recommendations[index];
          return _buildRecommendationCard(doc);
        },
      ),
    );
  }

  Widget _buildRecommendationCard(RecommendedDocumentModel doc) {
    final hasMatched = doc.matchedCount > 0;
    final displayTags = doc.matchedTags.isNotEmpty ? doc.matchedTags : doc.tags;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMatched ? Colors.indigo.shade200 : Colors.grey.shade200,
          width: hasMatched ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasMatched
                ? Colors.indigo.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row nhãn trùng khớp
          Row(
            children: [
              if (hasMatched)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 12, color: Colors.indigo),
                      const SizedBox(width: 4),
                      Text(
                        'Khớp ${doc.matchedCount} thẻ chủ đề',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tài liệu mới',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
              const Spacer(),
              if (doc.hasCoordinates)
                Tooltip(
                  message: 'Có định vị trên bản đồ',
                  child: Icon(Icons.pin_drop, size: 16, color: Colors.red.shade400),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Tiêu đề tài liệu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Vị trí vật lý vắn tắt
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doc.locationSummary,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Tags gợi ý
                if (displayTags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: displayTags.take(3).map((tag) {
                      final isMatchTag = doc.matchedTags.contains(tag);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMatchTag
                              ? Colors.amber.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: isMatchTag
                              ? Border.all(color: Colors.amber.shade400)
                              : null,
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isMatchTag ? FontWeight.bold : FontWeight.normal,
                            color: isMatchTag
                                ? Colors.brown.shade900
                                : Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          const Divider(height: 12),

          // Các nút hành động: "Vị trí" & "Mượn"
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showLocationSheet(doc),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 14),
                      SizedBox(width: 4),
                      Text('Vị trí', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _openBorrowDialog(doc),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_library_outlined, size: 14),
                      SizedBox(width: 4),
                      Text('Mượn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
