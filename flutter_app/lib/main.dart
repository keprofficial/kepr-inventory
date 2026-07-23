import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                : const HomeScreen(),
      );
}

class InventorySignInScreen extends StatefulWidget {
  const InventorySignInScreen({super.key});

  @override
  State<InventorySignInScreen> createState() => _InventorySignInScreenState();
}

class _InventorySignInScreenState extends State<InventorySignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  Future<void> signIn() async {
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: forest,
                          foregroundColor: Colors.white,
                          child: Text('K',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text('KEPR Inventory',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      const Text('Sign in with your KEPR staff account.',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 24),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
      TransfersPage(key: ValueKey('transfers-$revision'), onChanged: changed),
      ForecastPage(key: ValueKey('forecast-$revision')),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkForest,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              child: Text('K', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KEPR', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  'INVENTORY',
                  style: TextStyle(fontSize: 9, letterSpacing: 1.5),
                ),
              ],
            ),
          ],
        ),
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
            icon: Icon(Icons.swap_horiz),
            label: 'Transfers',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats),
            label: 'Forecast',
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
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
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data![0] as List<Product>;
          final apartments = snapshot.data![1] as List<Apartment>;
          final value = products.fold<double>(0, (sum, p) => sum + p.value);
          final low = products.where((p) => p.isLow).length;
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
            action: FilledButton.icon(
              onPressed: () => showProductForm(context, onChanged),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
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
  Widget build(BuildContext context) =>
      FutureBuilder<List<TransferSummary>>(
        future: InventoryDatabase.instance.transfers(),
        builder: (context, snapshot) {
          final transfers = snapshot.data ?? [];
          return PageShell(
            title: 'Stock transfers',
            subtitle: 'Every movement has a durable audit reference.',
            action: FilledButton.icon(
              onPressed: () => showTransferForm(context, onChanged),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('New'),
            ),
            child: SectionCard(
              title: 'Recent transfers',
              child: transfers.isEmpty
                  ? const EmptyState(
                      icon: Icons.swap_horiz,
                      title: 'No transfers',
                      message: 'Move warehouse stock to an apartment.',
                    )
                  : Column(
                      children: transfers
                          .map(
                            (t) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xffE2F1E9),
                                child: Icon(Icons.north_east, color: forest),
                              ),
                              title: Text(
                                t.apartment,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${t.reference}\n${t.date} · ${t.lineCount} items',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    inr(t.totalValue),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text('${number(t.totalQuantity)} units'),
                                ],
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
            color: warning
                ? const Color(0xffF7D3C6)
                : const Color(0xffE2E9E5),
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
          color: warning
              ? const Color(0xffFFE8DF)
              : const Color(0xffE2F1E9),
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
                value: unit,
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
                value: apartmentId,
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
                          value: line.productId,
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
                    final reference =
                        await InventoryDatabase.instance.transfer(
                      apartmentId: apartmentId,
                      date:
                          DateTime.now().toIso8601String().substring(0, 10),
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
String readableError(Object error) {
  final message = error.toString().replaceFirst('Bad state: ', '');
  if (message.contains('UNIQUE constraint')) return 'That name already exists.';
  return message;
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
