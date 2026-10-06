import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------- i18n ----------
const _tr = {
  'dash': ['Dashboard', 'ড্যাশবোর্ড'], 'tx': ['Transaction', 'লেনদেন'], 'bud': ['Budget', 'বাজেট'],
  'goals': ['Goals', 'লক্ষ্য'], 'rep': ['Reports', 'রিপোর্ট'], 'set': ['Settings', 'সেটিংস'],
  'bal': ['Total Balance', 'মোট ব্যালেন্স'], 'inc': ['Income', 'আয়'], 'exp': ['Expense', 'ব্যয়'],
  'sav': ['Savings', 'সঞ্চয়'], 'recent': ['Recent transactions', 'সাম্প্রতিক লেনদেন'],
  'add': ['Add', 'যোগ করুন'], 'save': ['Save', 'সংরক্ষণ'], 'cancel': ['Cancel', 'বাতিল'],
  'amt': ['Amount', 'পরিমাণ'], 'cat': ['Categories', 'ক্যাটাগরি'], 'note': ['Note', 'নোট'],
  'method': ['Payment method', 'পেমেন্ট মাধ্যম'], 'search': ['Search', 'খুঁজুন'], 'all': ['All', 'সব'],
  'total': ['Monthly budget', 'মাসিক বাজেট'], 'name': ['Name', 'নাম'], 'target': ['Target amount', 'লক্ষ্য পরিমাণ'],
  'contrib': ['Add to goal', 'লক্ষ্যে জমা'], 'cur': ['Currency', 'মুদ্রা'], 'lang': ['Language', 'ভাষা'],
  'dark': ['Dark mode', 'ডার্ক মোড'], 'backup': ['Backup (copy to clipboard)', 'ব্যাকআপ (ক্লিপবোর্ডে কপি)'],
  'restore': ['Restore (paste backup)', 'রিস্টোর (ব্যাকআপ পেস্ট)'], 'csv': ['Copy CSV', 'CSV কপি করুন'],
  'nodata': ['Nothing here yet', 'এখনো কিছু নেই'], 'newcat': ['New category name', 'নতুন ক্যাটাগরির নাম'],
  'copied': ['Copied', 'কপি হয়েছে'], 'over': ['Budget exceeded', 'বাজেট ছাড়িয়েছে'],
  'warn': ['80% used', '৮০% খরচ হয়েছে'], 'bad': ['Invalid data', 'ডাটা ঠিক নেই'],
};
String t(String k) => _tr[k]![S.bn ? 1 : 0];

// ---------- models ----------
const kIcons = [Icons.restaurant, Icons.directions_bus, Icons.home, Icons.payments, Icons.shopping_bag, Icons.favorite, Icons.school, Icons.receipt_long, Icons.category];
const kColors = [0xFFFF9800, 0xFF2196F3, 0xFF9C27B0, 0xFF4CAF50, 0xFFE91E63, 0xFFF44336, 0xFF3F51B5, 0xFF009688, 0xFF607D8B];

class Tx {
  String id, type, cat, note, method; double amt; DateTime date;
  Tx(this.id, this.type, this.amt, this.cat, this.date, this.note, this.method);
  Map j() => {'id': id, 'type': type, 'amt': amt, 'cat': cat, 'date': date.toIso8601String(), 'note': note, 'method': method};
  factory Tx.f(Map m) => Tx(m['id'], m['type'], (m['amt'] as num).toDouble(), m['cat'], DateTime.parse(m['date']), m['note'] ?? '', m['method'] ?? 'Cash');
}
class Goal {
  String id, name; double target, saved;
  Goal(this.id, this.name, this.target, this.saved);
  Map j() => {'id': id, 'name': name, 'target': target, 'saved': saved};
  factory Goal.f(Map m) => Goal(m['id'], m['name'], (m['target'] as num).toDouble(), (m['saved'] as num).toDouble());
}
class Cat {
  String name, bn; int color, icon;
  Cat(this.name, this.bn, this.color, this.icon);
  String get label => S.bn ? bn : name;
  Map j() => {'name': name, 'bn': bn, 'color': color, 'icon': icon};
  factory Cat.f(Map m) => Cat(m['name'], m['bn'], m['color'], m['icon']);
}

