import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  static const String _transferNotificationKey = 'pending_transfer_notification';

  // Local Offline Notification Trigger
  static Future<void> saveTransferNotificationLocally(String targetMadiya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_transferNotificationKey, targetMadiya);
  }

  static Future<void> checkAndShowTransferNotification(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final targetMadiya = prefs.getString(_transferNotificationKey);

    if (targetMadiya != null) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ ማሳሰቢያ'),
            content: Text('ወደ $targetMadiya ማዲያ ተዛውረዋል!'),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.remove(_transferNotificationKey);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('እሺ'),
              ),
            ],
          ),
        );
      }
    }
  }

  // SMS Notification Gateway Integration
  static Future<void> sendTransferSMS(String phoneNumber, String targetMadiya, {String? driverName}) async {
    final String name = driverName ?? "ሹፌር";
    final String message = "ሰላም $name፣ ከምድብ ማዲያ ወደ $targetMadiya በሰላም ተዛውረዋል። እባክዎ በተመደበልዎት ሰዓት ይገኙ።";

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        debugPrint("Could not launch SMS app");
      }
    } catch (e) {
      debugPrint("Error launching SMS: $e");
    }

    debugPrint("----------------------------------------");
    debugPrint("SMS GATEWAY TRIGGERED");
    debugPrint("TO: $phoneNumber");
    debugPrint("MESSAGE: $message");
    debugPrint("----------------------------------------");
  }

  // Station Admin Notifications
  static Future<void> notifyStationAdminOfBulkTransfer(String targetStation, int count) async {
    final prefs = await SharedPreferences.getInstance();
    // We store this for the station admin to see when they open their app
    await prefs.setString('station_admin_notif_$targetStation',
      "አዲስ ማሳወቂያ: $count ቁጥር ያላቸው ተሽከርካሪዎች ከሌላ ማዲያ ወደ እርስዎ ማዲያ ተዛውረው ተመድበዋል!");
  }

  static Future<String?> getStationAdminNotification(String station) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('station_admin_notif_$station');
  }

  static Future<void> clearStationAdminNotification(String station) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('station_admin_notif_$station');
  }
}
