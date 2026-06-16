import 'package:flutter/material.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'models/activity_log.dart';
import 'models/driver.dart';
import 'models/transfer_history.dart';

// Note: Using external SupabaseService from services/supabase_service.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const SmartMadiyaApp());
}

class SmartMadiyaApp extends StatelessWidget {
  static const String currentCity = 'ሀዋሳ'; // Configuration: 'ሀዋሳ' or 'ሻሸመኔ'

  const SmartMadiyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'የ$currentCity ስማርት ማዲያ ትራንስፖርት',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const MainSystemNavigation(),
    );
  }
}

class MainSystemNavigation extends StatefulWidget {
  const MainSystemNavigation({super.key});

  @override
  State<MainSystemNavigation> createState() => _MainSystemNavigationState();
}

class _MainSystemNavigationState extends State<MainSystemNavigation> {
  int _currentView = 0; // 0: User View, 1: Admin View
  int _userNavIndex = 0;
  int _adminNavIndex = 0;

  bool _isAdminLoggedIn = false;
  String _currentRole = ""; // "SUPER_ADMIN" ወይም "REGULAR_ADMIN"
  String _adminAssignedStation = "";

  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _transferHistory = [];
  List<ActivityLog> _activityLogs = [];
  List<Map<String, dynamic>> _announcements = [];
  Map<String, int> _stats = {
    'total_drivers': 0,
    'pending_requests': 0,
    'total_transfers': 0,
  };

  String _adTitle = 'የማስታወቂያ ሰሌዳ';
  String _adDescription =
      'ለድርጅትዎ ወይም ለአገልግሎትዎ እዚህ ላይ ያስታውቁ! በሁሉም ሹፌሮች ስልክ ላይ በፍጥነት ይድረሱ።';
  XFile? _adImage;

  final List<String> _officialVehicleTypes = [
    "የመንግስት መኪና",
    "የመንግስት ሞተር",
    "የግል መኪና",
    "የግል ሞተር",
    "ባጃጅ",
    "ኩዪት",
    "ዳማስ",
    "ምንባስ",
    "የጭነት መኪና",
  ];

  final List<String> _officialMadiyaStations = [
    "ቶታል ማንሃርያ",
    "ኖ1",
    "ኖክ 2",
    "የተባበሩት ዳቶ",
    "ግራን ጋማጦ",
    "የተባበሩት ሞኖፖልይ",
    "ሃበሻ",
    "ታፈ",
    "አይሊ ሊብያ ጥቁር ዉሃ",
    "ቶታል ፒያሳ",
    "ግሎባል",
    "ተባረክ",
    "አይል ሊብያ መናሃሪያ",
    "ቶታል ሞብል",
    "አዲስ 1",
    "አድስ 2",
    "አድስ 3",
    "አድስ 4",
    "አድስ 5",
    "አቶቴ",
  ];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _loadTransferHistory();
    _loadActivityLogs();
    _loadAnnouncements();
    _loadStatistics();
    _subscribeToRealtime();