List<Cat> _defCats() {
  const n = ['Food', 'Transport', 'Rent', 'Salary', 'Shopping', 'Health', 'Education', 'Bills', 'Others'];
  const b = ['খাবার', 'যাতায়াত', 'ভাড়া', 'বেতন', 'কেনাকাটা', 'স্বাস্থ্য', 'শিক্ষা', 'বিল', 'অন্যান্য'];
  return [for (var i = 0; i < 9; i++) Cat(n[i], b[i], kColors[i], i)];
}

// ---------- store ----------
class Store extends ChangeNotifier {
  List<Tx> txs = []; List<Goal> goals = []; List<Cat> cats = _defCats();
  Map<String, double> budgets = {}; String cur = 'BDT', lang = 'bn'; bool dark = false;
  SharedPreferences? p;
  bool get bn => lang == 'bn';
  String get sym => {'BDT': '৳', 'USD': '\$', 'INR': '₹', 'EUR': '€'}[cur]!;
  Future<void> load() async {
    p = await SharedPreferences.getInstance();
    final s = p!.getString('mm');
    if (s != null) { try { fromJ(jsonDecode(s)); } catch (_) {} }
  }
  void fromJ(Map m) {
    txs = [for (final e in m['txs'] ?? []) Tx.f(e)];
    goals = [for (final e in m['goals'] ?? []) Goal.f(e)];
    if (m['cats'] != null) cats = [for (final e in m['cats']) Cat.f(e)];
    budgets = Map<String, double>.from((m['budgets'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())));
    cur = m['cur'] ?? 'BDT'; lang = m['lang'] ?? 'bn'; dark = m['dark'] ?? false;
  }
  String dump() => jsonEncode({'txs': txs.map((e) => e.j()).toList(), 'goals': goals.map((e) => e.j()).toList(),
    'cats': cats.map((e) => e.j()).toList(), 'budgets': budgets, 'cur': cur, 'lang': lang, 'dark': dark});
  void commit() { p?.setString('mm', dump()); notifyListeners(); }
}
final S = Store();

// ---------- helpers ----------
String money(double v) => '${S.sym}${NumberFormat('#,##0.##').format(v)}';
bool sameM(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
double sum(Iterable<Tx> l, String ty) => l.where((x) => x.type == ty).fold(0.0, (s, x) => s + x.amt);
Map<String, double> byCat(Iterable<Tx> l) {
  final r = <String, double>{};
  for (final x in l.where((x) => x.type == 'expense')) { r[x.cat] = (r[x.cat] ?? 0) + x.amt; }
  return r;
}
Cat catOf(String n) => S.cats.firstWhere((c) => c.name == n, orElse: () => S.cats.last);
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
void msg(BuildContext c, String s) => ScaffoldMessenger.of(c).showSnackBar(
  SnackBar(content: Text(s), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

Widget stat(String l, double v, Color col, IconData icon) => Expanded(
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [col.withOpacity(0.15), col.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: col.withOpacity(0.2)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: col.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: col)),
          const SizedBox(width: 6),
          Expanded(child: Text(l, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        FittedBox(child: Text(money(v), style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 16))),
      ]),
    ),
  ),
);

Widget txTile(BuildContext c, Tx x) {
  final k = catOf(x.cat);
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(c).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(k.color), Color(k.color).withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Color(k.color).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Icon(kIcons[k.icon % 9], color: Colors.white, size: 22),
      ),
      title: Text(k.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text('${DateFormat.yMMMd().format(x.date)}${x.note.isEmpty ? '' : ' · ${x.note}'}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (x.type == 'income' ? Colors.green : Colors.red).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('${x.type == 'income' ? '+' : '-'}${money(x.amt)}',
          style: TextStyle(color: x.type == 'income' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      onTap: () => txDialog(c, x),
    ),
  );
}

// ---------- dialogs ----------
Future<double?> numDlg(BuildContext c, String title, [double? v]) {
  final a = TextEditingController(text: v == null ? '' : '$v');
  return showDialog<double>(context: c, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    content: TextField(controller: a, autofocus: true, keyboardType: TextInputType.number,
      decoration: InputDecoration(hintText: '0', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel'))),
      FilledButton(onPressed: () => Navigator.pop(c, double.tryParse(a.text)), child: Text(t('save')))]));
}

