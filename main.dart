import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:telephony/telephony.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.init();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState(db))],
      child: const MyRepairShopApp(),
    ),
  );
}

class MyRepairShopApp extends StatelessWidget {
  const MyRepairShopApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );

    return MaterialApp(
      title: 'Mobile Repair Shop Manager',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xfff5f5f7),
        cardTheme: CardThemeData(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(elevation: 3, centerTitle: true),
      ),
      home: const MainHomeScreen(),
    );
  }
}

/////////////////////
// App State & DB  //
/////////////////////

class AppState extends ChangeNotifier {
  final AppDatabase db;
  List<RepairJob> repairs = [];
  List<SmsLog> smsLogs = [];

  AppState(this.db) {
    _loadAll();
  }

  Future<void> _loadAll() async {
    repairs = await db.getRepairs();
    smsLogs = await db.getSmsLogs();
    notifyListeners();
  }

  Future<void> addRepair(RepairJob r) async {
    await db.insertRepair(r);
    await _loadAll();
  }

  Future<void> updateRepair(RepairJob r) async {
    await db.updateRepair(r);
    await _loadAll();
  }

  Future<void> deleteRepair(int id) async {
    await db.deleteRepair(id);
    await _loadAll();
  }

  Future<void> addSmsLog(SmsLog s) async {
    await db.insertSmsLog(s);
    await _loadAll();
  }
}

class AppDatabase {
  static Database? _db;
  Database get db => _db!;

  static Future<AppDatabase> init() async {
    final instance = AppDatabase();
    await instance._initDb();
    return instance;
  }

  Future<void> _initDb() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, "app_data.db");
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE repairs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT,
        phone TEXT,
        model TEXT,
        imei TEXT,
        problem TEXT,
        status TEXT,
        imagePath TEXT,
        createdAt INTEGER,
        completedAt INTEGER,
        pin TEXT,
        password TEXT,
        pattern TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE sms_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        toNumber TEXT,
        message TEXT,
        sentAt INTEGER,
        status TEXT
      );
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE repairs ADD COLUMN completedAt INTEGER;');
      await db.execute('ALTER TABLE repairs ADD COLUMN pin TEXT;');
      await db.execute('ALTER TABLE repairs ADD COLUMN password TEXT;');
      await db.execute('ALTER TABLE repairs ADD COLUMN pattern TEXT;');
    }
  }

  Future<int> insertRepair(RepairJob r) => db.insert('repairs', r.toMap());

  Future<int> updateRepair(RepairJob r) =>
      db.update('repairs', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<int> deleteRepair(int id) =>
      db.delete('repairs', where: 'id = ?', whereArgs: [id]);

  Future<List<RepairJob>> getRepairs() async {
    final rows = await db.query('repairs', orderBy: 'createdAt DESC');
    return rows.map((r) => RepairJob.fromMap(r)).toList();
  }

  Future<int> insertSmsLog(SmsLog s) => db.insert('sms_logs', s.toMap());

  Future<List<SmsLog>> getSmsLogs() async {
    final rows = await db.query('sms_logs', orderBy: 'sentAt DESC');
    return rows.map((r) => SmsLog.fromMap(r)).toList();
  }
}

/////////////////////
// Data Models     //
/////////////////////

class RepairJob {
  int? id;
  String customerName;
  String phone;
  String model;
  String imei;
  String problem;
  String status;
  String? imagePath;
  int createdAt;
  int? completedAt;
  String? pin;
  String? password;
  String? pattern;

  RepairJob({
    this.id,
    required this.customerName,
    required this.phone,
    required this.model,
    required this.imei,
    required this.problem,
    this.status = 'Pending',
    this.imagePath,
    int? createdAt,
    this.completedAt,
    this.pin,
    this.password,
    this.pattern,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'id': id,
    'customerName': customerName,
    'phone': phone,
    'model': model,
    'imei': imei,
    'problem': problem,
    'status': status,
    'imagePath': imagePath,
    'createdAt': createdAt,
    'completedAt': completedAt,
    'pin': pin,
    'password': password,
    'pattern': pattern,
  };

  factory RepairJob.fromMap(Map<String, dynamic> m) => RepairJob(
    id: m['id'],
    customerName: m['customerName'],
    phone: m['phone'],
    model: m['model'],
    imei: m['imei'],
    problem: m['problem'],
    status: m['status'],
    imagePath: m['imagePath'],
    createdAt: m['createdAt'],
    completedAt: m['completedAt'],
    pin: m['pin'],
    password: m['password'],
    pattern: m['pattern'],
  );
}

class SmsLog {
  int? id;
  String toNumber;
  String message;
  int sentAt;
  String status;

