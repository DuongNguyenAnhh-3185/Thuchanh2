import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/entities/cloud_document.dart';

/// Hộp thoại xem và cập nhật vị trí lưu trữ thực tế (Phòng, Kệ, Hộp, Tọa độ GPS)
/// Cho phép người dùng chạm trực tiếp trên bản đồ OpenStreetMap để chọn tọa độ mới
class DocumentLocationDialog extends StatefulWidget {
  const DocumentLocationDialog({
    super.key,
    required this.document,
    required this.onSaveLocation,
    this.onBorrow,
  });

  final CloudDocument document;
  final Future<void> Function({
    required String storageRoom,
    required String shelfCode,
    required String boxNumber,
    required String address,
    required double latitude,
    required double longitude,
  }) onSaveLocation;
  final VoidCallback? onBorrow;

  static Future<void> show(
    BuildContext context, {
    required CloudDocument document,
    required Future<void> Function({
      required String storageRoom,
      required String shelfCode,
      required String boxNumber,
      required String address,
      required double latitude,
      required double longitude,
    }) onSaveLocation,
    VoidCallback? onBorrow,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DocumentLocationDialog(
        document: document,
        onSaveLocation: onSaveLocation,
        onBorrow: onBorrow,
      ),
    );
  }

  @override
  State<DocumentLocationDialog> createState() => _DocumentLocationDialogState();
}

class _DocumentLocationDialogState extends State<DocumentLocationDialog> {
  late final MapController _mapController;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _shelfCtrl;
  late final TextEditingController _boxCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  static const LatLng _hanoiDefault = LatLng(21.0285, 105.8542);
  late LatLng _currentPin;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    final doc = widget.document;
    final initialLat = (doc.latitude != null && doc.latitude != 0.0)
        ? doc.latitude!
        : _hanoiDefault.latitude;
    final initialLng = (doc.longitude != null && doc.longitude != 0.0)
        ? doc.longitude!
        : _hanoiDefault.longitude;

    _currentPin = LatLng(initialLat, initialLng);