Future txDialog(BuildContext c, [Tx? e]) {
  var type = e?.type ?? 'expense', cat = e?.cat ?? 'Food', date = e?.date ?? DateTime.now(), method = e?.method ?? 'Cash';
  final a = TextEditingController(text: e == null ? '' : '${e.amt}'), n = TextEditingController(text: e?.note ?? '');
  return showDialog(context: c, builder: (_) => StatefulBuilder(builder: (c, ss) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Text(t('tx'), style: const TextStyle(fontWeight: FontWeight.bold)),
    content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SegmentedButton<String>(
        segments: [ButtonSegment(value: 'expense', label: Text(t('exp')), icon: const Icon(Icons.arrow_upward, size: 16)),
          ButtonSegment(value: 'income', label: Text(t('inc')), icon: const Icon(Icons.arrow_downward, size: 16))],
        selected: {type}, onSelectionChanged: (s) => ss(() => type = s.first)),
      const SizedBox(height: 16),
      TextField(controller: a, autofocus: true, keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: t('amt'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: cat, decoration: InputDecoration(labelText: t('cat'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        items: [for (final k in S.cats) DropdownMenuItem(value: k.name, child: Row(children: [
          Container(width: 20, height: 20, decoration: BoxDecoration(color: Color(k.color), borderRadius: BorderRadius.circular(6)),
            child: Icon(kIcons[k.icon % 9], size: 12, color: Colors.white)),
          const SizedBox(width: 8), Text(k.label)]))], onChanged: (v) => ss(() => cat = v!)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: method, decoration: InputDecoration(labelText: t('method'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        items: ['Cash', 'bKash', 'Nagad', 'Card', 'Bank'].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => ss(() => method = v!)),
      const SizedBox(height: 12),
      TextField(controller: n, decoration: InputDecoration(labelText: t('note'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
      const SizedBox(height: 8),
      TextButton.icon(icon: const Icon(Icons.event, size: 18), label: Text(DateFormat.yMMMd().format(date)), onPressed: () async {
        final d = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) ss(() => date = d);
      }),
    ]))),
    actions: [
      if (e != null) TextButton(onPressed: () { S.txs.remove(e); S.commit(); Navigator.pop(c); },
        child: const Icon(Icons.delete, color: Colors.red)),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel'))),
      FilledButton(onPressed: () {
        final v = double.tryParse(a.text);
        if (v == null || v <= 0) return;
        if (e == null) { S.txs.add(Tx(uid(), type, v, cat, date, n.text, method)); }
        else { e.type = type; e.amt = v; e.cat = cat; e.date = date; e.note = n.text; e.method = method; }
        S.commit(); Navigator.pop(c);
      }, child: Text(t('save'))),
    ])));
}

void goalDlg(BuildContext c) {
  final n = TextEditingController(), a = TextEditingController();
  showDialog(context: c, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Text(t('goals'), style: const TextStyle(fontWeight: FontWeight.bold)),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: n, autofocus: true, decoration: InputDecoration(labelText: t('name'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
      const SizedBox(height: 12),
      TextField(controller: a, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('target'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel'))),
      FilledButton(onPressed: () {
        final v = double.tryParse(a.text);
        if (v == null || v <= 0 || n.text.trim().isEmpty) return;
        S.goals.add(Goal(uid(), n.text.trim(), v, 0)); S.commit(); Navigator.pop(c);
      }, child: Text(t('save')))]));
}

// ---------- app ----------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.load();
  runApp(App());
}

ThemeData _th(Brightness b) {
  final isDark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF10B981),
      secondary: const Color(0xFFF59E0B),
      brightness: b,
    ),
    scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark ? const Color(0xFF1E1E30) : Colors.white,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E1E30) : Colors.white,
      indicatorColor: const Color(0xFF10B981).withOpacity(0.15),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isDark ? const Color(0xFF1E1E30) : Colors.white,
      indicatorColor: const Color(0xFF10B981).withOpacity(0.15),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A40) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0xFF10B981),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(color: isDark ? Colors.white12 : Colors.black12),
  );
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext c) => ListenableBuilder(listenable: S, builder: (c, _) => MaterialApp(
    title: 'MoneyMate', debugShowCheckedModeBanner: false, theme: _th(Brightness.light), darkTheme: _th(Brightness.dark),
    themeMode: S.dark ? ThemeMode.dark : ThemeMode.light, home: Home()));
}