    // Check for offline/pending notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.checkAndShowTransferNotification(context);
      _showAppLaunchAnnouncement();
    });
  }

  void _showAppLaunchAnnouncement() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.teal),
            const SizedBox(width: 10),
            Text(_adTitle),
          ],
        ),
        content: Text(_adDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('እሺ'),
          ),
        ],
      ),
    );
  }

  void _checkStationAdminNotifs() async {
    if (_currentRole == "REGULAR_ADMIN") {
      final msg = await NotificationService.getStationAdminNotification(_adminAssignedStation);
      if (msg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.blue.shade800,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'እሺ',
              textColor: Colors.white,
              onPressed: () => NotificationService.clearStationAdminNotification(_adminAssignedStation),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final response = await SupabaseService.client
          .from('drivers')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _drivers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Error loading drivers: $e");
    }
  }

  Future<void> _loadTransferHistory() async {
    try {
      final response = await SupabaseService.client
          .from('transfer_history')
          .select()
          .order('transferred_at', ascending: false);
      setState(() {
        _transferHistory = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Error loading transfer history: $e");
    }
  }

  Future<void> _loadActivityLogs() async {
    try {
      final logs = await SupabaseService.fetchActivityLogs();
      setState(() {
        _activityLogs = logs;
      });
    } catch (e) {
      debugPrint("Error loading activity logs: $e");
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      final data = await SupabaseService.fetchAnnouncements();
      setState(() {
        _announcements = data;
      });
    } catch (e) {
      debugPrint("Error loading announcements: $e");
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final data = await SupabaseService.fetchStatistics();
      setState(() {
        _stats = data;
      });
    } catch (e) {
      debugPrint("Error loading statistics: $e");
    }
  }

  void _subscribeToRealtime() {
    SupabaseService.client.from('drivers').stream(primaryKey: ['id']).listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _drivers = List<Map<String, dynamic>>.from(data);
        });
        _loadStatistics();
      }
    });

    SupabaseService.announcementsStream().listen((data) {
      if (mounted) {
        setState(() {
          _announcements = data;
        });
      }
    });

    SupabaseService.transferHistoryStream().listen((data) {
      if (mounted) {
        // Live Notification System
        if (_transferHistory.isNotEmpty && data.length > _transferHistory.length) {
          final newTransfer = data.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📣 አዲስ ዝውውር፡ ${newTransfer.fromMadiya} ➔ ${newTransfer.toMadiya}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.blue.shade900,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        setState(() {
          _transferHistory = data.map((e) => {
            'id': e.id,
            'driver_id': e.driverId,
            'driver_name': e.driverName,
            'plate': e.plate,
            'from_madiya': e.fromMadiya,
            'to_madiya': e.toMadiya,
            'transferred_by': e.transferredBy,
            'transferred_at': e.transferredAt.toIso8601String(),
          }).toList();
        });
        _loadStatistics();
      }
    });

    // Activity Logs Realtime Stream
    SupabaseService.activityLogsStream().listen((data) {
      if (mounted) {
        setState(() {
          _activityLogs = data;
        });
      }
    });
  }

  Future<void> _addDriver(Map<String, dynamic> driver) async {
    try {
      await SupabaseService.addDriver(driver);

      // Log Booking
      await SupabaseService.logActivity(ActivityLog(
        actionType: 'Booking',
        performedBy: 'Public User',
        vehiclePlate: driver['plate'],
        details: 'New registration for ${driver['name']}',
      ));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ምዝገባዎ በተካሳ ሁኔታ ተልኳል!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ስህተት: ${e.toString()}')));
    }
  }

  Future<void> _approveDriver(
    String driverId,
    String day,
    String timeSlot,
  ) async {
    try {
      await SupabaseService.updateDriver(driverId, {
        'status': 'Approved',
        'day': day,
        'time_slot': timeSlot,
        'live_status': 'Waiting',
      });

      final driver = _drivers.firstWhere((d) => d['id'] == driverId);

      // Log Approval
      await SupabaseService.logActivity(ActivityLog(
        actionType: 'Approval',
        performedBy: '$_currentRole ($_adminAssignedStation)',
        vehiclePlate: driver['plate'],
        details: 'Driver approved for $day $timeSlot',
      ));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ተሽከርካሪ ጸድቋል!')));
      _loadDrivers(); // Force refresh
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ስህተት: ${e.toString()}')));
    }
  }

  Future<void> _updateLiveStatus(String driverId, String newStatus) async {
    try {
      await SupabaseService.updateDriver(driverId, {'live_status': newStatus});

      final driver = _drivers.firstWhere((d) => d['id'] == driverId);
      // Log Status Update
      await SupabaseService.logActivity(ActivityLog(
        actionType: 'Status Update',
        performedBy: '$_currentRole ($_adminAssignedStation)',
        vehiclePlate: driver['plate'],
        details: 'Status changed to $newStatus',
      ));
    } catch (e) {
      debugPrint("Error updating live status: $e");
    }
  }

  Future<void> _bulkTransfer(
    List<String> driverIds,
    String fromMadiya,
    String toMadiya,
    String transferredBy,
  ) async {
    if (_currentRole != "SUPER_ADMIN") return;

    try {
      await SupabaseService.bulkUpdateDriversMadiya(driverIds, toMadiya);

      // Notify Station Admin
      await NotificationService.notifyStationAdminOfBulkTransfer(toMadiya, driverIds.length);

      for (var id in driverIds) {
        // Correctly capture driver details from the local state
        final driverData = _drivers.firstWhere(
          (d) => d['id'].toString() == id.toString(),
          orElse: () => {},
        );

        final String selectedDriverName = driverData['name']?.toString() ?? 'Unknown';
        final String selectedPlateNumber = driverData['plate']?.toString() ?? 'Unknown';
        final String driverPhone = driverData['phone']?.toString() ?? '';

        await SupabaseService.addTransferRecord({
          'driver_id': id,
          'driver_name': selectedDriverName,
          'plate': selectedPlateNumber,
          'from_madiya': fromMadiya,
          'to_madiya': toMadiya,
          'transferred_by': transferredBy,
        });

        // Log Individual Activity for the Audit Log
        await SupabaseService.logActivity(ActivityLog(
          actionType: 'Bulk Transfer',
          performedBy: transferredBy,
          stationId: fromMadiya,
          vehiclePlate: selectedPlateNumber,
          details: 'Transferred $selectedDriverName ($selectedPlateNumber) to $toMadiya',
        ));

        // Trigger SMS hook (using captured data)
        try {
           await NotificationService.sendTransferSMS(
             driverPhone,
             toMadiya,
             driverName: selectedDriverName,
           );
           // Save locally for that driver
           await NotificationService.saveTransferNotificationLocally(toMadiya);
        } catch (_) {}
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${driverIds.length} ተሽከርካሪዎች ከ $fromMadiya ወደ $toMadiya ተዛውረዋል'),
          backgroundColor: Colors.green,
        ),
      );

      // Force refresh data
      await _loadTransferHistory();
      await _loadActivityLogs();
      await _loadDrivers();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ስህተት: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentView == 0
              ? 'የ${SmartMadiyaApp.currentCity} ከተማ ስማርት ማዲያ'
              : (!_isAdminLoggedIn
                    ? 'የአድሚን መግቢያ መድረክ'
                    : (_currentRole == "SUPER_ADMIN"
                          ? '👑 ሱፐር አድሚን ማዕከል (20 ጣቢያ)'
                          : (_currentRole == "AD_OWNER"
                                ? '📢 የማስታወቂያ መቆጣጠሪያ'
                                : '🏢 ማዲያ አድሚን ($_adminAssignedStation)'))),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        backgroundColor: _currentView == 0
            ? Colors.teal
            : (!_isAdminLoggedIn
                  ? Colors.blueGrey.shade700
                  : (_currentRole == "SUPER_ADMIN"
                        ? Colors.purple.shade900
                        : Colors.blueGrey.shade900)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_currentView == 1 && _isAdminLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.amber),
              onPressed: () {
                setState(() {
                  _isAdminLoggedIn = false;
                  _currentRole = "";
                  _adminAssignedStation = "";
                  _currentView = 0;
                  _adminNavIndex = 0;
                });
              },
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: _currentView == 0
                    ? Colors.teal
                    : Colors.blueGrey.shade900,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ስማርት ማዲያ ቁጥጥር',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ባለብዙ ደረጃ የአድሚን ሲስተም v3.0',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.teal),
              title: const Text('የህዝብ/የሾፌሮች ገጽ (User View)'),
              selected: _currentView == 0,
              onTap: () {
                setState(() => _currentView = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_open, color: Colors.amber),
              title: const Text('የአድሚን መግቢያ (Admin Panel)'),
              selected: _currentView == 1,
              onTap: () {
                setState(() => _currentView = 1);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _currentView == 0
          ? _buildUserSide()
          : (_isAdminLoggedIn
                ? _buildAdminSide()
                : AdminLoginScreen(
                    madiyas: _officialMadiyaStations,
                    onLoginSuccess: (role, station) {
                      setState(() {
                        _isAdminLoggedIn = true;
                        _currentRole = role;
                        _adminAssignedStation = station;
                      });
                      _checkStationAdminNotifs();
                    },
                  )),
    );
  }

  Widget _buildUserSide() {
    final List<Widget> userScreens = [
      UserPortalHomeScreen(
        onNavigate: (index) => setState(() => _userNavIndex = index),
        adTitle: _adTitle,
        adDescription: _adDescription,
        adImage: _adImage,
        announcements: _announcements,
      ),
      DriverRegistrationScreen(
        onRegister: _addDriver,
        drivers: _drivers,
        vehicles: _officialVehicleTypes,
        madiyas: _officialMadiyaStations,
      ),
      UserAppointmentScreen(drivers: _drivers),
      LiveAppointmentDashboard(
        drivers: _drivers,
        currentMadiya: "ALL",
        isAdminMode: false,
        onStatusChanged: null,
      ),
    ];

    return Scaffold(
      body: userScreens[_userNavIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _userNavIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _userNavIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'መነሻ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.app_registration),
            label: 'ምዝገባ',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'ቀጠሮ ፍተሻ'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'ቀጥታ ሰሌዳ'),
        ],
      ),
    );
  }

  Widget _buildAdminSide() {
    List<Map<String, dynamic>> filteredDrivers = _drivers;
    if (_currentRole == "REGULAR_ADMIN") {
      filteredDrivers = _drivers
          .where((d) => d['madiya'] == _adminAssignedStation)
          .toList();
    }

    final List<Widget> adminScreens = [];
    final List<BottomNavigationBarItem> navItems = [];

    if (_currentRole == "REGULAR_ADMIN") {
      adminScreens.addAll([
        AdminDashboardScreen(
          drivers: _drivers,
          filteredDrivers: filteredDrivers,
          role: _currentRole,
          station: _adminAssignedStation,
          onApproved: _approveDriver,
          stats: _stats,
        ),
        LiveAppointmentDashboard(
          drivers: filteredDrivers,
          currentMadiya: _adminAssignedStation,
          isAdminMode: false,
          onStatusChanged: _updateLiveStatus,
        ),
        QrScanVerificationScreen(drivers: filteredDrivers),
      ]);
      navItems.addAll([
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'ዳሽቦርድ'),
        const BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'ቀጥታ መቆጣጠሪያ'),
        const BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'QR ፍተሻ'),
      ]);
    } else if (_currentRole == "SUPER_ADMIN") {
      adminScreens.addAll([
        AdminDashboardScreen(
          drivers: _drivers,
          filteredDrivers: _drivers,
          role: _currentRole,
          station: "ALL",
          onApproved: _approveDriver,
          stats: _stats,
        ),
        VehicleTransferScreen(
          drivers: _drivers,
          history: _transferHistory,
          madiyas: _officialMadiyaStations,
          role: _currentRole,
          station: _adminAssignedStation,
          onBulkTransfer: _bulkTransfer,
        ),
        TransferHistoryEntryScreen(logs: _activityLogs),
        AllUserRegistryScreen(drivers: _drivers),
      ]);
      navItems.addAll([
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'ዳሽቦርድ'),
        const BottomNavigationBarItem(icon: Icon(Icons.move_down), label: 'ጣቢያ ማዛወሪያ'),
        const BottomNavigationBarItem(icon: Icon(Icons.history_edu), label: 'ዝውውር ታሪክ'),
        const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'ተጠቃሚዎች'),
      ]);
    } else if (_currentRole == "AD_OWNER") {
      return AdManagementScreen(
        currentTitle: _adTitle,
        currentDesc: _adDescription,
        onUpdate: (title, desc, image) {
          setState(() {
            _adTitle = title;
            _adDescription = desc;
            _adImage = image;
          });
        },
      );
    }

    if (adminScreens.isEmpty) return const Center(child: Text("ምንም ገጽ አልተገኘም"));

    return Scaffold(
      body: adminScreens[_adminNavIndex >= adminScreens.length ? 0 : _adminNavIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _adminNavIndex >= adminScreens.length ? 0 : _adminNavIndex,
        selectedItemColor: _currentRole == "SUPER_ADMIN"
            ? Colors.purple
            : (_currentRole == "AD_OWNER" ? Colors.orange.shade900 : Colors.blueGrey.shade900),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _adminNavIndex = i),
        items: navItems,
      ),
    );
  }
}