  SmsLog({
    this.id,
    required this.toNumber,
    required this.message,
    int? sentAt,
    this.status = 'sent',
  }) : sentAt = sentAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'id': id,
    'toNumber': toNumber,
    'message': message,
    'sentAt': sentAt,
    'status': status,
  };

  factory SmsLog.fromMap(Map<String, dynamic> m) => SmsLog(
    id: m['id'],
    toNumber: m['toNumber'],
    message: m['message'],
    sentAt: m['sentAt'],
    status: m['status'] ?? 'sent',
  );
}

/////////////////////
// Utility         //
/////////////////////

final telephony = Telephony.instance;
final ImagePicker _picker = ImagePicker();

Future<String?> pickImageAndSave() async {
  final xfile = await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 80,
  );
  if (xfile == null) return null;
  final doc = await getApplicationDocumentsDirectory();
  final newDir = Directory(p.join(doc.path, 'images'));
  if (!await newDir.exists()) await newDir.create(recursive: true);
  final saved = await File(
    xfile.path,
  ).copy(p.join(newDir.path, p.basename(xfile.path)));
  return saved.path;
}

Future<Uint8List> generateInvoicePdf(RepairJob job) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Repair Invoice',
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Customer: ${job.customerName}',
            style: const pw.TextStyle(fontSize: 18),
          ),
          pw.Text(
            'Phone: ${job.phone}',
            style: const pw.TextStyle(fontSize: 18),
          ),
          pw.Text(
            'Device: ${job.model} (IMEI: ${job.imei})',
            style: const pw.TextStyle(fontSize: 18),
          ),
          pw.SizedBox(height: 15),
          pw.Text(
            'Issue: ${job.problem}',
            style: const pw.TextStyle(fontSize: 16),
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            'Thank you for trusting us!',
            style: const pw.TextStyle(fontSize: 16),
          ),
        ],
      ),
    ),
  );
  return pdf.save();
}

/////////////////////
// Main Shell      //
/////////////////////

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    RepairTrackingPage(),
    SmsSenderPage(),
    PasswordStorePage(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Repairs',
    'SMS Center',
    'Password Vault',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primaryContainer,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Repairs',
          ),
          NavigationDestination(
            icon: Icon(Icons.sms_outlined),
            selectedIcon: Icon(Icons.sms),
            label: 'SMS',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Passwords',
          ),
        ],
      ),
    );
  }
}