class Home extends StatefulWidget { @override State<Home> createState() => _HS(); }
class _HS extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext c) {
    const keys = ['dash', 'tx', 'bud', 'goals', 'rep', 'set'];
    const ic = [Icons.dashboard_rounded, Icons.swap_horiz_rounded, Icons.pie_chart_rounded, Icons.savings_rounded, Icons.bar_chart_rounded, Icons.settings_rounded];
    final pages = <Widget Function()>[() => Dash(), () => Txs(), () => BudgetPg(), () => GoalsPg(), () => Reports(), () => SettingsPg()];
    final wide = MediaQuery.of(c).size.width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MoneyMate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(t(keys[i]), style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.normal)),
          ]),
        ]),
      ),
      floatingActionButton: i <= 1 ? FloatingActionButton.extended(
        onPressed: () => txDialog(c), icon: const Icon(Icons.add), label: Text(t('add')),
        elevation: 4,
      ) : null,
      bottomNavigationBar: wide ? null : Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: NavigationBar(
          selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v),
          destinations: [for (var k = 0; k < 6; k++) NavigationDestination(icon: Icon(ic[k]), label: t(keys[k]))],
        ),
      ),
      body: Row(children: [
        if (wide) Container(
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(5, 0))],
          ),
          child: NavigationRail(
            selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              ),
            ),
            destinations: [for (var k = 0; k < 6; k++) NavigationRailDestination(icon: Icon(ic[k]), label: Text(t(keys[k])))],
          ),
        ),
        Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: pages[i]()))),
      ]));
  }
}

// ---------- dashboard ----------
class Dash extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    final m = S.txs.where((x) => sameM(x.date, DateTime.now())).toList();
    final inc = sum(m, 'income'), ex = sum(m, 'expense'), bal = sum(S.txs, 'income') - sum(S.txs, 'expense');
    final by = byCat(m);
    final rec = ([...S.txs]..sort((a, b) => b.date.compareTo(a.date))).take(10).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(t('bal'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          FittedBox(child: Text(money(bal), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        stat(t('inc'), inc, const Color(0xFF10B981), Icons.trending_up),
        stat(t('exp'), ex, const Color(0xFFEF4444), Icons.trending_down),
        stat(t('sav'), inc - ex, const Color(0xFFF59E0B), Icons.savings),
      ]),
      const SizedBox(height: 24),
      if (by.isNotEmpty) ...[
        Text(t('cat'), style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(c).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 40,
            sections: [
              for (final e in by.entries) PieChartSectionData(
                value: e.value,
                title: '${(e.value / ex * 100).toStringAsFixed(0)}%',
                color: Color(catOf(e.key).color),
                radius: 60,
                titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          )),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          for (final e in by.entries) Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(catOf(e.key).color), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(catOf(e.key).label, style: const TextStyle(fontSize: 12)),
          ]),
        ]),
      ],
      const SizedBox(height: 24),
      Row(children: [
        Text(t('recent'), style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${rec.length}', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      if (rec.isEmpty) Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(t('nodata'), style: TextStyle(color: Colors.grey[500])),
        ]),
      ),
      for (final x in rec) txTile(c, x),
    ]);
  }
}

// ---------- transactions ----------
class Txs extends StatefulWidget { @override State<Txs> createState() => _TS(); }
class _TS extends State<Txs> {
  String q = '', ty = 'all', ct = 'all';
  @override
  Widget build(BuildContext c) {
    final ql = q.toLowerCase();
    final l = S.txs.where((x) => (ty == 'all' || x.type == ty) && (ct == 'all' || x.cat == ct) &&
      (ql.isEmpty || x.note.toLowerCase().contains(ql) || catOf(x.cat).label.toLowerCase().contains(ql))).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        TextField(onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: t('search'), isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final k in ['all', 'income', 'expense']) Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(k == 'all' ? t('all') : t(k == 'income' ? 'inc' : 'exp')),
              selected: ty == k, onSelected: (_) => setState(() => ty = k),
              selectedColor: (k == 'income' ? Colors.green : k == 'expense' ? Colors.red : const Color(0xFF10B981)).withOpacity(0.15),
              checkmarkColor: k == 'income' ? Colors.green : k == 'expense' ? Colors.red : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(value: ct, onChanged: (v) => setState(() => ct = v!), underline: const SizedBox(),
            items: [DropdownMenuItem(value: 'all', child: Text(t('all'))), for (final k in S.cats) DropdownMenuItem(value: k.name, child: Text(k.label))]),
        ])),
      ])),
      Expanded(child: l.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(t('nodata'), style: TextStyle(color: Colors.grey[500])),
      ])) : ListView(children: [for (final x in l) txTile(c, x)])),
    ]);
  }
}

