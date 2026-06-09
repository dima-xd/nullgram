import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a `MessageLocation` or `MessageVenue` as a tappable card.
///
/// A plain location shows its coordinates; a venue shows its name and address.
/// Tapping opens the point in an external maps app via a `geo:` URI, falling
/// back to a Google Maps web link.
class MessageLocation extends StatelessWidget {
  final Map<String, dynamic> content;

  const MessageLocation({super.key, required this.content});

  /// The `{latitude, longitude}` map, read from either a location or a venue.
  Map<String, dynamic>? get _location {
    final venue = content['venue'] as Map<String, dynamic>?;
    if (venue != null) return venue['location'] as Map<String, dynamic>?;
    return content['location'] as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = _location;
    if (location == null) return const SizedBox.shrink();

    final latitude = (location['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (location['longitude'] as num?)?.toDouble() ?? 0;
    final venue = content['venue'] as Map<String, dynamic>?;

    final title = venue?['title'] as String? ?? 'Location';
    final subtitle = venue?['address'] as String? ??
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

    return InkWell(
      onTap: () => _open(latitude, longitude, venue?['title'] as String?),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on, color: scheme.onPrimary),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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

  Future<void> _open(double latitude, double longitude, String? label) async {
    final coords = '$latitude,$longitude';
    final query = label == null ? coords : '$coords($label)';
    final geo = Uri.parse('geo:$coords?q=$query');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    final web = Uri.parse('https://maps.google.com/?q=$coords');
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}
