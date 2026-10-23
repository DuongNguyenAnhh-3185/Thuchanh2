import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/document_location_map.dart';

class LocationMapButton extends StatelessWidget {
  const LocationMapButton({
    super.key,
    required this.location,
    this.latitude,
    this.longitude,
  });

  final String location;
  final double? latitude;
  final double? longitude;

  Future<void> _openMap(BuildContext context) async {
    final hasCoordinates = latitude != null && longitude != null;
    if (hasCoordinates) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentLocationMap(
            location: location,
            latitude: latitude!,
            longitude: longitude!,
          ),
        ),
      );
      return;
    }
    final uri = hasCoordinates
        ? Uri.parse(
            'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude'
            '#map=17/$latitude/$longitude',
          )
        : Uri.https('www.openstreetmap.org', '/search', {'query': location});

    if (!await launchUrl(uri, mode: LaunchMode.platformDefault) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở bản đồ trên thiết bị này.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (location.trim().isEmpty && (latitude == null || longitude == null)) {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      onPressed: () => _openMap(context),
      icon: const Icon(Icons.map_outlined),
      label: const Text('Mở bản đồ'),
    );
  }
}