// ---------- budget ----------
class BudgetPg extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    final m = S.txs.where((x) => sameM(x.date, DateTime.now()) && x.type == 'expense').toList();
    final by = byCat(m);
    Widget row(String title, String k, double spent, IconData icon, Color color) {
      final lim = S.budgets[k] ?? 0;
      final r = lim > 0 ? spent / lim : 0.0;
      final statusColor = r >= 1 ? Colors.red : r >= .8 ? Colors.orange : Colors.green;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(c).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: statusColor.withOpacity(0.15), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () async {
              final v = await numDlg(c, title, lim > 0 ? lim : null);
              if (v != null) { S.budgets[k] = v; S.commit(); }
            }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: r.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: statusColor.withOpacity(0.1),
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text(money(spent), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: statusColor)),
            Text(' / ${lim > 0 ? money(lim) : '—'}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const Spacer(),
            if (r >= 1) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(t('over'), style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
            ) else if (r >= .8) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(t('warn'), style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      row(t('total'), '_total', sum(m, 'expense'), Icons.account_balance_wallet, const Color(0xFF10B981)),
      const SizedBox(height: 8),
      Text(t('cat'), style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      for (final k in S.cats) row(k.label, k.name, by[k.name] ?? 0, kIcons[k.icon % 9], Color(k.color)),
    ]);
  }
}

// ---------- goals ----------
class GoalsPg extends StatelessWidget {
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(heroTag: 'g', onPressed: () => goalDlg(c), icon: const Icon(Icons.add), label: Text(t('add'))),
    body: S.goals.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.savings_rounded, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(t('nodata'), style: TextStyle(color: Colors.grey[500], fontSize: 16)),
      const SizedBox(height: 8),
      Text('Tap + to add a goal', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    ])) : ListView(padding: const EdgeInsets.all(16), children: [
      for (final g in S.goals) Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(c).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF10B981).withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.flag_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 28), onPressed: () async {
              final v = await numDlg(c, t('contrib'));
              if (v != null) { g.saved += v; S.commit(); }
            }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            IconButton(icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 22), onPressed: () { S.goals.remove(g); S.commit(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (g.saved / g.target).clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text(money(g.saved), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981))),
            Text(' / ${money(g.target)}', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('${(g.saved / g.target * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
        ]),
      ),
    ]));
}

// ---------- reports ----------
class Reports extends StatefulWidget { @override State<Reports> createState() => _RS(); }
class _RS extends State<Reports> {
  DateTime m = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext c) {
    final l = S.txs.where((x) => sameM(x.date, m)).toList();
    final inc = sum(l, 'income'), ex = sum(l, 'expense'), by = byCat(l);
    final yr = S.txs.where((x) => x.date.year == m.year);
    double mo(int i, String ty) => sum(yr.where((x) => x.date.month == i + 1), ty);
    const hide = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(c).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => m = DateTime(m.year, m.month - 1))),
          Text(DateFormat.yMMMM().format(m), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => setState(() => m = DateTime(m.year, m.month + 1))),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        stat(t('inc'), inc, const Color(0xFF10B981), Icons.trending_up),
        stat(t('exp'), ex, const Color(0xFFEF4444), Icons.trending_down),
        stat(t('sav'), inc - ex, const Color(0xFFF59E0B), Icons.savings),
      ]),
      const SizedBox(height: 24),
      if (by.isNotEmpty) ...[
        Text(t('cat'), style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final e in (by.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(c).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(catOf(e.key).color), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(catOf(e.key).label, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(money(e.value), style: TextStyle(fontWeight: FontWeight.bold, color: Color(catOf(e.key).color))),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ex > 0 ? e.value / ex : 0.0,
                    minHeight: 6,
                    backgroundColor: Color(catOf(e.key).color).withOpacity(0.1),
                    color: Color(catOf(e.key).color),
                  ),
                ),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 16),
      Text('${m.year}: ${t('inc')} vs ${t('exp')}', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(c).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: BarChart(BarChartData(
          titlesData: FlTitlesData(leftTitles: hide, topTitles: hide, rightTitles: hide,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt() + 1}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]))))),
          gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
          barGroups: [for (var i = 0; i < 12; i++) BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: mo(i, 'income'), color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: mo(i, 'expense'), color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])],
        )),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        icon: const Icon(Icons.copy, size: 18),
        label: Text(t('csv')),
        onPressed: () {
          final rows = ['date,type,category,amount,method,note', for (final x in l)
            '${DateFormat('yyyy-MM-dd').format(x.date)},${x.type},${x.cat},${x.amt},${x.method},"${x.note.replaceAll('"', '""')}"'];
          Clipboard.setData(ClipboardData(text: rows.join('\n'))); msg(c, t('copied'));
        },
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
      ),
    ]);
  }
}

