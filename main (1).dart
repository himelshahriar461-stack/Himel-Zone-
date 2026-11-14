import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const gold = Color(0xFFE4B75B);
const bg = Color(0xFF101114);
const panel = Color(0xFF202126);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    // The UI remains usable in preview mode until Firebase is configured.
  }
  runApp(KKApp(firebaseReady: firebaseReady));
}

class KKApp extends StatelessWidget {
  final bool firebaseReady;
  const KKApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Himel Zone',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    ),
    home: firebaseReady ? const AuthGate() : const PreviewHome(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snap.data == null ? const AuthPage() : const MainShell();
    },
  );
}

class PreviewHome extends StatelessWidget {
  const PreviewHome({super.key});
  @override
  Widget build(BuildContext context) => const MainShell(preview: true);
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool register = false, busy = false;
  String error = '';

  Future<void> submit() async {
    setState(() { busy = true; error = ''; });
    try {
      final auth = FirebaseAuth.instance;
      UserCredential result;
      if (register) {
        result = await auth.createUserWithEmailAndPassword(email: email.text.trim(), password: pass.text);
        await result.user!.updateDisplayName(name.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
          'name': name.text.trim(), 'phone': phone.text.trim(),
          'points': 0, 'role': 'user', 'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await auth.signInWithEmailAndPassword(email: email.text.trim(), password: pass.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'লগইন করা যায়নি');
    } catch (_) {
      setState(() => error = 'সমস্যা হয়েছে। Firebase সেটআপ পরীক্ষা করুন।');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Brand(),
        const SizedBox(height: 28),
        Text(register ? 'নতুন অ্যাকাউন্ট খুলুন' : 'স্বাগতম', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        if (register) ...[
          TextField(controller: name, decoration: const InputDecoration(labelText: 'আপনার নাম')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'মোবাইল নম্বর')),
          const SizedBox(height: 12),
        ],
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ইমেইল')),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)')),
        if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.all(15)),
          onPressed: busy ? null : submit,
          child: Text(busy ? 'অপেক্ষা করুন...' : register ? 'রেজিস্ট্রেশন' : 'লগইন'),
        ),
        TextButton(onPressed: () => setState(() { register = !register; error = ''; }),
          child: Text(register ? 'আগে অ্যাকাউন্ট আছে? লগইন' : 'নতুন অ্যাকাউন্ট তৈরি করুন')),
        const Text('নোট: অ্যাকাউন্ট চালু করতে Firebase কনফিগারেশন লাগবে।', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    ))),
  );
}

class MainShell extends StatefulWidget {
  final bool preview;
  const MainShell({super.key, this.preview = false});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  int demoPoints = 120;
  bool get preview => widget.preview;
  User? get user => preview ? null : FirebaseAuth.instance.currentUser;

  Future<void> awardPoints(int amount) async {
    if (preview) { setState(() => demoPoints += amount); return; }
    final ref = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['points'] as num?)?.toInt() ?? 0;
      tx.update(ref, {'points': current + amount});
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(preview: preview, user: user, demoPoints: demoPoints, onPlay: () => setState(() => tab = 1)),
      QuizPage(onAward: awardPoints),
      ProfilePage(preview: preview, user: user, demoPoints: demoPoints),
      AdminInfoPage(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Himel Zone', style: TextStyle(color: gold, fontWeight: FontWeight.w900)), actions: [
        if (preview) const Padding(padding: EdgeInsets.all(12), child: Chip(label: Text('PREVIEW')))
        else IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
      ]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'হোম'),
          NavigationDestination(icon: Icon(Icons.sports_esports), label: 'গেম'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'প্রোফাইল'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: 'অ্যাডমিন'),
        ],
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 76, height: 76, decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(22)),
      alignment: Alignment.center, child: const Text('77', style: TextStyle(color: Colors.black, fontSize: 34, fontWeight: FontWeight.w900))),
    const SizedBox(height: 8),
    const Text('Himel Zone', style: TextStyle(color: gold, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3)),
    const Text('PLAY • LEARN • COLLECT POINTS', style: TextStyle(color: Colors.white60, fontSize: 10)),
  ]);
}