//////////////////////////////
// Dashboard Page          //
//////////////////////////////

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final st = Provider.of<AppState>(context);
    final repairs = st.repairs;
    final now = DateTime.now();

    final pending = repairs.where((r) => r.status != 'Completed').length;
    final completed = repairs.where((r) => r.status == 'Completed').length;

    Map<String, int> receivedLast7 = {};
    Map<String, int> completedLast7 = {};
    final dateFormat = DateFormat('MMM dd');

    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final key = dateFormat.format(day);
      receivedLast7[key] = 0;
      completedLast7[key] = 0;
    }

    for (var r in repairs) {
      final createDt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
      if (createDt.isAfter(now.subtract(const Duration(days: 7)))) {
        final key = dateFormat.format(createDt);
        receivedLast7[key] = (receivedLast7[key] ?? 0) + 1;

        if (r.status == 'Completed' && r.completedAt != null) {
          final compDt = DateTime.fromMillisecondsSinceEpoch(r.completedAt!);
          if (compDt.isAfter(now.subtract(const Duration(days: 7)))) {
            final ckey = dateFormat.format(compDt);
            completedLast7[ckey] = (completedLast7[ckey] ?? 0) + 1;
          }
        }
      }
    }

    return SingleChildScrollView(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.build,
                  iconColor: Colors.orange.shade700,
                  label: 'Pending Repairs',
                  value: pending.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle,
                  iconColor: Colors.green.shade700,
                  label: 'Completed',
                  value: completed.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Last 7 Days Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...receivedLast7.keys.map((day) {
            return Card(
              child: ListTile(
                title: Text(
                  day,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  'Received: ${receivedLast7[day]}  •  Done: ${completedLast7[day]}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////
// Repair Tracking Page     //
//////////////////////////////

class RepairTrackingPage extends StatefulWidget {
  const RepairTrackingPage({Key? key}) : super(key: key);

  @override
  State<RepairTrackingPage> createState() => _RepairTrackingPageState();
}

class _RepairTrackingPageState extends State<RepairTrackingPage> {
  final _cname = TextEditingController();
  final _phone = TextEditingController();
  final _model = TextEditingController();
  final _imei = TextEditingController();
  final _problem = TextEditingController();
  final _pin = TextEditingController();
  final _password = TextEditingController();
  final _pattern = TextEditingController();
  String? _imagePath;

  Future<void> _saveRepair(AppState st) async {
    if (_cname.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name & phone are required')),
      );
      return;
    }

    final job = RepairJob(
      customerName: _cname.text.trim(),
      phone: _phone.text.trim(),
      model: _model.text.trim(),
      imei: _imei.text.trim(),
      problem: _problem.text.trim(),
      imagePath: _imagePath,
      pin: _pin.text.isEmpty ? null : _pin.text.trim(),
      password: _password.text.isEmpty ? null : _password.text.trim(),
      pattern: _pattern.text.isEmpty ? null : _pattern.text.trim(),
    );

    await st.addRepair(job);

    _cname.clear();
    _phone.clear();
    _model.clear();
    _imei.clear();
    _problem.clear();
    _pin.clear();
    _password.clear();
    _pattern.clear();
    setState(() => _imagePath = null);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Repair job added')));
  }

  @override
  Widget build(BuildContext context) {
    final st = Provider.of<AppState>(context);

    return Padding(
      key: const ValueKey('repairs'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNewRepairCard(st),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'All Repairs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${st.repairs.length} items',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: st.repairs.isEmpty
                ? const Center(
                    child: Text(
                      'No repair jobs yet.\nAdd a new job above.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: st.repairs.length,
                    itemBuilder: (context, index) {
                      final r = st.repairs[index];
                      final date = DateFormat('dd MMM yyyy').format(
                        DateTime.fromMillisecondsSinceEpoch(r.createdAt),
                      );
                      return _buildRepairItem(st, r, date);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewRepairCard(AppState st) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'New Repair Job',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cname,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _model,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _imei,
                    decoration: const InputDecoration(
                      labelText: 'IMEI',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _problem,
              decoration: const InputDecoration(
                labelText: 'Problem / Issue',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pin,
                    decoration: const InputDecoration(
                      labelText: 'PIN (optional)',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'Password (optional)',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pattern,
              decoration: const InputDecoration(
                labelText: 'Pattern (describe)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await pickImageAndSave();
                    if (path != null) setState(() => _imagePath = path);
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add Photo'),
                ),
                FilledButton.icon(
                  onPressed: () => _saveRepair(st),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Job'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepairItem(AppState st, RepairJob r, String date) {
    return Dismissible(
      key: Key(r.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Repair?'),
            content: Text('Delete ${r.customerName} - ${r.model}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        st.deleteRepair(r.id!);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${r.customerName} deleted')));
      },
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: r.imagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(r.imagePath!),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
              : CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: const Icon(Icons.phone_android),
                ),
          title: Text(
            r.customerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.model} • ${r.phone}'),
              Text(
                'Issue: ${r.problem}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Added: $date • Status: ${r.status}',
                style: TextStyle(
                  color: r.status == 'Completed'
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'complete') {
                r.status = 'Completed';
                r.completedAt = DateTime.now().millisecondsSinceEpoch;
                await st.updateRepair(r);
              } else if (value == 'invoice') {
                final bytes = await generateInvoicePdf(r);
                await Printing.layoutPdf(onLayout: (_) => bytes);
              } else if (value == 'call') {
                launchUrl(Uri.parse('tel:${r.phone}'));
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  st.deleteRepair(r.id!);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'complete', child: Text('Mark Complete')),
              PopupMenuItem(value: 'invoice', child: Text('Generate Invoice')),
              PopupMenuItem(value: 'call', child: Text('Call Customer')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cname.dispose();
    _phone.dispose();
    _model.dispose();
    _imei.dispose();
    _problem.dispose();
    _pin.dispose();
    _password.dispose();
    _pattern.dispose();
    super.dispose();
  }
}

//////////////////////////////
// SMS Page                 //
//////////////////////////////

class SmsSenderPage extends StatefulWidget {
  const SmsSenderPage({Key? key}) : super(key: key);

  @override
  State<SmsSenderPage> createState() => _SmsSenderPageState();
}

class _SmsSenderPageState extends State<SmsSenderPage> {
  final _to = TextEditingController();
  final _msg = TextEditingController();
  bool _sending = false;

  Future<void> _sendSms(AppState st) async {
    if (_to.text.trim().isEmpty || _msg.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Number and message required')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      // Make sure to handle permissions in real device
      await telephony.sendSms(to: _to.text.trim(), message: _msg.text.trim());

      await st.addSmsLog(
        SmsLog(
          toNumber: _to.text.trim(),
          message: _msg.text.trim(),
          status: 'sent',
        ),
      );

      _msg.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SMS sent')));
    } catch (e) {
      await st.addSmsLog(
        SmsLog(
          toNumber: _to.text.trim(),
          message: _msg.text.trim(),
          status: 'failed',
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send SMS')));
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Provider.of<AppState>(context);

    return Padding(
      key: const ValueKey('sms'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Send SMS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _to,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _msg,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : () => _sendSms(st),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Sending...' : 'Send SMS'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'SMS History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${st.smsLogs.length} messages',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: st.smsLogs.isEmpty
                ? const Center(child: Text('No SMS history yet'))
                : ListView.builder(
                    itemCount: st.smsLogs.length,
                    itemBuilder: (_, idx) {
                      final log = st.smsLogs[idx];
                      final dt = DateFormat(
                        'dd MMM, HH:mm',
                      ).format(DateTime.fromMillisecondsSinceEpoch(log.sentAt));
                      return Card(
                        child: ListTile(
                          title: Text(log.toNumber),
                          subtitle: Text(
                            log.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                log.status.toUpperCase(),
                                style: TextStyle(
                                  color: log.status == 'sent'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(dt, style: const TextStyle(fontSize: 12)),
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

  @override
  void dispose() {
    _to.dispose();
    _msg.dispose();
    super.dispose();
  }
}

//////////////////////////////
// Password Store Page      //
//////////////////////////////

class PasswordStorePage extends StatefulWidget {
  const PasswordStorePage({Key? key}) : super(key: key);

  @override
  State<PasswordStorePage> createState() => _PasswordStorePageState();
}

class _PasswordStorePageState extends State<PasswordStorePage> {
  final _keyCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final secureStorage = const FlutterSecureStorage();
  List<MapEntry<String, String>> entries = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final all = await secureStorage.readAll();
    setState(
      () => entries = all.entries
          .map((e) => MapEntry(e.key, e.value ?? ''))
          .toList(),
    );
  }

  Future<void> _saveEntry() async {
    if (_keyCtrl.text.trim().isEmpty || _valueCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Label & value required')));
      return;
    }
    await secureStorage.write(
      key: _keyCtrl.text.trim(),
      value: _valueCtrl.text.trim(),
    );
    _keyCtrl.clear();
    _valueCtrl.clear();
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('passwords'),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Save New Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label (e.g. Google account)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _valueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Password / PIN',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveEntry,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Saved Passwords',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No passwords saved yet'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (_, idx) {
                      final e = entries[idx];
                      return Card(
                        child: ListTile(
                          title: Text(e.key),
                          subtitle: Text(e.value),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await secureStorage.delete(key: e.key);
                              await _loadAll();
                            },
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

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }
}
