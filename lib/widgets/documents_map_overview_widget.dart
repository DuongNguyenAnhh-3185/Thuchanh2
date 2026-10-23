import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/entities/cloud_document.dart';

/// Widget Bản đồ Tổng quan hiển thị vị trí vật lý của tất cả tài liệu
/// Sử dụng `flutter_map` và OpenStreetMap (không cần API Key, chạy mượt trên Web & Mobile)
class DocumentsMapOverviewWidget extends StatefulWidget {
  const DocumentsMapOverviewWidget({
    super.key,
    required this.documents,
    this.onViewDocument,
    this.onEditLocation,
    this.onBorrowDocument,
    this.onAssignDefaultLocations,
  });

  final List<CloudDocument> documents;
  final ValueChanged<CloudDocument>? onViewDocument;
  final ValueChanged<CloudDocument>? onEditLocation;
  final ValueChanged<CloudDocument>? onBorrowDocument;
  final VoidCallback? onAssignDefaultLocations;

  @override
  State<DocumentsMapOverviewWidget> createState() =>
      _DocumentsMapOverviewWidgetState();
}

class _DocumentsMapOverviewWidgetState
    extends State<DocumentsMapOverviewWidget> {
  late final MapController _mapController;
  CloudDocument? _selectedDocument;
  final TextEditingController _searchFilter = TextEditingController();
  final String _filterKeyword = '';

  // Tọa độ mặc định: Trung tâm Hà Nội (Trường Đại học / Thư viện)
  static const LatLng _hanoiDefault = LatLng(21.0285, 105.8542);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final withCoords = _documentsWithCoordinates;
    if (withCoords.isNotEmpty) {
      _selectedDocument = withCoords.first;
    }
  }

  @override
  void dispose() {
    _searchFilter.dispose();
    _mapController.dispose();
    super.dispose();
  }

  List<CloudDocument> get _documentsWithCoordinates {
    return widget.documents.where((doc) {
      final hasCoords = doc.latitude != null &&
          doc.longitude != null &&
          doc.latitude != 0.0 &&
          doc.longitude != 0.0;
      if (!hasCoords) return false;
      if (_filterKeyword.trim().isEmpty) return true;
      final q = _filterKeyword.trim().toLowerCase();
      return doc.title.toLowerCase().contains(q) ||
          (doc.storageRoom?.toLowerCase().contains(q) ?? false) ||
          (doc.shelfCode?.toLowerCase().contains(q) ?? false) ||
          (doc.address?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<CloudDocument> get _documentsWithoutCoordinates {
    return widget.documents.where((doc) {
      return doc.latitude == null ||
          doc.longitude == null ||
          doc.latitude == 0.0 ||
          doc.longitude == 0.0;
    }).toList();
  }

  LatLng get _initialCenter {
    final withCoords = _documentsWithCoordinates;
    if (withCoords.isNotEmpty) {
      return LatLng(withCoords.first.latitude!, withCoords.first.longitude!);
    }
    return _hanoiDefault;
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _recenterToAll() {
    final list = _documentsWithCoordinates;
    if (list.isEmpty) {
      _mapController.move(_hanoiDefault, 14.0);
      return;
    }

    if (list.length == 1) {
      _mapController.move(
        LatLng(list.first.latitude!, list.first.longitude!),
        16.0,
      );
      return;
    }

    double minLat = list.first.latitude!;
    double maxLat = list.first.latitude!;
    double minLng = list.first.longitude!;
    double maxLng = list.first.longitude!;

    for (final doc in list) {
      if (doc.latitude! < minLat) minLat = doc.latitude!;
      if (doc.latitude! > maxLat) maxLat = doc.latitude!;
      if (doc.longitude! < minLng) minLng = doc.longitude!;
      if (doc.longitude! > maxLng) maxLng = doc.longitude!;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 13.5);
  }

  void _focusDocument(CloudDocument doc) {
    setState(() => _selectedDocument = doc);
    if (doc.latitude != null && doc.longitude != null) {
      _mapController.move(LatLng(doc.latitude!, doc.longitude!), 16.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final withCoords = _documentsWithCoordinates;
    final withoutCoords = _documentsWithoutCoordinates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thanh công cụ & Thông tin thống kê
        _buildTopHeader(withCoords.length, withoutCoords.length),
        const SizedBox(height: 8),

        // Danh sách tài liệu dạng chip ngang để định vị nhanh
        if (withCoords.isNotEmpty) ...[
          _buildQuickSelectorBar(withCoords),
          const SizedBox(height: 8),
        ],

        // Khung Bản đồ lớn OpenStreetMap
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 14.5,
                    minZoom: 3.0,
                    maxZoom: 18.5,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onTap: (_, __) {
                      // Không bắt buộc phải đóng card nếu người dùng muốn giữ xem
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'study_doc_manager',
                    ),
                    MarkerLayer(
                      markers: withCoords.map((doc) {
                        final isSelected = _selectedDocument?.id == doc.id;
                        final point = LatLng(doc.latitude!, doc.longitude!);
                        return Marker(
                          point: point,
                          width: isSelected ? 160 : 130,
                          height: isSelected ? 80 : 70,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _focusDocument(doc),
                            child: _buildMapMarker(doc, isSelected),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Nút điều khiển bản đồ góc trên bên phải
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      _buildMapBtn(
                        icon: Icons.add,
                        tooltip: 'Phóng to',
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 6),
                      _buildMapBtn(
                        icon: Icons.remove,
                        tooltip: 'Thu nhỏ',
                        onTap: _zoomOut,
                      ),
                      const SizedBox(height: 6),
                      _buildMapBtn(
                        icon: Icons.filter_center_focus,
                        tooltip: 'Xem toàn bộ ghim',
                        onTap: _recenterToAll,
                        color: Colors.indigo,
                      ),
                    ],
                  ),
                ),

                // Tọa độ GPS góc dưới bên trái
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.indigo),
                        const SizedBox(width: 4),
                        Text(
                          'Định vị OpenStreetMap · ${withCoords.length} tài liệu đã ghim',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Card chi tiết tài liệu khi bấm vào ghim Marker
                if (_selectedDocument != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 44,
                    child: _buildSelectedDocumentCard(_selectedDocument!),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopHeader(int withCoordsCount, int withoutCoordsCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.map_outlined, color: Colors.indigo, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bản đồ vị trí tài liệu vật lý (GPS & Kho lưu trữ)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Đang ghim $withCoordsCount tài liệu trên bản đồ'
                  '${withoutCoordsCount > 0 ? ' ($withoutCoordsCount tài liệu chưa có GPS)' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (withoutCoordsCount > 0 && widget.onAssignDefaultLocations != null)
            FilledButton.tonalIcon(
              onPressed: widget.onAssignDefaultLocations,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Gán tọa độ mẫu', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickSelectorBar(List<CloudDocument> list) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final doc = list[index];
          final isSelected = _selectedDocument?.id == doc.id;
          return ActionChip(
            avatar: Icon(
              Icons.location_on,
              size: 15,
              color: isSelected ? Colors.white : Colors.indigo,
            ),
            label: Text(
              doc.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor:
                isSelected ? Colors.indigo : Colors.indigo.shade50,
            side: BorderSide(
              color: isSelected ? Colors.indigo : Colors.indigo.shade200,
            ),
            onPressed: () => _focusDocument(doc),
          );
        },
      ),
    );
  }

  Widget _buildMapMarker(CloudDocument doc, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade900 : Colors.indigo.shade700,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.amberAccent : Colors.white,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (doc.storageRoom != null && doc.storageRoom!.isNotEmpty) ...[
                Text(
                  doc.storageRoom!,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  doc.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.location_on,
          color: isSelected ? Colors.redAccent : Colors.red.shade700,
          size: isSelected ? 40 : 34,
        ),
      ],
    );
  }

  Widget _buildSelectedDocumentCard(CloudDocument doc) {
    final room = doc.storageRoom?.isNotEmpty == true ? doc.storageRoom! : 'Chưa rõ';
    final shelf = doc.shelfCode?.isNotEmpty == true ? doc.shelfCode! : 'Chưa rõ';
    final box = doc.boxNumber?.isNotEmpty == true ? doc.boxNumber! : 'Chưa rõ';
    final address = doc.address?.isNotEmpty == true
        ? doc.address!
        : 'Thư viện cơ sở chính';

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.indigo, width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'GPS: ${doc.latitude?.toStringAsFixed(4)}, ${doc.longitude?.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Ẩn card',
                  onPressed: () => setState(() => _selectedDocument = null),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dải 3 thẻ: Phòng - Kệ - Hộp
            Row(
              children: [
                Expanded(
                  child: _buildMiniBadge(
                    icon: Icons.meeting_room_outlined,
                    label: 'Phòng',
                    value: room,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniBadge(
                    icon: Icons.shelves,
                    label: 'Kệ',
                    value: shelf,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniBadge(
                    icon: Icons.all_inbox_outlined,
                    label: 'Hộp',
                    value: box,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dòng địa chỉ
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Các nút thao tác
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onEditLocation?.call(doc),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: const Text('Xem & Sửa vị trí', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (!doc.isOwner && widget.onBorrowDocument != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => widget.onBorrowDocument?.call(doc),
                    icon: const Icon(Icons.local_library_outlined, size: 16),
                    label: const Text('Đăng ký mượn', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color.shade700),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
