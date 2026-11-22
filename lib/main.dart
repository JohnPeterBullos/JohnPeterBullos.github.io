
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const navy = Color(0xFF151832);
const blue = Color(0xFF3158DC);
const bg = Color(0xFFF3F5FA);

final db = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jtvimhichjjbwmagugsf.supabase.co',
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const ThesisApp());
}

class ThesisApp extends StatelessWidget {
  const ThesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thesis Task Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: blue,
        scaffoldBackgroundColor: bg,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (db.auth.currentSession == null) {
          return const LoginPage();
        }
        return const DashboardPage();
      },
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
  final name = TextEditingController();

  bool register = false;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      message(context, 'Enter your email and password.');
      return;
    }

    setState(() => loading = true);

    try {
      if (register) {
        final result = await db.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'full_name': name.text.trim()},
        );

        if (!mounted) return;

        message(
          context,
          result.session == null
              ? 'Account created. Check your email to confirm registration.'
              : 'Registration successful!',
        );

        if (result.session == null) {
          setState(() => register = false);
        }
      } else {
        await db.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) message(context, cleanError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Group Task Board',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sign in to continue your thesis work',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 45),
                Text(
                  register ? 'Create an account' : 'Welcome back',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  register
                      ? 'Register to join your thesis workspace.'
                      : 'Enter your details to access your workspace.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),
                if (register) ...[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(register ? 'Register' : 'Login'),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => register = !register),
                  child: Text(
                    register
                        ? 'Already have an account? Login'
                        : "Don't have an account? Register",
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
  String page = 'Dashboard';
  bool loading = true;

  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> profiles = [];
  List<Map<String, dynamic>> tasks = [];

  String get userId => db.auth.currentUser!.id;
  String get userEmail => db.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final g = await db.from('groups').select().order('created_at');
      final m = await db.from('group_members').select();
      final p = await db.from('profiles').select();
      final t = await db.from('tasks').select().order('created_at');

      if (!mounted) return;

      setState(() {
        groups = List<Map<String, dynamic>>.from(g);
        members = List<Map<String, dynamic>>.from(m);
        profiles = List<Map<String, dynamic>>.from(p);
        tasks = List<Map<String, dynamic>>.from(t);
      });
    } catch (e) {
      if (mounted) message(context, cleanError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String profileName(String? id) {
    if (id == null) return 'Unassigned';

    for (final p in profiles) {
      if (p['id'] == id) {
        final name = (p['full_name'] ?? '').toString().trim();
        return name.isEmpty ? 'Unnamed User' : name;
      }
    }

    if (id == userId) return userEmail;
    return 'User ${id.substring(0, 8)}';
  }

  String groupName(String? id) {
    for (final g in groups) {
      if (g['id'] == id) return '${g['name']}';
    }
    return 'Unknown Group';
  }

  bool isLeader(String? groupId) {
    for (final g in groups) {
      if (g['id'] == groupId) {
        return g['created_by'] == userId;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> groupUsers(String groupId) {
    final ids = <String>{};

    for (final g in groups) {
      if (g['id'] == groupId && g['created_by'] != null) {
        ids.add('${g['created_by']}');
      }
    }

    for (final m in members) {
      if (m['group_id'] == groupId && m['user_id'] != null) {
        ids.add('${m['user_id']}');
      }
    }

    return ids.map((id) => {'id': id, 'name': profileName(id)}).toList();
  }

  Future<void> createGroup() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final thesis = TextEditingController();
    final stage = TextEditingController(text: 'Planning');

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Thesis Group'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thesis,
                  decoration: const InputDecoration(
                    labelText: 'Thesis Title',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stage,
                  decoration: const InputDecoration(
                    labelText: 'Research Stage',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Group'),
          ),
        ],
      ),
    );

    if (save != true || !mounted) return;

    if (name.text.trim().isEmpty) {
      message(context, 'Group name is required.');
      return;
    }

    try {
      await db.from('groups').insert({
        'name': name.text.trim(),
        'description': description.text.trim(),
        'thesis_title': thesis.text.trim(),
        'research_stage': stage.text.trim(),
        'created_by': userId,
      });

      await loadData();
      if (mounted) message(context, 'Thesis group created!');
    } catch (e) {
      if (mounted) message(context, cleanError(e));
    }
  }

  Future<void> addMember() async {
    final owned = groups.where((g) => g['created_by'] == userId).toList();

    if (owned.isEmpty) {
      message(context, 'Create your own group first.');
      return;
    }

    if (profiles.isEmpty) {
      message(context, 'No registered user profiles found.');
      return;
    }

    String? selectedGroup = '${owned.first['id']}';
    String? selectedUser;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final existing = groupUsers(selectedGroup!)
              .map((m) => '${m['id']}')
              .toSet();

          final available = profiles
              .where((p) => !existing.contains('${p['id']}'))
              .toList();

          if (selectedUser != null &&
              !available.any((p) => p['id'] == selectedUser)) {
            selectedUser = null;
          }

          return AlertDialog(
            title: const Text('Add Group Member'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedGroup,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thesis Group',
                    ),
                    items: owned
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: '${g['id']}',
                            child: Text('${g['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(() {
                      selectedGroup = v;
                      selectedUser = null;
                    }),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedGroup),
                    initialValue: selectedUser,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Registered User',
                    ),
                    items: available
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: '${p['id']}',
                            child: Text(profileName('${p['id']}')),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(() => selectedUser = v),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Only registered users with a profile can be added.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedUser == null
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Add Member'),
              ),
            ],
          );
        },
      ),
    );

    if (save != true || selectedUser == null || !mounted) return;

    try {
      await db.from('group_members').insert({
        'group_id': selectedGroup,
        'user_id': selectedUser,
        'role': 'member',
      });

      await loadData();
      if (mounted) message(context, 'Member added successfully!');
    } catch (e) {
      if (mounted) message(context, cleanError(e));
    }
  }

  Future<void> createTask() async {
    final owned = groups.where((g) => g['created_by'] == userId).toList();

    if (owned.isEmpty) {
      message(context, 'You must be a group leader to assign tasks.');
      return;
    }

    final title = TextEditingController();
    final description = TextEditingController();
    final chapter = TextEditingController();

    String selectedGroup = '${owned.first['id']}';
    String? assignedTo;
    String priority = 'medium';
    DateTime? dueDate;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final users = groupUsers(selectedGroup);

          return AlertDialog(
            title: const Text('Assign New Task'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedGroup,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Thesis Group',
                      ),
                      items: owned
                          .map(
                            (g) => DropdownMenuItem<String>(
                              value: '${g['id']}',
                              child: Text('${g['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => update(() {
                        selectedGroup = v!;
                        assignedTo = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: chapter,
                      decoration: const InputDecoration(
                        labelText: 'Chapter (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('member-$selectedGroup'),
                      initialValue: assignedTo,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assign To',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Unassigned'),
                        ),
                        ...users.map(
                          (u) => DropdownMenuItem<String>(
                            value: '${u['id']}',
                            child: Text('${u['name']}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => update(() => assignedTo = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low',
                          child: Text('Low'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('High'),
                        ),
                      ],
                      onChanged: (v) => update(() => priority = v!),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          update(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        dueDate == null
                            ? 'Choose Due Date'
                            : dateText(dueDate!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save Task'),
              ),
            ],
          );
        },
      ),
    );

    if (save != true || !mounted) return;

    if (title.text.trim().isEmpty) {
      message(context, 'Task title is required.');
      return;
    }

    try {
      await db.from('tasks').insert({
        'group_id': selectedGroup,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'chapter': chapter.text.trim(),
        'assigned_to':
            assignedTo == null || assignedTo!.isEmpty ? null : assignedTo,
        'priority': priority,
        'status': 'pending',
        'due_date': dueDate == null ? null : dateText(dueDate!),
        'created_by': userId,
      });

      await loadData();
      if (mounted) message(context, 'Task assigned successfully!');
    } catch (e) {
      if (mounted) message(context, cleanError(e));
    }
  }

  Future<void> updateStatus(Map<String, dynamic> task, String status) async {
    try {
      await db
          .from('tasks')
          .update({'status': status})
          .eq('id', task['id']);

      await loadData();

      if (mounted) message(context, 'Task status updated!');
    } catch (e) {
      if (mounted) message(context, cleanError(e));
    }
  }

  Future<void> deleteTask(Map<String, dynamic> task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await db.from('tasks').delete().eq('id', task['id']);
      await loadData();
      if (mounted) message(context, 'Task deleted.');
    } catch (e) {
      if (mounted) message(context, cleanError(e));
    }
  }

  void goTo(String destination) {
    setState(() => page = destination);
  }

  Widget sidebarItem(String title, IconData icon) {
    final active = page == title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        tileColor: active ? blue : Colors.transparent,
        leading: Icon(
          icon,
          color: active ? Colors.white : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {
          goTo(title);
          if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget sidebar() {
    return Container(
      width: 250,
      color: navy,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(22),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: blue,
                    child: Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thesis Task\nManagement System',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(25, 20, 0, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WORKSPACE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            sidebarItem('Dashboard', Icons.dashboard_outlined),
            sidebarItem('Thesis Groups', Icons.groups_outlined),
            sidebarItem('Group Members', Icons.people_outline),
            sidebarItem('Assign Tasks', Icons.assignment_add),
            sidebarItem('Group Tasks', Icons.task_alt_outlined),
            const Spacer(),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.white70,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async => db.auth.signOut(),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget panel(Widget child) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: child,
      ),
    );
  }

  Widget statCard(String title, int count, IconData icon, Color color) {
    return panel(
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 27),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    final pending = tasks.where((t) => t['status'] == 'pending').length;
    final progress = tasks.where((t) => t['status'] == 'in progress').length;
    final completed = tasks.where((t) => t['status'] == 'completed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2545B8), Color(0xFF5279EE)],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR THESIS WORKSPACE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Welcome to your Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Manage your thesis groups, organize assignments, '
                'and monitor progress.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        sectionTitle('Task Overview'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 650;

            final cards = [
              statCard(
                'Pending Tasks',
                pending,
                Icons.schedule,
                Colors.orange,
              ),
              statCard(
                'In Progress',
                progress,
                Icons.autorenew,
                blue,
              ),
              statCard(
                'Completed Tasks',
                completed,
                Icons.check_circle_outline,
                Colors.green,
              ),
            ];

            if (!wide) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 25),
        LayoutBuilder(
          builder: (context, constraints) {
            final quick = panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle('Quick Access'),
                  const SizedBox(height: 15),
                  quickButton(
                    'Thesis Groups',
                    Icons.groups,
                    'Thesis Groups',
                  ),
                  quickButton(
                    'Group Tasks',
                    Icons.task_alt,
                    'Group Tasks',
                  ),
                  quickButton(
                    'Assign Tasks',
                    Icons.add_task,
                    'Assign Tasks',
                  ),
                ],
              ),
            );

            final guide = panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle('Task Status Guide'),
                  const SizedBox(height: 20),
                  statusGuide('Pending', Colors.orange),
                  statusGuide('In Progress', blue),
                  statusGuide('Completed', Colors.green),
                ],
              ),
            );

            if (constraints.maxWidth < 650) {
              return Column(
                children: [
                  quick,
                  const SizedBox(height: 12),
                  guide,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: quick),
                const SizedBox(width: 15),
                Expanded(child: guide),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget quickButton(String label, IconData icon, String destination) {
    return ListTile(
      leading: Icon(icon, color: blue),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => goTo(destination),
    );
  }

  Widget statusGuide(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: color,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: navy,
      ),
    );
  }

  Widget actionHeader(
    String title,
    String buttonText,
    VoidCallback action,
  ) {
    return Wrap(
      spacing: 15,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        FilledButton.icon(
          onPressed: action,
          icon: const Icon(Icons.add),
          label: Text(buttonText),
        ),
      ],
    );
  }

  Widget groupsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        actionHeader('Thesis Groups', 'Create Group', createGroup),
        const SizedBox(height: 20),
        if (groups.isEmpty)
          panel(const Text('No thesis groups yet. Create your first group.')),
        for (final g in groups)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${g['name']}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Thesis: ${g['thesis_title'] ?? ''}'),
                const SizedBox(height: 5),
                Text('Description: ${g['description'] ?? ''}'),
                const SizedBox(height: 5),
                Text('Research Stage: ${g['research_stage'] ?? ''}'),
                const SizedBox(height: 8),
                Text(
                  isLeader('${g['id']}') ? 'Role: Group Leader' : 'Role: Member',
                  style: const TextStyle(
                    color: blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget membersPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        actionHeader('Group Members', 'Add Member', addMember),
        const SizedBox(height: 20),
        if (groups.isEmpty)
          panel(const Text('No thesis groups found.')),
        for (final g in groups)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('${g['name']}'),
                const SizedBox(height: 12),
                for (final u in groupUsers('${g['id']}'))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text('${u['name']}'),
                    subtitle: Text(
                      u['id'] == g['created_by']
                          ? 'Group Leader'
                          : 'Group Member',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget tasksPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        actionHeader('Group Tasks', 'Assign Task', createTask),
        const SizedBox(height: 20),
        if (tasks.isEmpty)
          panel(const Text('No tasks yet. Create your first assignment.')),
        for (final task in tasks) taskCard(task),
      ],
    );
  }

  Widget taskCard(Map<String, dynamic> task) {
    final status = '${task['status'] ?? 'pending'}';
    final canManage = isLeader('${task['group_id']}');
    final canChangeStatus =
        canManage || task['assigned_to'] == userId;

    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'in progress'
            ? blue
            : Colors.orange;

    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${task['title']}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          Text('Group: ${groupName('${task['group_id']}')}'),
          Text('Assigned To: ${profileName(task['assigned_to']?.toString())}'),
          Text('Description: ${task['description'] ?? ''}'),
          Text('Chapter: ${task['chapter'] ?? ''}'),
          Text('Priority: ${task['priority'] ?? 'medium'}'),
          Text('Due Date: ${task['due_date'] ?? 'Not set'}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(status.toUpperCase()),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                labelStyle: TextStyle(color: statusColor),
              ),
              if (canChangeStatus)
                PopupMenuButton<String>(
                  tooltip: 'Update Status',
                  onSelected: (value) => updateStatus(task, value),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    PopupMenuItem(
                      value: 'in progress',
                      child: Text('In Progress'),
                    ),
                    PopupMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                  ],
                  child: const Chip(
                    label: Text('Change Status'),
                    avatar: Icon(Icons.edit_outlined, size: 17),
                  ),
                ),
              if (canManage)
                TextButton.icon(
                  onPressed: () => deleteTask(task),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget pageContent() {
    switch (page) {
      case 'Thesis Groups':
        return groupsPage();
      case 'Group Members':
        return membersPage();
      case 'Assign Tasks':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            actionHeader('Assign Tasks', 'Create Task', createTask),
            const SizedBox(height: 20),
            panel(
              const Text(
                'Create assignments for your thesis group members. '
                'Only group leaders can assign tasks.',
              ),
            ),
          ],
        );
      case 'Group Tasks':
        return tasksPage();
      default:
        return dashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 850;

    return Scaffold(
      drawer: desktop ? null : Drawer(child: sidebar()),
      body: Row(
        children: [
          if (desktop) sidebar(),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      if (!desktop)
                        Builder(
                          builder: (ctx) => IconButton(
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                            icon: const Icon(Icons.menu),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'THESIS MANAGEMENT',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              page,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (desktop)
                        Flexible(
                          child: Text(
                            userEmail,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      IconButton(
                        onPressed: loadData,
                        tooltip: 'Refresh Data',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: loadData,
                          child: ListView(
                            padding: const EdgeInsets.all(22),
                            children: [
                              pageContent(),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String dateText(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String cleanError(Object error) {
  if (error is PostgrestException) return error.message;
  if (error is AuthException) return error.message;
  return error.toString();
}

void message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