// ==========================================
// 📢 AD MANAGEMENT PANEL (Ad Owner Only)
// ==========================================
class AdManagementScreen extends StatefulWidget {
  final String currentTitle;
  final String currentDesc;
  final Function(String, String, XFile?) onUpdate;

  const AdManagementScreen({
    super.key,
    required this.currentTitle,
    required this.currentDesc,
    required this.onUpdate,
  });

  @override
  State<AdManagementScreen> createState() => _AdManagementScreenState();
}

class _AdManagementScreenState extends State<AdManagementScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _descController = TextEditingController(text: widget.currentDesc);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'የማስታወቂያዎች ማስተዳደሪያ (Ad Management)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ለባነር ፎቶ መመሪያ፡ እባክዎ 16:9 Aspect Ratio (ለምሳሌ 1600x900) የሆነ ፎቶ ይጠቀሙ።',
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: FileImage(File(_selectedImage!.path)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'የማስታወቂያ ርዕስ (Title)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration:
                const InputDecoration(labelText: 'የማስታወቂያ ዝርዝር (Description)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.upload_file),
            label: const Text('አዲስ ባነር ፎቶ ይጫኑ (Upload Banner)'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blueGrey.shade100,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade900,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              widget.onUpdate(_titleController.text, _descController.text, _selectedImage);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ማስታወቂያው በተሳካ ሁኔታ ተቀይሯል!')),
              );
            },
            child: const Text(
              'አድስ / አውጣ (Update & Publish)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 📜 ALL-USER CENTRAL REGISTRY SCREEN (Super Admin Only)
// ==========================================
class AllUserRegistryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;
  const AllUserRegistryScreen({super.key, required this.drivers});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'የተጠቃሚዎች ማውጫ ዝርዝር (Central Registry)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: drivers.isEmpty
                ? const Center(child: Text('ምንም የተመዘገቡ ተጠቃሚዎች የሉም'))
                : ListView.builder(
                    itemCount: drivers.length,
                    itemBuilder: (ctx, index) {
                      final d = drivers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            d['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ስልክ፡ ${d['phone']} | ሰሌዳ፡ ${d['plate']}'),
                              Text('ጣቢያ፡ ${d['madiya']} | ሁኔታ፡ ${d['status']}'),
                            ],
                          ),
                          isThreeLine: true,
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: const Icon(Icons.person, color: Colors.teal),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 📜 TRANSFER HISTORY ENTRY SCREEN (Super Admin Only)
// ==========================================
class TransferHistoryEntryScreen extends StatelessWidget {
  final List<ActivityLog> logs;
  const TransferHistoryEntryScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final transferLogs = logs.where((l) => l.actionType == 'Bulk Transfer').toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'የዝውውር ታሪክ መግቢያ (Audit Log)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: transferLogs.isEmpty
                ? const Center(child: Text('ምንም የዝውውር ታሪክ አልተገኘም'))
                : ListView.builder(
                    itemCount: transferLogs.length,
                    itemBuilder: (ctx, index) {
                      final log = transferLogs[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade100,
                            child: const Icon(Icons.move_to_inbox, color: Colors.purple),
                          ),
                          title: Text(log.details),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('የተዛወረበት ቀን፡ ${log.createdAt?.toLocal()}'),
                              Text('በ፡ ${log.performedBy}'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 📺 LIVE APPOINTMENT DASHBOARD (with Supabase update)
// ==========================================
class LiveAppointmentDashboard extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;
  final String currentMadiya;
  final bool isAdminMode;
  final Future<void> Function(String, String)? onStatusChanged;

  const LiveAppointmentDashboard({
    super.key,
    required this.drivers,
    required this.currentMadiya,
    this.isAdminMode = false,
    this.onStatusChanged,
  });

  Color _getLiveStatusColor(String status) {
    switch (status) {
      case "Waiting":
        return Colors.orange;
      case "In Progress":
        return Colors.blue;
      case "Completed":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getLiveStatusAmharic(String status) {
    switch (status) {
      case "Waiting":
        return "በመጠባበቅ ላይ";
      case "In Progress":
        return "በመፈተሽ ላይ ⏳";
      case "Completed":
        return "ተጠናቋል ✅";
      default:
        return "ያልተጀመረ";
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveList = drivers
        .where((d) => d['status'] == 'Approved' && d['live_status'] != 'None')
        .toList();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      color: Colors.red,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'የዛሬ የቀጥታ ቀጠሮ መከታተያ ሰሌዳ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  currentMadiya == "ALL" ? "ሁሉም ጣቢያዎች" : currentMadiya,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: liveList.isEmpty
                ? const Center(
                    child: Text('ዛሬ በአሁኑ ሰዓት በጣቢያው የሚገኝ ተሽከርካሪ የለም።'),
                  )
                : ListView.builder(
                    itemCount: liveList.length,
                    itemBuilder: (ctx, index) {
                      final d = liveList[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    d['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getLiveStatusColor(
                                        d['live_status'],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _getLiveStatusAmharic(d['live_status']),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'ሰሌዳ፡ ${d['plate']} (${d['type']})',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    '🕒 ሰዓት፡ ${d['time_slot']}',
                                    style: const TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '📍 ጣቢያ፡ ${d['madiya']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '⛽ ነዳጅ፡ ${d['fuel_type'] ?? 'አልተመረጠም'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),

                              if (isAdminMode) ...[
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'ሁኔታ ቀይር፦ ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      onPressed: () => onStatusChanged?.call(
                                        d['id'],
                                        'Waiting',
                                      ),
                                      child: const Text(
                                        'ጠባቂ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      onPressed: () => onStatusChanged?.call(
                                        d['id'],
                                        'In Progress',
                                      ),
                                      child: const Text(
                                        'ፍተሻ ላይ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      onPressed: () => onStatusChanged?.call(
                                        d['id'],
                                        'Completed',
                                      ),
                                      child: const Text(
                                        'ጨረሰ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🔒 የአድሚን መግቢያ ገጽ (unchanged)
// ==========================================
class AdminLoginScreen extends StatefulWidget {
  final List<String> madiyas;
  final Function(String, String) onLoginSuccess;
  const AdminLoginScreen({
    super.key,
    required this.madiyas,
    required this.onLoginSuccess,
  });

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedStationForAdmin;
  String _errorMessage = "";

  void _login() {
    String user = _usernameController.text.trim();
    String pass = _passwordController.text.trim();

    if (user == "superadmin" && pass == "456") {
      widget.onLoginSuccess("SUPER_ADMIN", "ALL");
    } else if (user == "admin" && pass == "123") {
      if (_selectedStationForAdmin == null) {
        setState(() => _errorMessage = "እባክዎ መጀመሪያ የሚያስተዳድሩትን 1 ማዲያ ጣቢያ ይምረጡ!");
        return;
      }
      widget.onLoginSuccess("REGULAR_ADMIN", _selectedStationForAdmin!);
    } else if (user == "abrish" && pass == "@abrish#12") {
      widget.onLoginSuccess("AD_OWNER", "GLOBAL");
    } else {
      setState(() => _errorMessage = "የተጠቃሚ ስም ወይም የይለፍ ቃል ስህተት ነው!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Icon(Icons.lock_person, size: 60, color: Colors.blueGrey),
          const SizedBox(height: 12),
          const Text(
            'የአድሚን መግቢያ መድረክ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'ተጠቃሚ ስም (Username)',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'የይለፍ ቃል (Password)',
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'ለመደበኛ አድሚን፡ የሚቆጣጠሩት ጣቢያ',
            ),
            value: _selectedStationForAdmin,
            items: widget.madiyas
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedStationForAdmin = v),
          ),
          const SizedBox(height: 12),
          if (_errorMessage.isNotEmpty)
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade900,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _login,
            child: const Text(
              'ግባ (Login)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. የሾፌሮች መነሻ ገጽ (unchanged)
// ==========================================
class UserPortalHomeScreen extends StatelessWidget {
  final Function(int) onNavigate;
  final String adTitle;
  final String adDescription;
  final XFile? adImage;
  final List<Map<String, dynamic>> announcements;

  const UserPortalHomeScreen({
    super.key,
    required this.onNavigate,
    required this.adTitle,
    required this.adDescription,
    this.adImage,
    required this.announcements,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dynamic Banner from SUPER ADMIN
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade800, width: 2),
            ),
            child: Column(
              children: [
                if (adImage != null)
                  Image.file(
                    File(adImage!.path),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Text(
                            adTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        adDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (announcements.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.teal),
                SizedBox(width: 10),
                Text(
                  'አዳዲስ ማስታወቂያዎች',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                final ann = announcements[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.orange),
                    title: Text(ann['title'] ?? 'ማስታወቂያ'),
                    subtitle: Text(ann['content'] ?? ''),
                    trailing: Text(
                      ann['created_at'] != null
                        ? DateTime.parse(ann['created_at']).toLocal().toString().split(' ')[0]
                        : '',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 30),
          const Icon(Icons.directions_car, size: 70, color: Colors.teal),
          const SizedBox(height: 16),
          Text(
            'የ${SmartMadiyaApp.currentCity} ከተማ ስማርት ማዲያ ሲስተም',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () => onNavigate(1),
            icon: const Icon(Icons.add_box, color: Colors.white),
            label: const Text(
              'አዲስ ተሽከርካሪ ይመዝግቡ',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.teal),
            ),
            onPressed: () => onNavigate(2),
            icon: const Icon(Icons.search, color: Colors.teal),
            label: const Text(
              'በሰሌዳ ወይም ስልክ ቁጥር ቀጠሮ ፍተሻ',
              style: TextStyle(color: Colors.teal),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () => onNavigate(3),
            icon: const Icon(Icons.live_tv, color: Colors.white),
            label: const Text(
              'የዛሬ የጣቢያዎች ቀጥታ (Live) ሁኔታ መከታተያ',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. የሾፌር ምዝገባ ገጽ (adjusted for Supabase)
// ==========================================
class DriverRegistrationScreen extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onRegister;
  final List<Map<String, dynamic>> drivers;
  final List<String> vehicles;
  final List<String> madiyas;

  const DriverRegistrationScreen({
    super.key,
    required this.onRegister,
    required this.drivers,
    required this.vehicles,
    required this.madiyas,
  });

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faydaController = TextEditingController();
  final _plateController = TextEditingController();
  String? _selectedVehicle;
  String? _selectedMadiya;
  String? _selectedFuelType;

  final List<String> _fuelTypes = [
    "ነጭ ናፍጣ",
    "ቤንዚን",
    "ኬሮሲን",
    "ቀላል ጥቁር ናፍጣ",
    "ከባድ ጥቁር ናፍጣ",
    "የኤሮፕላን ነዳጅ",
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'አዲስ ተሽከርካሪ መመዝገቢያ ፎርም',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ሙሉ ስም'),
              validator: (v) => v!.isEmpty ? 'እባክዎ ስም ያስገቡ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'ስልክ ቁጥር'),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'እባክዎ ስልክ ያስገቡ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _faydaController,
              decoration: const InputDecoration(labelText: 'የፋይዳ ቁጥር ያስገቡ'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'እባክዎ የፋይዳ ቁጥር ያስገቡ';
                if (v.length != 16 || !RegExp(r'^[0-9]+$').hasMatch(v)) {
                  return 'እባክዎ በትክክል የ 16 አሃዝ የፋይዳ ቁጥር ያስገቡ!';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateController,
              decoration: const InputDecoration(labelText: 'የሰሌዳ ቁጥር'),
              validator: (v) => v!.isEmpty ? 'እባክዎ የሰሌዳ ቁጥር ያስገቡ' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'የተሽከርካሪ ዓይነት'),
              value: _selectedVehicle,
              items: widget.vehicles
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedVehicle = v),
              validator: (v) => v == null ? 'ዓይነት ይምረጡ' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'የነዳጅ አይነት (Fuel Type)',
              ),
              value: _selectedFuelType,
              items: _fuelTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedFuelType = v),
              validator: (v) => v == null ? 'እባክዎ የነዳጅ አይነት ይምረጡ' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'የመጀመሪያ ማዲያ ጣቢያ'),
              value: _selectedMadiya,
              items: widget.madiyas
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMadiya = v),
              validator: (v) => v == null ? 'ማዲያ ይምረጡ' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  String inputPhone = _phoneController.text.trim();
                  String inputPlate = _plateController.text
                      .trim()
                      .toUpperCase();
                  String inputFayda = _faydaController.text.trim();

                  // Check duplicate from existing drivers list (already loaded)
                  bool isDuplicate = widget.drivers.any(
                    (d) =>
                        d['phone'] == inputPhone ||
                        d['plate'].toString().toUpperCase() == inputPlate ||
                        d['fayda'] == inputFayda,
                  );

                  if (isDuplicate) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(
                          '⚠️ የምዝገባ ስህተት',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: const Text(
                          'ይህ ስልክ ቁጥር፣ የሰሌዳ ቁጥር ወይም የፋይዳ መለያ አስቀድሞ በሌላ ሾፌር ተመዝግቧል!',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('እሺ'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  await widget.onRegister({
                    "name": _nameController.text,
                    "phone": inputPhone,
                    "fayda": inputFayda,
                    "plate": inputPlate,
                    "type": _selectedVehicle,
                    "fuel_type": _selectedFuelType,
                    "madiya": _selectedMadiya,
                    "status": "Pending",
                    "day": "ያልተወሰነ",
                    "time_slot": "ያልተወሰነ",
                    "live_status": "None",
                    "qr": "",
                    "message": "",
                  });

                  _nameController.clear();
                  _phoneController.clear();
                  _faydaController.clear();
                  _plateController.clear();
                  setState(() {
                    _selectedVehicle = null;
                    _selectedFuelType = null;
                    _selectedMadiya = null;
                  });
                }
              },
              child: const Text(
                'መረጃውን በደህንነት መዝግብ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. የሾፌር ቀጠሮ ፍተሻ (still uses local list, but works with real data)
// ==========================================
class UserAppointmentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> drivers;
  const UserAppointmentScreen({super.key, required this.drivers});

  @override
  State<UserAppointmentScreen> createState() => _UserAppointmentScreenState();
}

class _UserAppointmentScreenState extends State<UserAppointmentScreen> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _foundDriver;
  bool _hasSearched = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'በስልክ ወይም በሰሌዳ ቁጥር ቀጠሮዎን ይፈትሹ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _searchController,
                  decoration: const InputDecoration(labelText: 'ቁጥር ያስገቡ'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(80, 50),
                ),
                onPressed: () {
                  setState(() {
                    _hasSearched = true;
                    String query = _searchController.text.trim().toUpperCase();
                    final matches = widget.drivers.where(
                      (d) =>
                          d['phone'] == query ||
                          d['plate'].toString().toUpperCase() == query,
                    );
                    _foundDriver = matches.isNotEmpty ? matches.first : null;
                  });
                },
                child: const Text('ፈልግ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_hasSearched && _foundDriver == null)
            const Text(
              'ምንም ዓይነት የተመዘገበ መረጃ አልተገኘም።',
              style: TextStyle(color: Colors.red),
            ),
          if (_foundDriver != null) ...[
            Card(
              color: Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _foundDriver!['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('የሰሌዳ ቁጥር'),
                      trailing: Text(_foundDriver!['plate']),
                    ),
                    ListTile(
                      title: const Text('የተሽከርካሪ ዓይነት'),
                      trailing: Text(_foundDriver!['type']),
                    ),
                    ListTile(
                      title: const Text('የነዳጅ አይነት'),
                      trailing: Text(_foundDriver!['fuel_type'] ?? 'አልተመረጠም'),
                    ),
                    ListTile(
                      title: const Text('የተመደበ ማዲያ ጣቢያ'),
                      trailing: Text(_foundDriver!['madiya']),
                    ),
                    ListTile(
                      title: const Text('የቀጠሮ ቀን'),
                      trailing: Text(
                        _foundDriver!['day'],
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('የቀጠሮ ሰዓት (Time Slot)'),
                      trailing: Text(
                        _foundDriver!['time_slot'],
                        style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_foundDriver!['status'] == 'Approved') ...[
                      const SizedBox(height: 12),
                      const Icon(
                        Icons.qr_code_2,
                        size: 100,
                        color: Colors.teal,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// 👑 4. የአድሚን ዳሽቦርድ (with Supabase approval)
// ==========================================
class AdminDashboardScreen extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> filteredDrivers;
  final String role;
  final String station;
  final Future<void> Function(String, String, String) onApproved;
  final Map<String, int> stats;

  const AdminDashboardScreen({
    super.key,
    required this.drivers,
    required this.filteredDrivers,
    required this.role,
    required this.station,
    required this.onApproved,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final pendingList = role == "SUPER_ADMIN"
        ? drivers.where((d) => d['status'] == 'Pending').toList()
        : filteredDrivers.where((d) => d['status'] == 'Pending').toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (role == "SUPER_ADMIN") ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👑 ሱፐር አድሚን የቁጥጥር ማዕከል (Super Admin Panel)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard('ጠቅላላ ሹፌሮች', stats['total_drivers'].toString(), Colors.amber),
                      _buildStatCard('ዝውውሮች', stats['total_transfers'].toString(), Colors.cyan),
                      _buildStatCard('በመጠባበቅ ላይ', stats['pending_requests'].toString(), Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏢 የማዲያ አድሚን ዳሽቦርድ ($station)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'በዚህ ጣቢያ ያሉ አጠቃላይ ተሽከርካሪዎች፡ ${filteredDrivers.length}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'የጸደቁ፡ ${filteredDrivers.where((element) => element['status'] == 'Approved').length} | በመጠባበቅ ላይ፡ ${filteredDrivers.where((element) => element['status'] == 'Pending').length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '⏳ በመጠባበቅ ላይ ያሉ ጥያቄዎች',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: pendingList.isEmpty
                ? const Center(child: Text('ምንም ያልተፈቀዱ ተሽከርካሪዎች የሉም'))
                : ListView.builder(
                    itemCount: pendingList.length,
                    itemBuilder: (ctx, index) {
                      final d = pendingList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            d['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'ሰሌዳ፡ ${d['plate']} | ጣቢያ፡ ${d['madiya']} | ነዳጅ፡ ${d['fuel_type'] ?? 'አልተመረጠም'}',
                          ),
                          trailing: role == "SUPER_ADMIN"
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () async {
                                    await onApproved(
                                      d['id'],
                                      'ማክሰኞ',
                                      '10:00 - 11:30 ጠዋት',
                                    );
                                  },
                                  child: const Text(
                                    'አፅድቅ',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. QR ስካን ማረጋገጫ (REAL SCANNER)
// ==========================================
class QrScanVerificationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> drivers;
  const QrScanVerificationScreen({super.key, required this.drivers});

  @override
  State<QrScanVerificationScreen> createState() =>
      _QrScanVerificationScreenState();
}

class _QrScanVerificationScreenState extends State<QrScanVerificationScreen> {
  bool _isProcessing = false;
  String? _lastScanned;

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code != _lastScanned) {
        setState(() {
          _isProcessing = true;
          _lastScanned = code;
        });

        final driver = await SupabaseService.verifyMadiyaQueueByQR(code);

        if (driver != null) {
          // Log QR Verification
          await SupabaseService.logActivity(ActivityLog(
            actionType: 'QR Check-in',
            performedBy: 'QR Scanner',
            vehiclePlate: driver.plate,
            details: 'Verified via QR Code scan',
          ));

          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('✅ ማረጋገጫ ተጠናቋል'),
                content: Text(
                  'ሾፌር፡ ${driver.name}\nሰሌዳ፡ ${driver.plate}\nሁኔታ፡ ወደ ፍተሻ ተቀይሯል።',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _isProcessing = false;
                        _lastScanned = null;
                      });
                    },
                    child: const Text('እሺ'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ የማይታወቅ QR ኮድ!'),
                backgroundColor: Colors.red,
              ),
            );
            Future.delayed(const Duration(seconds: 2), () {
              setState(() {
                _isProcessing = false;
                _lastScanned = null;
              });
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'የሾፌሩን QR ኮድ እዚህ ያሳዩ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: MobileScanner(
            onDetect: _handleCapture,
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

// ==========================================
// 6. የማዛወሪያ ስክሪን (STATION-TO-STATION BULK TRANSFER)
// ==========================================
class VehicleTransferScreen extends StatefulWidget {
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> history;
  final List<String> madiyas;
  final String role;
  final String station;
  final Future<void> Function(List<String>, String, String, String) onBulkTransfer;

  const VehicleTransferScreen({
    super.key,
    required this.drivers,
    required this.history,
    required this.madiyas,
    required this.role,
    required this.station,
    required this.onBulkTransfer,
  });

  @override
  State<VehicleTransferScreen> createState() => _VehicleTransferScreenState();
}

class _VehicleTransferScreenState extends State<VehicleTransferScreen> {
  String? _selectedSourceMadiya;
  String? _selectedTargetMadiya;
  final _quantityController = TextEditingController();
  final Set<String> _selectedDriverIds = {};

  List<Map<String, dynamic>> get _sourceDrivers {
    if (_selectedSourceMadiya == null) return [];
    return widget.drivers
        .where((d) => d['madiya'] == _selectedSourceMadiya)
        .toList();
  }

  void _autoSelect(String value) {
    int? count = int.tryParse(value);
    _selectedDriverIds.clear();
    if (count != null && count > 0) {
      final list = _sourceDrivers;
      for (int i = 0; i < count && i < list.length; i++) {
        _selectedDriverIds.add(list[i]['id']);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = widget.role == "SUPER_ADMIN";

    if (!isSuperAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'ይቅርታ! ይህ ገጽ ለሱፐር አድሚን ብቻ የተፈቀደ ነው',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'የተሽከርካሪ ጣቢያ በጅምላ ማዛወሪያ (Bulk)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'የሚዛወርበትን መነሻ ማዲያ ይምረጡ'),
            value: _selectedSourceMadiya,
            items: widget.madiyas
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedSourceMadiya = v;
                _selectedDriverIds.clear();
                _quantityController.clear();
              });
            },
          ),
          if (_selectedSourceMadiya != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'የሚዛወሩ ሰዎች ብዛት (ከ ${_sourceDrivers.length})',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle),
                  onPressed: () => _autoSelect(_quantityController.text),
                ),
              ),
              onChanged: _autoSelect,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _sourceDrivers.length,
                itemBuilder: (ctx, index) {
                  final d = _sourceDrivers[index];
                  return CheckboxListTile(
                    title: Text('${d['name']} - ${d['plate']}'),
                    value: _selectedDriverIds.contains(d['id']),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedDriverIds.add(d['id']);
                        } else {
                          _selectedDriverIds.remove(d['id']);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'ወደሚዛወርበት መድረሻ ማዲያ ይምረጡ'),
            value: _selectedTargetMadiya,
            items: widget.madiyas
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedTargetMadiya = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade900,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _selectedDriverIds.isNotEmpty &&
                    _selectedTargetMadiya != null &&
                    _selectedTargetMadiya != _selectedSourceMadiya
                ? () async {
                    await widget.onBulkTransfer(
                      _selectedDriverIds.toList(),
                      _selectedSourceMadiya!,
                      _selectedTargetMadiya!,
                      '${widget.role} (${widget.station})',
                    );
                    setState(() {
                      _selectedDriverIds.clear();
                      _quantityController.clear();
                    });
                  }
                : null,
            child: Text(
              '${_selectedDriverIds.length} ተሽከርካሪዎችን አዛውር',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.analytics),
            label: const Text('የዝውውር አናሊቲክስ ሪፖርት ይመልከቱ'),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => const AnalyticsReportSheet(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 📊 ANALYTICS & REPORT SHEET
// ==========================================
class AnalyticsReportSheet extends StatefulWidget {
  const AnalyticsReportSheet({super.key});

  @override
  State<AnalyticsReportSheet> createState() => _AnalyticsReportSheetState();
}

class _AnalyticsReportSheetState extends State<AnalyticsReportSheet> {
  List<TransferHistory> _transfers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final transfers = await SupabaseService.fetchTransferHistory();
      if (mounted) {
        setState(() {
          _transfers = transfers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading transfer analytics: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 የዝውውር አናሊቲክስ እና ሪፖርት',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_transfers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('ምንም የዝውውር ታሪክ አልተገኘም'),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('ጠቅላላ ዝውውር', _transfers.length.toString()),
                  _buildStatItem(
                    'ዛሬ',
                    _transfers.where((t) {
                      final now = DateTime.now();
                      return t.transferredAt.year == now.year &&
                          t.transferredAt.month == now.month &&
                          t.transferredAt.day == now.day;
                    }).length.toString(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'የቅርብ ጊዜ እንቅስቃሴዎች',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _transfers.length,
                itemBuilder: (ctx, index) {
                  final t = _transfers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.move_to_inbox, color: Colors.orange),
                      title: Text(t.driverName ?? 'Unknown Driver'),
                      subtitle: Text('ከ ${t.fromMadiya} ➔ ${t.toMadiya}'),
                      trailing: Text(
                        '${t.transferredAt.hour}:${t.transferredAt.minute}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
