import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'database.dart';
import 'models.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
  runApp(const KeprApp());
}

const forest = Color(0xffF85F5A);
const darkForest = Color(0xffB12B2C);
const canvas = Color(0xffF8FAFC);
const orange = Color(0xffF85F5A);

class KeprApp extends StatelessWidget {
  const KeprApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'KEPR Inventory',
        theme: ThemeData(
          useMaterial3: true,
          textTheme: GoogleFonts.manropeTextTheme(),
          colorScheme: ColorScheme.fromSeed(
            seedColor: forest,
            primary: forest,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: canvas,
          fontFamily: 'sans-serif',
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffDFE7E2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffDFE7E2)),
            ),
          ),
        ),
        home: SupabaseConfig.isConfigured
            ? const InventoryAuthGate()
            : const SupabaseSetupScreen(),
      );
}

class InventoryAuthGate extends StatelessWidget {
  const InventoryAuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) =>
            Supabase.instance.client.auth.currentSession == null
                ? const InventorySignInScreen()
                : const InventoryRoleGate(),
      );
}

class InventoryRoleGate extends StatelessWidget {
  const InventoryRoleGate({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<InventoryUser>(
        future: InventoryDatabase.instance.currentUser(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: EmptyState(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Account role not configured',
                message:
                    'Add this user to inventory_users, then sign in again.\n'
                    '${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data!.isAdmin) return const HomeScreen();
          if (snapshot.data!.isFinance) return const FinancePortal();
          return ApartmentPortal(user: snapshot.data!);
        },
      );
}

class InventorySignInScreen extends StatefulWidget {
  const InventorySignInScreen({super.key});

  @override
  State<InventorySignInScreen> createState() => _InventorySignInScreenState();
}

class _InventorySignInScreenState extends State<InventorySignInScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? selectedRole;

  Future<void> signIn() async {
    final login = username.text.trim().toLowerCase();
    final validAdmin = login == 'admin' && password.text == 'admin123';
    final validApartment = selectedRole == 'apartment' &&
        login.isNotEmpty &&
        password.text.isNotEmpty;
    final validFinance = login == 'finance' && password.text == 'finance123';
    final roleMatches = (selectedRole == 'inventory' && validAdmin) ||
        (selectedRole == 'finance' && validFinance) ||
        validApartment;
    if (!roleMatches) {
      showMessage(context, 'Invalid username or password.');
      return;
    }
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: validAdmin
            ? 'admin@kepr.local'
            : validFinance
                ? 'finance@kepr.local'
                : '$login@kepr.local',
        password: password.text,
      );
    } on AuthException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: selectedRole == null ? 760 : 430,
              ),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xffE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/brand/kepr_icon.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('KEPR',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900)),
                                Text('INVENTORY',
                                    style: TextStyle(
                                        fontSize: 10, letterSpacing: 2)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (selectedRole == null) ...[
                        const Text('Choose your workspace',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        const Text(
                          'Select a role to continue to the correct dashboard.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _RoleOption(
                              icon: Icons.warehouse_outlined,
                              title: 'Inventory & Warehouse',
                              message:
                                  'Stock, availability checks, issues and logs',
                              onTap: () =>
                                  setState(() => selectedRole = 'inventory'),
                            ),
                            _RoleOption(
                              icon: Icons.account_balance_outlined,
                              title: 'Finance',
                              message:
                                  'Review demand tickets and approve budgets',
                              onTap: () =>
                                  setState(() => selectedRole = 'finance'),
                            ),
                            _RoleOption(
                              icon: Icons.apartment_outlined,
                              title: 'Apartment',
                              message:
                                  'View stock, raise demand and record usage',
                              onTap: () =>
                                  setState(() => selectedRole = 'apartment'),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          selectedRole == 'inventory'
                              ? 'Inventory & Warehouse login'
                              : selectedRole == 'finance'
                                  ? 'Finance login'
                                  : 'Apartment login',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selectedRole == 'apartment'
                              ? 'Use the username mapped to your apartment.'
                              : 'Sign in with your assigned KEPR account.',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: username,
                          decoration: InputDecoration(
                            labelText: selectedRole == 'apartment'
                                ? 'Apartment username'
                                : 'Username',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          onSubmitted: (_) => signIn(),
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: loading ? null : signIn,
                          child: Text(loading ? 'Signing in…' : 'Sign in'),
                        ),
                        TextButton.icon(
                          onPressed: loading
                              ? null
                              : () => setState(() {
                                    selectedRole = null;
                                    username.clear();
                                    password.clear();
                                  }),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Choose another workspace'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffE2E8F0)),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: forest, size: 28),
                const SizedBox(height: 14),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(message,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
}

class _AppBarBrand extends StatelessWidget {
  const _AppBarBrand(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/brand/kepr_icon.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KEPR', style: TextStyle(fontWeight: FontWeight.w900)),
              Text(label.toUpperCase(),
                  style: const TextStyle(fontSize: 9, letterSpacing: 1.4)),
            ],
          ),
        ],
      );
}

class SupabaseSetupScreen extends StatelessWidget {
  const SupabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: forest,
                    foregroundColor: Colors.white,
                    child: Text(
                      'K',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Connect KEPR Inventory',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Run with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
                    'using --dart-define.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  int revision = 0;

  void changed() => setState(() => revision++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(key: ValueKey('dashboard-$revision'), onChanged: changed),
      WarehousePage(key: ValueKey('warehouse-$revision'), onChanged: changed),
      ApartmentsPage(key: ValueKey('apartments-$revision'), onChanged: changed),
      RequestsPage(key: ValueKey('requests-$revision'), onChanged: changed),
      TransfersPage(key: ValueKey('transfers-$revision'), onChanged: changed),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkForest,
        foregroundColor: Colors.white,
        title: const _AppBarBrand('Inventory & Warehouse'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Apartments',
          ),
          NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            selectedIcon: Icon(Icons.approval),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Stock log',
          ),
        ],
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
    super.key,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.onChanged, super.key});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: Future.wait([
          InventoryDatabase.instance.products(),
          InventoryDatabase.instance.apartments(),
          InventoryDatabase.instance.weeklyInsights(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data![0] as List<Product>;
          final apartments = snapshot.data![1] as List<Apartment>;
          final weekly = snapshot.data![2] as List<WeeklyInsight>;
          final value = products.fold<double>(0, (sum, p) => sum + p.value);
          final low = products.where((p) => p.isLow).length;
          double weeklyValue(String metric) => weekly
              .where(
                  (item) => item.scope == 'warehouse' && item.metric == metric)
              .fold(0, (sum, item) => sum + item.value);
          return PageShell(
            title: 'Good inventory starts here.',
            subtitle: DateFormat('EEEE, d MMMM').format(DateTime.now()),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    MetricCard(
                      label: 'Warehouse value',
                      value: inr(value),
                      icon: Icons.currency_rupee,
                    ),
                    MetricCard(
                      label: 'Products',
                      value: '${products.length}',
                      icon: Icons.inventory_2_outlined,
                    ),
                    MetricCard(
                      label: 'Apartments',
                      value: '${apartments.length}',
                      icon: Icons.apartment,
                    ),
                    MetricCard(
                      label: 'Low stock',
                      value: '$low',
                      icon: Icons.warning_amber_rounded,
                      warning: low > 0,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SectionCard(
                  title: 'Last 7 days',
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.south_west,
                              color: Color(0xff3F9A6E)),
                          title: const Text('Received'),
                          subtitle: Text(number(weeklyValue('Stock received'))),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.north_east, color: forest),
                          title: const Text('Issued'),
                          subtitle: Text(number(weeklyValue('Stock issued'))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  title: 'Needs attention',
                  child: products.where((p) => p.isLow).isEmpty
                      ? const EmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'Stock looks healthy',
                          message: 'No products are below their reorder level.',
                        )
                      : Column(
                          children: products
                              .where((p) => p.isLow)
                              .take(5)
                              .map(ProductTile.new)
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      );
}

class WarehousePage extends StatelessWidget {
  const WarehousePage({required this.onChanged, super.key});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
        future: InventoryDatabase.instance.products(),
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          return PageShell(
            title: 'Warehouse stock',
            subtitle: 'Live quantities and valuation.',
            action: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showProductForm(context, onChanged),
                  icon: const Icon(Icons.add),
                  label: const Text('New product'),
                ),
                FilledButton.icon(
                  onPressed: () => showStockInForm(context, onChanged),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Stock in'),
                ),
              ],
            ),
            child: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : SectionCard(
                    title: '${products.length} products',
                    child: products.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products yet',
                            message: 'Add the first warehouse product.',
                          )
                        : Column(
                            children: products
                                .map(
                                  (p) => InkWell(
                                    onTap: () =>
                                        showProductForm(context, onChanged, p),
                                    child: ProductTile(p),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
          );
        },
      );
}

class ApartmentsPage extends StatelessWidget {
  const ApartmentsPage({required this.onChanged, super.key});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Apartment>>(
        future: InventoryDatabase.instance.apartments(),
        builder: (context, snapshot) {
          final apartments = snapshot.data ?? [];
          return PageShell(
            title: 'Apartment inventory',
            subtitle: 'Customer locations and distributed stock.',
            action: FilledButton.icon(
              onPressed: () => showApartmentForm(context, onChanged),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
            child: SectionCard(
              title: '${apartments.length} locations',
              child: apartments.isEmpty
                  ? const EmptyState(
                      icon: Icons.apartment,
                      title: 'No apartments',
                      message: 'Create a customer location to begin.',
                    )
                  : Column(
                      children: apartments
                          .map(
                            (a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xffE2F1E9),
                                foregroundColor: forest,
                                child: Icon(Icons.apartment),
                              ),
                              title: Text(
                                a.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text('${a.itemCount} products'),
                              trailing: Text(
                                inr(a.stockValue),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ApartmentDetailPage(
                                    apartment: a,
                                    onChanged: onChanged,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          );
        },
      );
}

class ApartmentDetailPage extends StatefulWidget {
  const ApartmentDetailPage({
    required this.apartment,
    required this.onChanged,
    super.key,
  });
  final Apartment apartment;
  final VoidCallback onChanged;

  @override
  State<ApartmentDetailPage> createState() => _ApartmentDetailPageState();
}

class _ApartmentDetailPageState extends State<ApartmentDetailPage> {
  int revision = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.apartment.name)),
        body: FutureBuilder<List<ApartmentStock>>(
          key: ValueKey(revision),
          future:
              InventoryDatabase.instance.apartmentStock(widget.apartment.id),
          builder: (context, snapshot) {
            final stock = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                SectionCard(
                  title: 'Current stock',
                  child: stock.isEmpty
                      ? const EmptyState(
                          icon: Icons.move_to_inbox_outlined,
                          title: 'No stock allocated',
                          message: 'Complete a warehouse transfer first.',
                        )
                      : Column(
                          children: stock
                              .map(
                                (s) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    s.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Use ${number(s.monthlyUse)}/month · '
                                    '${s.daysRemaining == null ? 'No usage set' : '${number(s.daysRemaining!)} days left'}',
                                  ),
                                  trailing:
                                      Text('${number(s.quantity)} ${s.unit}'),
                                  onTap: () async {
                                    final changed = await showUsageForm(
                                      context,
                                      widget.apartment,
                                      s,
                                    );
                                    if (changed && mounted) {
                                      setState(() => revision++);
                                      widget.onChanged();
                                    }
                                  },
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
      );
}

class TransfersPage extends StatelessWidget {
  const TransfersPage({required this.onChanged, super.key});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<StockMovement>>(
        future: InventoryDatabase.instance.movements(),
        builder: (context, snapshot) {
          final movements = snapshot.data ?? [];
          return PageShell(
            title: 'Stock movement',
            subtitle:
                'Receipts and approved apartment demand in one audit trail.',
            action: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoicesPage()),
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Invoices'),
                ),
                FilledButton.icon(
                  onPressed: () => showStockInForm(context, onChanged),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Stock in'),
                ),
              ],
            ),
            child: Column(
              children: [
                SectionCard(
                  title: 'Stock log · ${movements.length} entries',
                  child: movements.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No stock movements',
                          message:
                              'Use Stock in or Move out to create the first log.',
                        )
                      : Column(
                          children: movements
                              .map(
                                (movement) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: movement.isReceipt
                                        ? const Color(0xffE3F4EB)
                                        : const Color(0xffFFF0EC),
                                    child: Icon(
                                      movement.isReceipt
                                          ? Icons.south_west
                                          : Icons.north_east,
                                      color: movement.isReceipt
                                          ? const Color(0xff3F9A6E)
                                          : forest,
                                    ),
                                  ),
                                  title: Text(
                                    movement.isReceipt
                                        ? 'Received into warehouse'
                                        : 'Moved to ${movement.destination}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${movement.reference}\n'
                                    '${movement.date} · ${movement.lineCount} items',
                                  ),
                                  isThreeLine: true,
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${movement.isReceipt ? '+' : '−'}'
                                        '${number(movement.totalQuantity)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: movement.isReceipt
                                              ? const Color(0xff3F9A6E)
                                              : forest,
                                        ),
                                      ),
                                      Text(inr(movement.totalValue)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      );
}

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? exactDate;

  List<DateTime> get months => List.generate(
        18,
        (index) => DateTime(DateTime.now().year, DateTime.now().month - index),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: darkForest,
          foregroundColor: Colors.white,
          title: const _AppBarBrand('Invoice register'),
        ),
        body: FutureBuilder<List<InvoiceRecord>>(
          future: InventoryDatabase.instance.invoices(
            month: month,
            exactDate: exactDate,
          ),
          builder: (context, snapshot) {
            final invoices = snapshot.data ?? [];
            return PageShell(
              title: 'Invoice register',
              subtitle:
                  'Private bills mapped to fulfilled apartment demand tickets.',
              child: Column(
                children: [
                  SectionCard(
                    title: 'Find invoices',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<DateTime>(
                            initialValue: month,
                            decoration:
                                const InputDecoration(labelText: 'Month'),
                            items: months
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                        DateFormat('MMMM yyyy').format(value)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              month = value!;
                              exactDate = null;
                            }),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDate: exactDate ?? DateTime.now(),
                            );
                            if (selected != null) {
                              setState(() => exactDate = selected);
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: Text(exactDate == null
                              ? 'Search exact date'
                              : DateFormat('d MMM yyyy').format(exactDate!)),
                        ),
                        if (exactDate != null)
                          TextButton.icon(
                            onPressed: () => setState(() => exactDate = null),
                            icon: const Icon(Icons.close),
                            label: const Text('Clear date'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title:
                        '${exactDate == null ? DateFormat('MMMM yyyy').format(month) : DateFormat('d MMMM yyyy').format(exactDate!)} · ${invoices.length} invoices',
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : invoices.isEmpty
                            ? const EmptyState(
                                icon: Icons.description_outlined,
                                title: 'No invoices found',
                                message:
                                    'Try another month or clear the date filter.',
                              )
                            : Column(
                                children: invoices
                                    .map(
                                      (invoice) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xffFFF0EC),
                                          child: Icon(Icons.picture_as_pdf,
                                              color: forest),
                                        ),
                                        title: Text(
                                          invoice.invoiceNumber,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                        subtitle: Text(
                                          '${invoice.apartment} · ${invoice.requestReference}\n'
                                          '${invoice.invoiceDate} · ${invoice.originalFilename}',
                                        ),
                                        isThreeLine: true,
                                        trailing: IconButton(
                                          tooltip: 'Open invoice',
                                          onPressed: () async {
                                            final url = await InventoryDatabase
                                                .instance
                                                .invoiceDownloadUrl(
                                              invoice.storagePath,
                                            );
                                            await launchUrl(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          },
                                          icon: const Icon(Icons.open_in_new),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class RequestsPage extends StatelessWidget {
  const RequestsPage({required this.onChanged, super.key});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: Future.wait([
          InventoryDatabase.instance.requests(),
          InventoryDatabase.instance.monthlyUsage(),
        ]),
        builder: (context, snapshot) {
          final requests =
              snapshot.hasData ? snapshot.data![0] as List<StockRequest> : [];
          final usage =
              snapshot.hasData ? snapshot.data![1] as List<UsageSummary> : [];
          final pending = requests.where((request) =>
              request.status == 'pending_inventory' ||
              request.status == 'finance_approved');
          return PageShell(
            title: 'Demand approvals',
            subtitle:
                'Apartment demand moves stock only after inventory approval.',
            action: IconButton.filledTonal(
              tooltip: 'Refresh tickets',
              onPressed: onChanged,
              icon: const Icon(Icons.refresh),
            ),
            child: Column(
              children: [
                SectionCard(
                  title: 'Warehouse action · ${pending.length}',
                  child: pending.isEmpty
                      ? const EmptyState(
                          icon: Icons.task_alt,
                          title: 'Queue is clear',
                          message: 'New apartment demand will appear here.',
                        )
                      : Column(
                          children: pending
                              .map(
                                (request) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xffFFF0EC),
                                    child: Icon(Icons.pending_actions,
                                        color: forest),
                                  ),
                                  title: Text(request.apartment,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  subtitle: Text(
                                    '${request.reference} · ${request.lineCount} items\n'
                                    '${number(request.totalQuantity)} units · ${request.note}\n'
                                    '${request.status == 'finance_approved' ? 'Finance approved · invoice required' : 'Awaiting availability check'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: request.status ==
                                            'pending_inventory'
                                        ? [
                                            IconButton(
                                              tooltip: 'Reject',
                                              onPressed: () async {
                                                await InventoryDatabase.instance
                                                    .checkRequest(
                                                  request.id,
                                                  forward: false,
                                                );
                                                onChanged();
                                              },
                                              icon: const Icon(Icons.close,
                                                  color: Colors.red),
                                            ),
                                            FilledButton(
                                              onPressed: () async {
                                                try {
                                                  await InventoryDatabase
                                                      .instance
                                                      .checkRequest(
                                                    request.id,
                                                    forward: true,
                                                  );
                                                  onChanged();
                                                } catch (error) {
                                                  if (context.mounted) {
                                                    showMessage(context,
                                                        readableError(error));
                                                  }
                                                }
                                              },
                                              child: const Text('Send finance'),
                                            ),
                                          ]
                                        : [
                                            FilledButton.icon(
                                              onPressed: () =>
                                                  showFulfillRequestDialog(
                                                context,
                                                request,
                                                onChanged,
                                              ),
                                              icon: const Icon(
                                                  Icons.receipt_long),
                                              label: const Text('Issue stock'),
                                            ),
                                          ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Monthly apartment usage',
                  child: usage.isEmpty
                      ? const EmptyState(
                          icon: Icons.query_stats,
                          title: 'No usage recorded',
                          message:
                              'Apartment consumption totals will appear here.',
                        )
                      : Column(
                          children: usage
                              .take(30)
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.apartment,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle:
                                      Text('${item.month} · ${item.product}'),
                                  trailing: Text(
                                    '${number(item.quantity)} ${item.unit}\n'
                                    '${inr(item.value)}',
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      );
}

class FinancePortal extends StatefulWidget {
  const FinancePortal({super.key});

  @override
  State<FinancePortal> createState() => _FinancePortalState();
}

class _FinancePortalState extends State<FinancePortal> {
  int revision = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: darkForest,
          foregroundColor: Colors.white,
          title: const _AppBarBrand('Finance'),
          actions: [
            IconButton(
              tooltip: 'Invoice register',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvoicesPage()),
              ),
              icon: const Icon(Icons.description_outlined),
            ),
            IconButton(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: FutureBuilder<List<StockRequest>>(
          key: ValueKey(revision),
          future: InventoryDatabase.instance.requests(),
          builder: (context, snapshot) {
            final tickets = (snapshot.data ?? [])
                .where((request) => request.status == 'pending_finance')
                .toList();
            return PageShell(
              title: 'Demand tickets',
              subtitle:
                  'Inventory has confirmed availability. Approve or reject only.',
              child: SectionCard(
                title: 'Awaiting finance · ${tickets.length}',
                child: tickets.isEmpty
                    ? const EmptyState(
                        icon: Icons.verified_outlined,
                        title: 'Nothing to approve',
                        message:
                            'Inventory-checked demand tickets will appear here.',
                      )
                    : Column(
                        children: tickets
                            .map((ticket) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xffFFF0EC),
                                    child: Icon(Icons.request_quote,
                                        color: forest),
                                  ),
                                  title: Text(ticket.apartment,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  subtitle: Text(
                                    '${ticket.reference} · ${ticket.lineCount} items\n'
                                    '${number(ticket.totalQuantity)} units · ${inr(ticket.totalValue)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () async {
                                          await InventoryDatabase.instance
                                              .financeReview(ticket.id,
                                                  approve: false);
                                          setState(() => revision++);
                                        },
                                        child: const Text('Reject'),
                                      ),
                                      FilledButton(
                                        onPressed: () async {
                                          await InventoryDatabase.instance
                                              .financeReview(ticket.id,
                                                  approve: true);
                                          setState(() => revision++);
                                        },
                                        child: const Text('Approve'),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
              ),
            );
          },
        ),
      );
}

class ApartmentPortal extends StatefulWidget {
  const ApartmentPortal({required this.user, super.key});
  final InventoryUser user;

  @override
  State<ApartmentPortal> createState() => _ApartmentPortalState();
}

class _ApartmentPortalState extends State<ApartmentPortal> {
  int index = 0;
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final apartmentId = widget.user.apartmentId!;
    final pages = [
      ApartmentStockPage(
        key: ValueKey('apt-stock-$revision'),
        apartmentId: apartmentId,
      ),
      ApartmentDemandPage(
        key: ValueKey('apt-demand-$revision'),
        onChanged: () => setState(() => revision++),
      ),
      ApartmentUsagePage(
        key: ValueKey('apt-usage-$revision'),
        apartmentId: apartmentId,
        onChanged: () => setState(() => revision++),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkForest,
        foregroundColor: Colors.white,
        title: _AppBarBrand(widget.user.displayName.isEmpty
            ? 'Apartment'
            : widget.user.displayName),
        actions: [
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'My stock'),
          NavigationDestination(
              icon: Icon(Icons.add_shopping_cart), label: 'Demand'),
          NavigationDestination(icon: Icon(Icons.query_stats), label: 'Usage'),
        ],
      ),
    );
  }
}

class ApartmentStockPage extends StatelessWidget {
  const ApartmentStockPage({required this.apartmentId, super.key});
  final int apartmentId;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<ApartmentStock>>(
        future: InventoryDatabase.instance.apartmentStock(apartmentId),
        builder: (context, snapshot) {
          final stock = snapshot.data ?? [];
          return PageShell(
            title: 'Available stock',
            subtitle: 'Inventory currently issued to your apartment.',
            child: SectionCard(
              title: '${stock.length} products available',
              child: stock.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No stock available',
                      message: 'Raise a demand request for required products.',
                    )
                  : Column(
                      children: stock
                          .map((item) => ListTile(
                                title: Text(item.productName),
                                subtitle: Text(inr(item.unitPrice)),
                                trailing: Text(
                                  '${number(item.quantity)} ${item.unit}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ))
                          .toList(),
                    ),
            ),
          );
        },
      );
}

class ApartmentDemandPage extends StatelessWidget {
  const ApartmentDemandPage({required this.onChanged, super.key});
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<StockRequest>>(
        future: InventoryDatabase.instance.requests(),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? [];
          return PageShell(
            title: 'Stock demand',
            subtitle:
                'Requests need Main Inventory approval before stock moves.',
            action: FilledButton.icon(
              onPressed: () => showDemandForm(context, onChanged),
              icon: const Icon(Icons.add),
              label: const Text('Raise demand'),
            ),
            child: SectionCard(
              title: 'My requests',
              child: requests.isEmpty
                  ? const EmptyState(
                      icon: Icons.pending_actions,
                      title: 'No demand requests',
                      message: 'Raise a request when stock is required.',
                    )
                  : Column(
                      children: requests
                          .map((request) => ListTile(
                                title: Text(request.reference),
                                subtitle: Text(
                                    '${request.lineCount} items · ${request.note}'),
                                trailing: StatusPill(
                                  text: request.status.toUpperCase(),
                                  warning: request.status == 'pending',
                                ),
                              ))
                          .toList(),
                    ),
            ),
          );
        },
      );
}

class ApartmentUsagePage extends StatelessWidget {
  const ApartmentUsagePage({
    required this.apartmentId,
    required this.onChanged,
    super.key,
  });
  final int apartmentId;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: Future.wait([
          InventoryDatabase.instance.monthlyUsage(),
          InventoryDatabase.instance.weeklyInsights(),
        ]),
        builder: (context, snapshot) {
          final usage =
              snapshot.hasData ? snapshot.data![0] as List<UsageSummary> : [];
          final weekly =
              snapshot.hasData ? snapshot.data![1] as List<WeeklyInsight> : [];
          double weeklyValue(String metric) => weekly
              .where((item) =>
                  item.apartmentId == apartmentId && item.metric == metric)
              .fold(0, (sum, item) => sum + item.value);
          return PageShell(
            title: 'Monthly usage',
            subtitle: 'Record consumed stock to keep availability accurate.',
            action: FilledButton.icon(
              onPressed: () =>
                  showRecordUsageForm(context, apartmentId, onChanged),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Record usage'),
            ),
            child: Column(
              children: [
                SectionCard(
                  title: 'Last 7 days',
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Consumed'),
                          subtitle: Text(number(weeklyValue('Stock consumed'))),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Demands raised'),
                          subtitle: Text(number(weeklyValue('Demand raised'))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Consumption history',
                  child: usage.isEmpty
                      ? const EmptyState(
                          icon: Icons.query_stats,
                          title: 'No usage recorded',
                          message: 'Record consumption as items are used.',
                        )
                      : Column(
                          children: usage
                              .map((item) => ListTile(
                                    title: Text(item.product),
                                    subtitle: Text(item.month),
                                    trailing: Text(
                                        '${number(item.quantity)} ${item.unit}'),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      );
}

class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: Future.wait([
          InventoryDatabase.instance.products(),
          InventoryDatabase.instance.apartments(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data![0] as List<Product>;
          final apartments = snapshot.data![1] as List<Apartment>;
          return FutureBuilder<List<List<ApartmentStock>>>(
            future: Future.wait(
              apartments.map(
                (a) => InventoryDatabase.instance.apartmentStock(a.id),
              ),
            ),
            builder: (context, stockSnapshot) {
              final all = stockSnapshot.data ?? [];
              return PageShell(
                title: '30-day forecast',
                subtitle: 'Requirements based on monthly consumption.',
                child: products.isEmpty
                    ? const SectionCard(
                        title: 'Forecast',
                        child: EmptyState(
                          icon: Icons.query_stats,
                          title: 'No data yet',
                          message: 'Add products and monthly usage first.',
                        ),
                      )
                    : Column(
                        children: products.map((product) {
                          final items = all
                              .expand((e) => e)
                              .where((s) => s.productId == product.id)
                              .toList();
                          final need =
                              items.fold<double>(0, (sum, s) => sum + s.need30);
                          final shortfall = (need - product.quantity)
                              .clamp(0, double.infinity)
                              .toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SectionCard(
                              title: product.name,
                              trailing: StatusPill(
                                text: shortfall > 0
                                    ? 'Short ${number(shortfall)}'
                                    : 'Covered',
                                warning: shortfall > 0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Warehouse ${number(product.quantity)} ${product.unit} · '
                                    '30-day need ${number(need)} ${product.unit}',
                                    style:
                                        const TextStyle(color: Colors.black54),
                                  ),
                                  if (items.isNotEmpty) ...[
                                    const Divider(height: 24),
                                    ...items.map(
                                      (s) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(s.apartmentName),
                                            ),
                                            Text(
                                              'Need ${number(s.need30)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              );
            },
          );
        },
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
    super.key,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) => Card(
        color: warning ? const Color(0xffFFF1EB) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: warning ? const Color(0xffF7D3C6) : const Color(0xffE2E9E5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: warning ? orange : forest, size: 20),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffE2E9E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class ProductTile extends StatelessWidget {
  const ProductTile(this.product, {super.key});
  final Product product;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: const Color(0xffE2F1E9),
          foregroundColor: forest,
          child: Text(
            product.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${inr(product.unitPrice)} / ${product.unit}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${number(product.quantity)} ${product.unit}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            StatusPill(
              text: product.isLow ? 'Low stock' : 'Healthy',
              warning: product.isLow,
            ),
          ],
        ),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.text,
    required this.warning,
    super.key,
  });
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: warning ? const Color(0xffFFE8DF) : const Color(0xffE2F1E9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: warning ? const Color(0xffB94B2B) : forest,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Center(
          child: Column(
            children: [
              Icon(icon, color: Colors.black26, size: 36),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
}

Future<void> showProductForm(
  BuildContext context,
  VoidCallback onSaved, [
  Product? product,
]) async {
  final name = TextEditingController(text: product?.name);
  final quantity = TextEditingController(text: '${product?.quantity ?? 0}');
  final price = TextEditingController(text: '${product?.unitPrice ?? 0}');
  final reorder = TextEditingController(text: '${product?.reorderLevel ?? 0}');
  final notes = TextEditingController(text: product?.notes);
  var unit = product?.unit ?? 'Pcs';
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                product == null ? 'Add product' : 'Edit product',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: ['Pcs', 'Liters', 'Kg', 'Packets', 'Bottles']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (value) => setSheetState(() => unit = value!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: NumberField('Quantity', quantity)),
                  const SizedBox(width: 10),
                  Expanded(child: NumberField('Unit price', price)),
                ],
              ),
              const SizedBox(height: 12),
              NumberField('Reorder level', reorder),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  try {
                    await InventoryDatabase.instance.saveProduct(
                      id: product?.id,
                      name: name.text,
                      unit: unit,
                      quantity: double.tryParse(quantity.text) ?? 0,
                      unitPrice: double.tryParse(price.text) ?? 0,
                      reorderLevel: double.tryParse(reorder.text) ?? 0,
                      notes: notes.text,
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    onSaved();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      showMessage(sheetContext, readableError(error));
                    }
                  }
                },
                child: const Text('Save product'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showApartmentForm(
  BuildContext context,
  VoidCallback onSaved,
) async {
  final name = TextEditingController();
  final contact = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add apartment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Apartment name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contact,
            decoration:
                const InputDecoration(labelText: 'Contact / notes (optional)'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              try {
                await InventoryDatabase.instance
                    .addApartment(name.text, contact.text);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                onSaved();
              } catch (error) {
                if (sheetContext.mounted) {
                  showMessage(sheetContext, readableError(error));
                }
              }
            },
            child: const Text('Add apartment'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> showUsageForm(
  BuildContext context,
  Apartment apartment,
  ApartmentStock stock,
) async {
  final usage = TextEditingController(text: '${stock.monthlyUse}');
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(stock.productName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${number(stock.quantity)} ${stock.unit} available'),
          const SizedBox(height: 14),
          NumberField('Average monthly use', usage),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await InventoryDatabase.instance.updateUsage(
              apartment.id,
              stock.productId,
              double.tryParse(usage.text) ?? 0,
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showFulfillRequestDialog(
  BuildContext context,
  StockRequest request,
  VoidCallback onSaved,
) async {
  final invoice = TextEditingController();
  var invoiceDate = DateTime.now();
  PlatformFile? selectedFile;
  var uploading = false;
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Issue approved stock'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${request.reference} · ${request.apartment}'),
              const SizedBox(height: 14),
              TextField(
                controller: invoice,
                decoration: const InputDecoration(
                  labelText: 'Invoice number',
                  hintText: 'Example: INV-2026-0184',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDate: invoiceDate,
                        );
                        if (date != null) {
                          setDialogState(() => invoiceDate = date);
                        }
                      },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'Invoice date · ${DateFormat('d MMM yyyy').format(invoiceDate)}',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'pdf',
                            'jpg',
                            'jpeg',
                            'png',
                            'webp'
                          ],
                          withData: true,
                        );
                        if (result != null) {
                          final file = result.files.single;
                          if (file.size > 10485760) {
                            if (dialogContext.mounted) {
                              showMessage(dialogContext,
                                  'Invoice file must be 10 MB or smaller.');
                            }
                            return;
                          }
                          setDialogState(() => selectedFile = file);
                        }
                      },
                icon: const Icon(Icons.attach_file),
                label: Text(selectedFile?.name ?? 'Select invoice file'),
              ),
              if (selectedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB · '
                    'PDF, JPG, PNG or WebP',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: uploading ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: uploading
                ? null
                : () async {
                    if (invoice.text.trim().isEmpty || selectedFile == null) {
                      showMessage(dialogContext,
                          'Invoice number and invoice file are required.');
                      return;
                    }
                    final bytes = selectedFile!.bytes;
                    if (bytes == null) {
                      showMessage(
                          dialogContext, 'Could not read invoice file.');
                      return;
                    }
                    setDialogState(() => uploading = true);
                    try {
                      final transfer = await InventoryDatabase.instance
                          .uploadInvoiceAndFulfill(
                        requestId: request.id,
                        invoiceNumber: invoice.text,
                        invoiceDate:
                            invoiceDate.toIso8601String().substring(0, 10),
                        filename: selectedFile!.name,
                        mimeType: invoiceMimeType(selectedFile!.extension),
                        bytes: bytes,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        showMessage(context, 'Stock issued as $transfer.');
                      }
                      onSaved();
                    } catch (error) {
                      if (dialogContext.mounted) {
                        showMessage(dialogContext, readableError(error));
                        setDialogState(() => uploading = false);
                      }
                    }
                  },
            icon: uploading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(uploading ? 'Uploading…' : 'Upload & issue stock'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showDemandForm(
  BuildContext context,
  VoidCallback onSaved,
) async {
  final products = await InventoryDatabase.instance.products();
  if (!context.mounted || products.isEmpty) return;
  final productId = ValueNotifier<int>(products.first.id);
  final quantity = TextEditingController();
  final note = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Raise stock demand',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ValueListenableBuilder(
            valueListenable: productId,
            builder: (context, value, _) => DropdownButtonFormField<int>(
              initialValue: value,
              decoration: const InputDecoration(labelText: 'Product'),
              items: products
                  .map((p) => DropdownMenuItem(
                      value: p.id,
                      child:
                          Text('${p.name} · ${number(p.quantity)} available')))
                  .toList(),
              onChanged: (value) => productId.value = value!,
            ),
          ),
          const SizedBox(height: 12),
          NumberField('Required quantity', quantity),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration:
                const InputDecoration(labelText: 'Reason / requirement note'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              try {
                final reference =
                    await InventoryDatabase.instance.createRequest(
                  [
                    TransferLine(
                      productId: productId.value,
                      quantity: double.tryParse(quantity.text) ?? 0,
                    ),
                  ],
                  note.text,
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (context.mounted) {
                  showMessage(context, 'Demand $reference submitted.');
                }
                onSaved();
              } catch (error) {
                if (sheetContext.mounted) {
                  showMessage(sheetContext, readableError(error));
                }
              }
            },
            child: const Text('Submit for approval'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showRecordUsageForm(
  BuildContext context,
  int apartmentId,
  VoidCallback onSaved,
) async {
  final stock = await InventoryDatabase.instance.apartmentStock(apartmentId);
  if (!context.mounted) return;
  if (stock.isEmpty) {
    showMessage(context, 'No apartment stock is available to consume.');
    return;
  }
  var productId = stock.first.productId;
  final quantity = TextEditingController();
  final note = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Record stock usage',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: productId,
              decoration: const InputDecoration(labelText: 'Product'),
              items: stock
                  .map((item) => DropdownMenuItem(
                        value: item.productId,
                        child: Text(
                            '${item.productName} · ${number(item.quantity)} available'),
                      ))
                  .toList(),
              onChanged: (value) => productId = value!,
            ),
            const SizedBox(height: 12),
            NumberField('Quantity used', quantity),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Usage note'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                try {
                  await InventoryDatabase.instance.recordUsage(
                    productId: productId,
                    quantity: double.tryParse(quantity.text) ?? 0,
                    note: note.text,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  onSaved();
                } catch (error) {
                  if (sheetContext.mounted) {
                    showMessage(sheetContext, readableError(error));
                  }
                }
              },
              child: const Text('Record consumption'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showStockInForm(
  BuildContext context,
  VoidCallback onSaved,
) async {
  final products = await InventoryDatabase.instance.products();
  if (!context.mounted) return;
  if (products.isEmpty) {
    showMessage(context, 'Add a product before receiving stock.');
    return;
  }
  final lines = <TransferLine>[
    TransferLine(productId: products.first.id, quantity: 0),
  ];
  final note = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Receive stock',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Adds inventory to the warehouse and creates a receipt log.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              ...lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: line.productId,
                          decoration:
                              const InputDecoration(labelText: 'Product'),
                          items: products
                              .map(
                                (product) => DropdownMenuItem(
                                  value: product.id,
                                  child: Text(product.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => line.productId = value!,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Quantity'),
                          onChanged: (value) =>
                              line.quantity = double.tryParse(value) ?? 0,
                        ),
                      ),
                      if (lines.length > 1)
                        IconButton(
                          onPressed: () =>
                              setSheetState(() => lines.removeAt(index)),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () => setSheetState(
                  () => lines.add(
                    TransferLine(
                      productId: products.first.id,
                      quantity: 0,
                    ),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add another item'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Supplier / invoice / note',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    final reference =
                        await InventoryDatabase.instance.receiveStock(
                      date: DateTime.now().toIso8601String().substring(0, 10),
                      lines: lines,
                      note: note.text,
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (context.mounted) {
                      showMessage(context, 'Receipt $reference completed.');
                    }
                    onSaved();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      showMessage(sheetContext, readableError(error));
                    }
                  }
                },
                icon: const Icon(Icons.inventory),
                label: const Text('Receive into warehouse'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showTransferForm(
  BuildContext context,
  VoidCallback onSaved,
) async {
  final products = await InventoryDatabase.instance.products();
  final apartments = await InventoryDatabase.instance.apartments();
  if (!context.mounted) return;
  if (products.isEmpty || apartments.isEmpty) {
    showMessage(context, 'Add a product and an apartment first.');
    return;
  }
  var apartmentId = apartments.first.id;
  final lines = <TransferLine>[
    TransferLine(productId: products.first.id, quantity: 0),
  ];
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New stock transfer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const Text(
                'All lines commit together or roll back.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: apartmentId,
                decoration: const InputDecoration(labelText: 'Apartment'),
                items: apartments
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => apartmentId = value!,
              ),
              const SizedBox(height: 14),
              ...lines.asMap().entries.map((entry) {
                final i = entry.key;
                final line = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: line.productId,
                          decoration:
                              const InputDecoration(labelText: 'Product'),
                          items: products
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    '${p.name} (${number(p.quantity)})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => line.productId = value!,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty'),
                          onChanged: (value) =>
                              line.quantity = double.tryParse(value) ?? 0,
                        ),
                      ),
                      if (lines.length > 1)
                        IconButton(
                          onPressed: () =>
                              setSheetState(() => lines.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () => setSheetState(
                  () => lines.add(
                    TransferLine(productId: products.first.id, quantity: 0),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () async {
                  try {
                    final reference = await InventoryDatabase.instance.transfer(
                      apartmentId: apartmentId,
                      date: DateTime.now().toIso8601String().substring(0, 10),
                      lines: lines,
                    );
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                      showMessage(context, 'Transfer $reference completed.');
                    }
                    onSaved();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      showMessage(sheetContext, readableError(error));
                    }
                  }
                },
                child: const Text('Complete transfer'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class NumberField extends StatelessWidget {
  const NumberField(this.label, this.controller, {super.key});
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      );
}

String number(double value) =>
    NumberFormat.decimalPatternDigits(locale: 'en_IN', decimalDigits: 1)
        .format(value);
String inr(double value) => NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
String invoiceMimeType(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}

String readableError(Object error) {
  final message = error.toString().replaceFirst('Bad state: ', '');
  if (message.contains('UNIQUE constraint')) return 'That name already exists.';
  return message;
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