class Dashboard extends StatelessWidget {
  final bool preview; final User? user; final int demoPoints; final VoidCallback onPlay;
  const Dashboard({super.key, required this.preview, required this.user, required this.demoPoints, required this.onPlay});
  @override
  Widget build(BuildContext context) {
    Widget content(int points, String name) => ListView(padding: const EdgeInsets.all(18), children: [
      const Brand(), const SizedBox(height: 24),
      Text('স্বাগতম, $name!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Card(color: panel, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('আপনার পয়েন্ট', style: TextStyle(color: Colors.white60)),
        Text('$points ⭐', style: const TextStyle(color: gold, fontSize: 34, fontWeight: FontWeight.bold)),
        const Text('পয়েন্টের কোনো নগদ মূল্য নেই।', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]))),
      const SizedBox(height: 18),
      Card(color: panel, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('আজকের চ্যালেঞ্জ', style: TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Text('৩টি সাধারণ জ্ঞান প্রশ্নের উত্তর দিন এবং দক্ষতা বাড়ান।'),
        const SizedBox(height: 12), FilledButton(onPressed: onPlay, child: const Text('কুইজ খেলুন')),
      ]))),
      const SizedBox(height: 12),
      const Text('Himel Zone একটি দক্ষতাভিত্তিক বিনোদন অ্যাপ। এখানে বাজি, জুয়া বা টাকা দিয়ে খেলার ব্যবস্থা নেই.', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
    if (preview) return content(demoPoints, 'Player');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (_, snap) => content((snap.data?.data()?['points'] as num?)?.toInt() ?? 0, user!.displayName ?? 'Player'),
    );
  }
}

class QuizPage extends StatefulWidget {
  final Future<void> Function(int) onAward;
  const QuizPage({super.key, required this.onAward});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final questions = const [
    ('বাংলাদেশের রাজধানী কোনটি?', ['ঢাকা', 'চট্টগ্রাম', 'খুলনা'], 0),
    ('এক সপ্তাহে কয় দিন?', ['৫ দিন', '৭ দিন', '১০ দিন'], 1),
    ('সূর্য কোন দিক থেকে ওঠে?', ['পশ্চিম', 'উত্তর', 'পূর্ব'], 2),
  ];
  int index = 0; bool answered = false; String message = '';
  Future<void> answer(int i) async {
    if (answered) return;
    setState(() { answered = true; message = i == questions[index].$3 ? 'সঠিক! ১০ পয়েন্ট যোগ হয়েছে 🎉' : 'ভুল উত্তর। পরের প্রশ্নে চেষ্টা করুন।'; });
    if (i == questions[index].$3) await widget.onAward(10);
  }
  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('জ্ঞান যাচাই কুইজ', style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10), Text('প্রশ্ন ${index + 1} / ${questions.length}', style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 18), Card(color: panel, child: Padding(padding: const EdgeInsets.all(20), child: Text(q.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 14),
      for (int i = 0; i < q.$2.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton(onPressed: answered ? null : () => answer(i), child: Padding(padding: const EdgeInsets.all(12), child: Text(q.$2[i])))),
      if (message.isNotEmpty) ...[
        Text(message, style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => setState(() { index = (index + 1) % questions.length; answered = false; message = ''; }), child: const Text('পরের প্রশ্ন')),
      ]
    ]);
  }
}

class ProfilePage extends StatelessWidget {
  final bool preview; final User? user; final int demoPoints;
  const ProfilePage({super.key, required this.preview, required this.user, required this.demoPoints});
  @override
  Widget build(BuildContext context) {
    Widget card(int points, String name, String email) => Card(color: panel, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.account_circle, size: 64, color: gold), const SizedBox(height: 10),
      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text(email, style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 18), Text('মোট পয়েন্ট: $points ⭐', style: const TextStyle(color: gold, fontSize: 18)),
    ])));
    if (preview) return ListView(padding: const EdgeInsets.all(18), children: [const Text('আমার প্রোফাইল', style: TextStyle(fontSize: 24, color: gold)), card(demoPoints, 'Player', 'Preview mode')]);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (_, snap) => ListView(padding: const EdgeInsets.all(18), children: [
        const Text('আমার প্রোফাইল', style: TextStyle(fontSize: 24, color: gold)),
        card((snap.data?.data()?['points'] as num?)?.toInt() ?? 0, user!.displayName ?? 'Player', user!.email ?? ''),
      ]),
    );
  }
}

class AdminInfoPage extends StatelessWidget {
  const AdminInfoPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('অ্যাডমিন প্যানেল', style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    const Card(color: panel, child: Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('নিরাপদ অ্যাডমিন ব্যবস্থাপনা', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('এই স্টার্টার সংস্করণে অ্যাডমিন স্ক্রিনটি তথ্যভিত্তিক। বাস্তব অ্যাডমিন অ্যাক্সেস চালু করতে Firebase Authentication-এর UID-কে সার্ভার-নিয়ন্ত্রিত admin role দিতে হবে।'),
      SizedBox(height: 8),
      Text('সাধারণ ব্যবহারকারী নিজে role পরিবর্তন করতে পারবে না।', style: TextStyle(color: gold)),
    ]))),
  ]);
}