    _roomCtrl = TextEditingController(text: doc.storageRoom ?? 'Phòng A1');
    _shelfCtrl = TextEditingController(text: doc.shelfCode ?? 'Kệ B2');
    _boxCtrl = TextEditingController(text: doc.boxNumber ?? 'Hộp 01');
    _addressCtrl = TextEditingController(
      text: doc.address?.isNotEmpty == true
          ? doc.address!
          : 'Thư viện Trung tâm, Tòa A',
    );
    _latCtrl = TextEditingController(text: initialLat.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: initialLng.toStringAsFixed(6));
  }

  @override
  void dispose() {
    _mapController.dispose();
    _roomCtrl.dispose();
    _shelfCtrl.dispose();
    _boxCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _currentPin = point;
      _latCtrl.text = point.latitude.toStringAsFixed(6);
      _lngCtrl.text = point.longitude.toStringAsFixed(6);
    });
  }

  void _setDefaultHanoi() {
    setState(() {
      _currentPin = _hanoiDefault;
      _latCtrl.text = _hanoiDefault.latitude.toStringAsFixed(6);
      _lngCtrl.text = _hanoiDefault.longitude.toStringAsFixed(6);
      if (_roomCtrl.text.isEmpty) _roomCtrl.text = 'Phòng A1';
      if (_shelfCtrl.text.isEmpty) _shelfCtrl.text = 'Kệ B2';
      if (_boxCtrl.text.isEmpty) _boxCtrl.text = 'Hộp 01';
      if (_addressCtrl.text.isEmpty) {
        _addressCtrl.text = 'Thư viện Trường Đại học - Hà Nội';
      }
    });
    _mapController.move(_hanoiDefault, 16.0);
  }

  Future<void> _submit() async {
    final lat = double.tryParse(_latCtrl.text.trim()) ?? _hanoiDefault.latitude;
    final lng =
        double.tryParse(_lngCtrl.text.trim()) ?? _hanoiDefault.longitude;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSaveLocation(
        storageRoom: _roomCtrl.text.trim(),
        shelfCode: _shelfCtrl.text.trim(),
        boxNumber: _boxCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật vị trí lưu trữ và tọa độ bản đồ thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Column(
          children: [
            // Header Dialog
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.indigo.shade800,
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Định vị & Bản đồ Vị trí Vật lý',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          doc.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Thân Dialog cuộn được
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hướng dẫn tương tác chạm trên bản đồ
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.touch_app, size: 18, color: Colors.indigo),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chạm bất kỳ đâu trên bản đồ để di chuyển ghim và cập nhật tọa độ GPS tự động.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Khung bản đồ OpenStreetMap
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentPin,
                              initialZoom: 16.0,
                              minZoom: 4.0,
                              maxZoom: 18.5,
                              onTap: (_, point) => _onMapTapped(point),
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'study_doc_manager',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _currentPin,
                                    width: 140,
                                    height: 70,
                                    alignment: Alignment.topCenter,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade900,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _roomCtrl.text.isNotEmpty
                                                ? '${_roomCtrl.text} - ${_shelfCtrl.text}'
                                                : 'Vị trí ghim',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
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

                          // Tọa độ hiện tại ở góc dưới trái
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'GPS: ${_currentPin.latitude.toStringAsFixed(4)}, ${_currentPin.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),

                          // Nút điều khiển bản đồ
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black26, blurRadius: 4),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      _mapController.move(
                                        _mapController.camera.center,
                                        _mapController.camera.zoom + 1,
                                      );
                                    },
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black26, blurRadius: 4),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () {
                                      _mapController.move(
                                        _mapController.camera.center,
                                        _mapController.camera.zoom - 1,
                                      );
                                    },
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black26, blurRadius: 4),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.my_location,
                                        size: 18, color: Colors.indigo),
                                    tooltip: 'Về vị trí ghim',
                                    onPressed: () {
                                      _mapController.move(_currentPin, 16.0);
                                    },
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tiêu đề phần Form cập nhật thông tin
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: Colors.indigo),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Thông tin vị trí lưu kho & Tọa độ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _setDefaultHanoi,
                          icon: const Icon(Icons.gps_fixed, size: 15),
                          label: const Text('Gán mặc định Hà Nội',
                              style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Hàng 1: Phòng & Mã kệ
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _roomCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phòng lưu trữ *',
                              hintText: 'VD: Phòng A1, Kho K2',
                              prefixIcon: Icon(Icons.meeting_room_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _shelfCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mã kệ *',
                              hintText: 'VD: Kệ B2, Kệ 04',
                              prefixIcon: Icon(Icons.shelves),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hàng 2: Số hộp & Địa chỉ
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _boxCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Số hộp lưu trữ',
                              hintText: 'VD: Hộp H01',
                              prefixIcon: Icon(Icons.all_inbox_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Địa chỉ / Cơ sở',
                              hintText: 'VD: Thư viện Tòa A, 144 Xuân Thủy',
                              prefixIcon: Icon(Icons.place_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hàng 3: Tọa độ GPS (Vĩ độ & Kinh độ)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (val) {
                              final lat = double.tryParse(val);
                              if (lat != null) {
                                setState(() {
                                  _currentPin = LatLng(lat, _currentPin.longitude);
                                });
                                _mapController.move(_currentPin, _mapController.camera.zoom);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Vĩ độ (Latitude) *',
                              hintText: '21.0285',
                              prefixIcon: Icon(Icons.explore_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (val) {
                              final lng = double.tryParse(val);
                              if (lng != null) {
                                setState(() {
                                  _currentPin = LatLng(_currentPin.latitude, lng);
                                });
                                _mapController.move(_currentPin, _mapController.camera.zoom);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Kinh độ (Longitude) *',
                              hintText: '105.8542',
                              prefixIcon: Icon(Icons.explore_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  if (!doc.isOwner && widget.onBorrow != null) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onBorrow?.call();
                      },
                      icon: const Icon(Icons.local_library_outlined, size: 16),
                      label: const Text('Đăng ký mượn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                        side: BorderSide(color: Colors.green.shade400),
                      ),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_isSaving ? 'Đang lưu...' : 'Lưu vị trí'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
