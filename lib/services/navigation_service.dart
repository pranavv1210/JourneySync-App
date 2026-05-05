import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';

/// Service for handling external navigation (Google Maps)
class NavigationService {
  /// Opens Google Maps with directions to the specified destination
  ///
  /// [lat] - Destination latitude
  /// [lng] - Destination longitude
  /// [label] - Optional label for the destination (e.g., ride destination name)
  static Future<void> openGoogleMaps(
    double lat,
    double lng, {
    String? label,
  }) async {
    // Build the Google Maps directions URL
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Try opening Google Maps app directly with geo scheme
        final appUrl = Uri.parse(
          'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
        );
        if (await canLaunchUrl(appUrl)) {
          await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
      // Error will be handled by caller
      rethrow;
    }
  }

  /// Opens Google Maps with navigation to a destination from the current location
  ///
  /// [context] - BuildContext for showing toast messages
  /// [lat] - Destination latitude
  /// [lng] - Destination longitude
  /// [destinationName] - Name of the destination for display
  static Future<void> navigateToDestination(
    BuildContext context,
    double lat,
    double lng, {
    String? destinationName,
  }) async {
    try {
      await openGoogleMaps(lat, lng, label: destinationName);
    } catch (e) {
      if (context.mounted) {
        showAppToast(
          context,
          'Could not open navigation. Please check if Google Maps is installed.',
          type: AppToastType.error,
        );
      }
    }
  }
}