// ---------- settings ----------
class SettingsPg extends StatelessWidget {
  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
    Container(
      decoration: BoxDecoration(
        color: Theme.of(c).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.currency_exchange, color: Color(0xFF10B981), size: 20)),
          title: Text(t('cur')), trailing: DropdownButton<String>(value: S.cur, onChanged: (v) { S.cur = v!; S.commit(); }, underline: const SizedBox(),
            items: ['BDT', 'USD', 'INR', 'EUR'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList())),
        Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.language, color: Color(0xFFF59E0B), size: 20)),
          title: Text(t('lang')), trailing: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'bn', label: Text('বাংলা')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {S.lang}, onSelectionChanged: (s) { S.lang = s.first; S.commit(); },
            style: ButtonStyle(visualDensity: VisualDensity.compact))),
        Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
        SwitchListTile(
          secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(S.dark ? Icons.dark_mode : Icons.light_mode, color: Colors.purple, size: 20)),
          title: Text(t('dark')), value: S.dark, onChanged: (v) { S.dark = v; S.commit(); }),
      ]),
    ),
    const SizedBox(height: 16),
    Container(
      decoration: BoxDecoration(
        color: Theme.of(c).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.category_rounded, color: Color(0xFF10B981), size: 20)),
          title: Text(t('cat')),
          trailing: IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF10B981)), onPressed: () {
            final n = TextEditingController();
            showDialog(context: c, builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(t('newcat'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: TextField(controller: n, autofocus: true, decoration: InputDecoration(hintText: 'e.g. Travel', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel'))),
                FilledButton(onPressed: () {
                  final s = n.text.trim();
                  if (s.isEmpty || S.cats.any((k) => k.name == s)) return;
                  S.cats.insert(S.cats.length - 1, Cat(s, s, kColors[S.cats.length % 9], S.cats.length % 9));
                  S.commit(); Navigator.pop(c);
                }, child: Text(t('save')))]));
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in S.cats) Chip(
              avatar: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: Color(k.color), borderRadius: BorderRadius.circular(8)),
                child: Icon(kIcons[k.icon % 9], size: 14, color: Colors.white),
              ),
              label: Text(k.label, style: const TextStyle(fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ]),
        ),
      ]),
    ),
    const SizedBox(height: 16),
    Container(
      decoration: BoxDecoration(
        color: Theme.of(c).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.copy_rounded, color: Colors.blue, size: 20)),
          title: Text(t('backup')), trailing: const Icon(Icons.chevron_right),
          onTap: () { Clipboard.setData(ClipboardData(text: S.dump())); msg(c, t('copied')); }),
        Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.paste_rounded, color: Colors.orange, size: 20)),
          title: Text(t('restore')), trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final n = TextEditingController();
            showDialog(context: c, builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(t('restore'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: TextField(controller: n, maxLines: 6, decoration: InputDecoration(hintText: 'Paste backup JSON here...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel'))),
                FilledButton(onPressed: () {
                  try { S.fromJ(jsonDecode(n.text)); S.commit(); Navigator.pop(c); } catch (_) { msg(c, t('bad')); }
                }, child: Text(t('save')))]));
          }),
      ]),
    ),
    const SizedBox(height: 32),
    Center(child: Column(children: [
      Icon(Icons.account_balance_wallet, size: 40, color: Colors.grey[300]),
      const SizedBox(height: 8),
      Text('MoneyMate v2.0', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    ])),
    const SizedBox(height: 16),
  ]);
}