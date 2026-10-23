import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentLocationMap extends StatelessWidget {
  const DocumentLocationMap({
    super.key,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  final String location;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('Vị trí tài liệu')),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(location.isEmpty ? 'Vị trí đã ghim' : location),
            subtitle: Text('$latitude, $longitude'),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.study_doc_manager',
                  maxNativeZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        size: 48,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
