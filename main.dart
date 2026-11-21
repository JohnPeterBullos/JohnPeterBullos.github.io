
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ocejnabppxoosdylvvte.supabase.co',
    publishableKey: 'sb_publishable_ZVQykTXhhDvMhczBKehSiQ_0n5r2A-4',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
const purple = Color(0xFF4934F5);
const background = Color(0xFFF2F3FA);

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String formatDateTime(dynamic value) {
  if (value == null) return 'No check-in time';

  final date = DateTime.tryParse(value.toString());
  if (date == null) return value.toString();

  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';

  return '${local.month}/${local.day}/${local.year} '
      '$hour:$minute $period';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'School Event Check-In',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: purple),
        useMaterial3: true,
      ),
      home: supabase.auth.currentUser == null
          ? const LoginPage()
          : const DashboardPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      showMessage(context, 'Enter your email and password');
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Unable to log in');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_available,
                  size: 65,
                  color: purple,
                ),
                const SizedBox(height: 15),
                const Text(
                  'School Event Check-In',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: purple,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Organizer Login'),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: password,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.visibility_off),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text('LOGIN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> events = [];
  int totalAttendees = 0;
  int checkIns = 0;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final eventData = await supabase
          .from('events')
          .select()
          .order('event_date', ascending: false);

      final attendeeData = await supabase
          .from('attendees')
          .select('id, checked_in');

      if (!mounted) return;

      setState(() {
        events = List<Map<String, dynamic>>.from(eventData);
        totalAttendees = attendeeData.length;
        checkIns = attendeeData
            .where((person) => person['checked_in'] == true)
            .length;
      });
    } catch (e) {
      if (mounted) setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Unable to log out');
    }
  }

  Future<void> openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (mounted) loadDashboard();
  }

  Widget counterCard(String title, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: purple),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget actionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) {
    return Card(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFECE9FF),
          child: Icon(icon, color: purple),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        title: const Text(
          'School Event Check-In',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: logout,
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Manage school events and track attendance',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Text(
                'Error loading dashboard: $errorMessage',
                style: const TextStyle(color: Colors.red),
              )
            else ...[
              Row(
                children: [
                  counterCard(
                    'Total Attendees',
                    totalAttendees,
                    Icons.people,
                  ),
                  const SizedBox(width: 12),
                  counterCard(
                    'Check-Ins',
                    checkIns,
                    Icons.how_to_reg,
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                'School Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No events found'),
                  ),
                ),
              ...events.map((event) {
                return Card(
                  color: purple,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      event['event_name']?.toString() ??
                          'Untitled Event',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${event['event_date'] ?? ''}\n'
                      '${event['location'] ?? ''}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    leading: const Icon(
                      Icons.event,
                      color: Colors.white,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              actionCard(
                'Manage Events',
                'Create and organize school events',
                Icons.event_note,
                () => openPage(const CreateEventPage()),
              ),
              actionCard(
                'Guest Check-In',
                'Check in registered attendees',
                Icons.how_to_reg,
                () => openPage(const GuestCheckInPage()),
              ),
              actionCard(
                'Attendance Records',
                'View event attendance history',
                Icons.list_alt,
                () => openPage(const AttendanceRecordsPage()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final location = TextEditingController();
  final description = TextEditingController();

  DateTime? selectedDate;
  bool saving = false;

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  Future<void> saveEvent() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedDate == null) {
      showMessage(context, 'Please select an event date');
      return;
    }

    setState(() => saving = true);

    try {
      final date = selectedDate!;
      final formattedDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      await supabase.from('events').insert({
        'event_name': name.text.trim(),
        'location': location.text.trim(),
        'description': description.text.trim(),
        'event_date': formattedDate,
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) {
        showMessage(context, 'Could not save event: ${e.message}');
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Unable to save event');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.event_note,
                    size: 55,
                    color: purple,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create School Event',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Event Name',
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter an event name'
                            : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter a location'
                            : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    onPressed: chooseDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      selectedDate == null
                          ? 'Select Event Date'
                          : 'Date: '
                              '${selectedDate!.year}-'
                              '${selectedDate!.month.toString().padLeft(2, '0')}-'
                              '${selectedDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving ? null : saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                      ),
                      child: saving
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('SAVE EVENT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GuestCheckInPage extends StatefulWidget {
  const GuestCheckInPage({super.key});

  @override
  State<GuestCheckInPage> createState() => _GuestCheckInPageState();
}

class _GuestCheckInPageState extends State<GuestCheckInPage> {
  final name = TextEditingController();
  final studentId = TextEditingController();

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> recent = [];

  String? selectedEventId;
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final eventData = await supabase
          .from('events')
          .select('id, event_name')
          .order('event_name');

      final attendeeData = await supabase
          .from('attendees')
          .select('full_name, student_id, checked_in_at')
          .eq('checked_in', true)
          .order('checked_in_at', ascending: false)
          .limit(5);

      if (!mounted) return;

      final loadedEvents =
          List<Map<String, dynamic>>.from(eventData);

      setState(() {
        events = loadedEvents;
        recent = List<Map<String, dynamic>>.from(attendeeData);

        if (!events.any((e) => e['id'] == selectedEventId)) {
          selectedEventId = null;
        }
      });
    } catch (e) {
      if (mounted) setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> checkIn() async {
    if (selectedEventId == null) {
      showMessage(context, 'Please select a school event');
      return;
    }

    if (name.text.trim().isEmpty || studentId.text.trim().isEmpty) {
      showMessage(context, 'Please enter name and student ID');
      return;
    }

    setState(() => saving = true);

    try {
      await supabase.from('attendees').insert({
        'event_id': selectedEventId,
        'full_name': name.text.trim(),
        'student_id': studentId.text.trim(),
        'checked_in': true,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      name.clear();
      studentId.clear();

      showMessage(context, 'Guest checked in successfully!');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Unable to check in guest');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    studentId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
              decoration: const BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.settings,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 35,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Guest Check-In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'School Event Management System',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (loading)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (errorMessage != null)
                      Text(
                        'Error: $errorMessage',
                        style: const TextStyle(color: Colors.red),
                      )
                    else ...[
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Event Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<String>(
                                initialValue: selectedEventId,
                                decoration: const InputDecoration(
                                  labelText: 'Select School Event',
                                  border: OutlineInputBorder(),
                                ),
                                items: events.map((event) {
                                  return DropdownMenuItem<String>(
                                    value: event['id'].toString(),
                                    child: Text(
                                      event['event_name'].toString(),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => selectedEventId = value);
                                },
                              ),
                              const SizedBox(height: 15),
                              TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                  labelText: 'Enter Full Name',
                                  hintText: 'Enter Attendees Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 15),
                              TextField(
                                controller: studentId,
                                decoration: const InputDecoration(
                                  labelText: 'Student ID',
                                  hintText: 'Enter Student ID',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: saving ? null : checkIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: purple,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: saving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text('CHECK IN'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Colors.teal,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Ready for next check-in',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Recently Checked In',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (recent.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No recent check-ins'),
                          ),
                        ),
                      ...recent.map((person) {
                        return Card(
                          color: Colors.white,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(
                              person['full_name']?.toString() ?? '',
                            ),
                            subtitle: Text(
                              'Student ID: ${person['student_id'] ?? ''}',
                            ),
                            trailing: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  State<AttendanceRecordsPage> createState() =>
      _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> {
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> attendees = [];

  String? selectedEventId;
  bool loadingEvents = true;
  bool loadingAttendees = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() {
      loadingEvents = true;
      errorMessage = null;
    });

    try {
      final data = await supabase
          .from('events')
          .select('id, event_name')
          .order('event_name');

      if (!mounted) return;

      setState(() {
        events = List<Map<String, dynamic>>.from(data);
        if (!events.any((e) => e['id'] == selectedEventId)) {
          selectedEventId = null;
          attendees = [];
        }
      });
    } catch (e) {
      if (mounted) setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => loadingEvents = false);
    }
  }

  Future<void> loadAttendees(String eventId) async {
    setState(() {
      loadingAttendees = true;
      errorMessage = null;
    });

    try {
      final data = await supabase
          .from('attendees')
          .select(
            'id, full_name, student_id, checked_in, checked_in_at',
          )
          .eq('event_id', eventId)
          .order('checked_in_at', ascending: false);

      if (!mounted || selectedEventId != eventId) return;

      setState(() {
        attendees = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted && selectedEventId == eventId) {
        setState(() => errorMessage = e.toString());
      }
    } finally {
      if (mounted && selectedEventId == eventId) {
        setState(() => loadingAttendees = false);
      }
    }
  }

  Future<void> refresh() async {
    await loadEvents();

    if (selectedEventId != null) {
      await loadAttendees(selectedEventId!);
    }
  }

  Widget attendeeCard(Map<String, dynamic> person) {
    final checkedIn = person['checked_in'] == true;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFECE9FF),
              child: Icon(Icons.person, color: purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person['full_name']?.toString() ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${person['student_id'] ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateTime(person['checked_in_at']),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: checkedIn
                    ? const Color(0xFFE1F5F0)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                checkedIn ? 'Checked In' : 'Not Checked In',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: checkedIn ? Colors.teal : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: const BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Attendance Records',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Event',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Choose School Event'),
                        value: selectedEventId,
                        items: events.map((event) {
                          return DropdownMenuItem<String>(
                            value: event['id'].toString(),
                            child: Text(
                              event['event_name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: loadingEvents
                            ? null
                            : (value) {
                                setState(() {
                                  selectedEventId = value;
                                  attendees = [];
                                });

                                if (value != null) {
                                  loadAttendees(value);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Attendance List',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (loadingEvents || loadingAttendees)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (errorMessage != null)
                      Text(
                        'Error: $errorMessage',
                        style: const TextStyle(color: Colors.red),
                      )
                    else if (selectedEventId == null)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Please select an event to view attendance.',
                          ),
                        ),
                      )
                    else if (attendees.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No attendance records found for this event.',
                          ),
                        ),
                      )
                    else
                      ...attendees.map(attendeeCard),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
