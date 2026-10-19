import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  static Future<void> callNumber(BuildContext context, String rawNumber) async {
    final cleanNumber = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open phone dialer for $rawNumber')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching phone dialer: $e')),
        );
      }
    }
  }

  static Future<void> openMapDirections(
    BuildContext context,
    String query, {
    double? lat,
    double? lng,
  }) async {
    final hasCoords = lat != null && lng != null;
    final webUri = hasCoords
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
          );

    try {
      if (!kIsWeb && hasCoords) {
        final geoUri = Uri.parse(
          'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(query)})',
        );
        if (await canLaunchUrl(geoUri)) {
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening directions: $e')),
        );
      }
    }
  }
}
