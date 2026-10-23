import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Widget hiển thị thông tin vị trí lưu trữ thực tế (Phòng, Kệ, Hộp)
/// và Bản đồ tương tác OpenStreetMap ghim tọa độ GPS bằng `flutter_map`
class DocumentLocationWidget extends StatefulWidget {
  const DocumentLocationWidget({
    super.key,
    this.latitude,
    this.longitude,
    String? room,
    String? shelf,
    String? box,
    String? storageRoom,
    String? shelfCode,
    String? boxNumber,
    this.address,
    this.title,
    this.mapHeight = 260.0,
    this.showLocationCard = true,
  })  : room = room ?? storageRoom,
        shelf = shelf ?? shelfCode,
        box = box ?? boxNumber;

  final double? latitude;
  final double? longitude;
  final String? room;
  final String? shelf;
  final String? box;
  final String? address;
  final String? title;
  final double mapHeight;
  final bool showLocationCard;

  @override
  State<DocumentLocationWidget> createState() => _DocumentLocationWidgetState();
}

class _DocumentLocationWidgetState extends State<DocumentLocationWidget> {
  late final MapController _mapController;

  bool get _hasValidCoordinates =>
      widget.latitude != null &&
      widget.longitude != null &&
      widget.latitude != 0.0 &&
      widget.longitude != 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _recenter() {
    if (_hasValidCoordinates) {
      _mapController.move(
        LatLng(widget.latitude!, widget.longitude!),
        16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLocationCard) ...[
          _buildPhysicalLocationCard(context),
          const SizedBox(height: 12),
        ],
        _buildMapSection(context),
      ],
    );
  }

  /// Card thông tin vị trí vật lý chi tiết: Phòng, Kệ, Hộp, Địa chỉ
  Widget _buildPhysicalLocationCard(BuildContext context) {
    final theme = Theme.of(context);
    final hasDetails = (widget.room != null && widget.room!.isNotEmpty) ||
        (widget.shelf != null && widget.shelf!.isNotEmpty) ||
        (widget.box != null && widget.box!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.indigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vị trí lưu trữ thực tế',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    Text(
                      hasDetails
                          ? 'Định vị kho lưu trữ tài liệu bản cứng'
                          : 'Chưa cập nhật thông tin vị trí lưu kho',
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
          const SizedBox(height: 14),
          // 3 Thẻ thông tin: Phòng / Kệ / Hộp
          Row(
            children: [
              Expanded(
                child: _buildLocationBadge(
                  icon: Icons.meeting_room_outlined,
                  label: 'Phòng',
                  value: widget.room?.isNotEmpty == true ? widget.room! : 'Chưa rõ',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationBadge(
                  icon: Icons.shelves,
                  label: 'Mã kệ',
                  value: widget.shelf?.isNotEmpty == true ? widget.shelf! : 'Chưa rõ',
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationBadge(
                  icon: Icons.all_inbox_outlined,
                  label: 'Số hộp',
                  value: widget.box?.isNotEmpty == true ? widget.box! : 'Chưa rõ',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          if (widget.address != null && widget.address!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.address!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationBadge({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.shade800),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
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

  /// Khung Bản đồ OpenStreetMap sử dụng `flutter_map`
  Widget _buildMapSection(BuildContext context) {
    if (!_hasValidCoordinates) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Tài liệu này chưa được cấu hình tọa độ GPS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cần cập nhật Latitude & Longitude để hiển thị trên bản đồ',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    final targetPoint = LatLng(widget.latitude!, widget.longitude!);

    return Container(
      height: widget.mapHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: targetPoint,
              initialZoom: 16.0,
              minZoom: 4.0,
              maxZoom: 18.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'study_doc_manager',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: targetPoint,
                    width: 140,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade900,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.title ?? 'Vị trí tài liệu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 38,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tọa độ GPS hiển thị góc trái dưới
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Text(
                'GPS: ${widget.latitude!.toStringAsFixed(4)}, ${widget.longitude!.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Các nút điều khiển bản đồ góc phải trên
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.add,
                  tooltip: 'Phóng to',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.remove,
                  tooltip: 'Thu nhỏ',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.my_location,
                  tooltip: 'Về vị trí ghim',
                  onTap: _recenter,
                  iconColor: Colors.indigo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = Colors.black87,
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
        icon: Icon(icon, size: 20, color: iconColor),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
