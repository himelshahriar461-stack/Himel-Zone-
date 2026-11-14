import 'dart:async';
import 'dart:math';

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
    // Preview mode remains available until Firebase is configured.
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
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
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
        result = await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: pass.text,
        );
        await result.user!.updateDisplayName(name.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'points': 0,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: pass.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'লগইন করা যায়নি');
    } catch (_) {
      setState(() => error = 'সমস্যা হয়েছে। Firebase সেটআপ পরীক্ষা করুন।');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Brand(),
            const SizedBox(height: 28),
            Text(
              register ? 'নতুন অ্যাকাউন্ট খুলুন' : 'স্বাগতম',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            if (register) ...[
              TextField(controller: name, decoration: const InputDecoration(labelText: 'আপনার নাম')),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'মোবাইল নম্বর'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'ইমেইল'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)'),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error, style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.all(15),
              ),
              onPressed: busy ? null : submit,
              child: Text(busy ? 'অপেক্ষা করুন...' : register ? 'রেজিস্ট্রেশন' : 'লগইন'),
            ),
            TextButton(
              onPressed: () => setState(() { register = !register; error = ''; }),
              child: Text(register ? 'আগে অ্যাকাউন্ট আছে? লগইন' : 'নতুন অ্যাকাউন্ট তৈরি করুন'),
            ),
            const Text(
              'নোট: অ্যাকাউন্ট চালু করতে Firebase কনফিগারেশন লাগবে।',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
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
    if (preview) {
      setState(() => demoPoints += amount);
      return;
    }
    final currentUser = user;
    if (currentUser == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['points'] as num?)?.toInt() ?? 0;
      if (snap.exists) {
        tx.update(ref, {'points': current + amount});
      } else {
        tx.set(ref, {'points': amount, 'role': 'user'});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(
        preview: preview,
        user: user,
        demoPoints: demoPoints,
        onPlay: () => setState(() => tab = 1),
      ),
      GamesPage(onAward: awardPoints),
      ProfilePage(preview: preview, user: user, demoPoints: demoPoints),
      const AdminInfoPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Himel Zone',
          style: TextStyle(color: gold, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (preview)
            const Padding(padding: EdgeInsets.all(12), child: Chip(label: Text('PREVIEW')))
          else
            IconButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
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
    Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(22)),
      alignment: Alignment.center,
      child: const Text(
        '77',
        style: TextStyle(color: Colors.black, fontSize: 34, fontWeight: FontWeight.w900),
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Himel Zone',
      style: TextStyle(color: gold, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3),
    ),
    const Text(
      'PLAY • LEARN • COLLECT POINTS',
      style: TextStyle(color: Colors.white60, fontSize: 10),
    ),
  ]);
}

class Dashboard extends StatelessWidget {
  final bool preview;
  final User? user;
  final int demoPoints;
  final VoidCallback onPlay;
  const Dashboard({
    super.key,
    required this.preview,
    required this.user,
    required this.demoPoints,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    Widget content(int points, String name) => ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Brand(),
        const SizedBox(height: 24),
        Text('স্বাগতম, $name!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Card(
          color: panel,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('আপনার পয়েন্ট', style: TextStyle(color: Colors.white60)),
                Text(
                  '$points ⭐',
                  style: const TextStyle(color: gold, fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'পয়েন্টের কোনো নগদ মূল্য নেই।',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          color: panel,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'আজকের চ্যালেঞ্জ',
                  style: TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('কুইজ ও মজার গেম খেলে দক্ষতা বাড়ান।'),
                const SizedBox(height: 12),
                FilledButton(onPressed: onPlay, child: const Text('গেম খেলুন')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Himel Zone একটি দক্ষতাভিত্তিক বিনোদন অ্যাপ। এখানে বাজি, জুয়া বা টাকা দিয়ে খেলার ব্যবস্থা নেই.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );

    if (preview) return content(demoPoints, 'Player');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (_, snap) => content(
        (snap.data?.data()?['points'] as num?)?.toInt() ?? 0,
        user!.displayName ?? 'Player',
      ),
    );
  }
}

class GamesPage extends StatelessWidget {
  final Future<void> Function(int) onAward;
  const GamesPage({super.key, required this.onAward});

  void openGame(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'গেম জোন',
        style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text('পছন্দের গেম বেছে নাও এবং পয়েন্ট জেতো।', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 16),
      GameTile(
        icon: Icons.quiz,
        title: 'জ্ঞান যাচাই কুইজ',
        subtitle: 'সাধারণ জ্ঞানের প্রশ্নের উত্তর দাও',
        reward: 'সঠিক উত্তরে ১০ পয়েন্ট',
        onTap: () => openGame(context, QuizPage(onAward: onAward)),
      ),
      GameTile(
        icon: Icons.directions_run,
        title: 'Snake Game',
        subtitle: 'সাপ চালিয়ে খাবার সংগ্রহ করো',
        reward: 'গেম শেষ হলে স্কোর অনুযায়ী পয়েন্ট',
        onTap: () => openGame(context, SnakeGamePage(onAward: onAward)),
      ),
      GameTile(
        icon: Icons.grid_3x3,
        title: 'Tic Tac Toe',
        subtitle: 'দুইজন মিলে X ও O খেলো',
        reward: 'জিতলে ১০ পয়েন্ট',
        onTap: () => openGame(context, TicTacToePage(onAward: onAward)),
      ),
      GameTile(
        icon: Icons.memory,
        title: 'Memory Match',
        subtitle: 'একই রকম ছবি মিলিয়ে ফেলো',
        reward: 'সব জোড়া মিললে ২০ পয়েন্ট',
        onTap: () => openGame(context, MemoryGamePage(onAward: onAward)),
      ),
    ],
  );
}

class GameTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String reward;
  final VoidCallback onTap;
  const GameTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: panel,
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: gold.withOpacity(0.16),
        child: Icon(icon, color: gold, size: 28),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 4),
            Text(reward, style: const TextStyle(color: gold, fontSize: 12)),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: gold),
      onTap: onTap,
    ),
  );
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
  int index = 0;
  bool answered = false;
  String message = '';

  Future<void> answer(int i) async {
    if (answered) return;
    final correct = i == questions[index].$3;
    setState(() {
      answered = true;
      message = correct ? 'সঠিক! ১০ পয়েন্ট যোগ হয়েছে 🎉' : 'ভুল উত্তর। পরের প্রশ্নে চেষ্টা করুন।';
    });
    if (correct) await widget.onAward(10);
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    return Scaffold(
      appBar: AppBar(title: const Text('জ্ঞান যাচাই কুইজ')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'প্রশ্ন ${index + 1} / ${questions.length}',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 18),
          Card(
            color: panel,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(q.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < q.$2.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                onPressed: answered ? null : () => answer(i),
                child: Padding(padding: const EdgeInsets.all(12), child: Text(q.$2[i])),
              ),
            ),
          if (message.isNotEmpty) ...[
            Text(message, style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() {
                index = (index + 1) % questions.length;
                answered = false;
                message = '';
              }),
              child: const Text('পরের প্রশ্ন'),
            ),
          ],
        ],
      ),
    );
  }
}

class SnakeGamePage extends StatefulWidget {
  final Future<void> Function(int) onAward;
  const SnakeGamePage({super.key, required this.onAward});
  @override
  State<SnakeGamePage> createState() => _SnakeGamePageState();
}

class _SnakeGamePageState extends State<SnakeGamePage> {
  static const int columns = 15;
  static const int rows = 20;
  final random = Random();
  late List<Point<int>> snake;
  late Point<int> food;
  Timer? timer;
  Point<int> direction = const Point(1, 0);
  bool running = false;
  bool gameOver = false;
  bool rewarded = false;
  int score = 0;

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  void resetGame() {
    timer?.cancel();
    snake = [const Point(7, 10), const Point(6, 10), const Point(5, 10)];
    direction = const Point(1, 0);
    score = 0;
    running = false;
    gameOver = false;
    rewarded = false;
    placeFood();
    if (mounted) setState(() {});
  }

  void placeFood() {
    do {
      food = Point(random.nextInt(columns), random.nextInt(rows));
    } while (snake.contains(food));
  }

  void startGame() {
    if (gameOver) resetGame();
    if (running) return;
    setState(() => running = true);
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) => moveSnake());
  }

  void changeDirection(Point<int> next) {
    if (next.x == -direction.x && next.y == -direction.y) return;
    setState(() => direction = next);
  }

  Future<void> finishGame() async {
    timer?.cancel();
    setState(() {
      running = false;
      gameOver = true;
    });
    if (!rewarded && score > 0) {
      rewarded = true;
      await widget.onAward(score);
    }
  }

  void moveSnake() {
    if (!mounted || !running) return;
    final head = Point(snake.first.x + direction.x, snake.first.y + direction.y);
    final eating = head == food;
    final bodyToCheck = eating ? snake : snake.take(snake.length - 1);
    if (head.x < 0 || head.x >= columns || head.y < 0 || head.y >= rows || bodyToCheck.contains(head)) {
      finishGame();
      return;
    }
    setState(() {
      snake.insert(0, head);
      if (eating) {
        score += 5;
        placeFood();
      } else {
        snake.removeLast();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Snake Game')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('স্কোর: $score', textAlign: TextAlign.center,
            style: const TextStyle(color: gold, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: columns / rows,
            child: Container(
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(4),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: columns * rows,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                ),
                itemBuilder: (_, index) {
                  final point = Point(index % columns, index ~/ columns);
                  final isHead = point == snake.first;
                  final isBody = snake.contains(point);
                  final isFood = point == food;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: isHead ? Colors.lightGreenAccent : isBody ? Colors.green : isFood ? Colors.redAccent : const Color(0xFF303238),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (gameOver)
            const Text('গেম শেষ! আবার খেলতে Play চাপো।', textAlign: TextAlign.center,
              style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
          if (!running)
            FilledButton(onPressed: startGame, child: Text(gameOver ? 'আবার খেলুন' : 'Play')),
          const SizedBox(height: 8),
          _DirectionPad(onDirection: changeDirection),
          const SizedBox(height: 8),
          const Text('খাবার সংগ্রহ করো, দেয়াল ও নিজের শরীরে ধাক্কা দিও না।',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _DirectionPad extends StatelessWidget {
  final ValueChanged<Point<int>> onDirection;
  const _DirectionPad({required this.onDirection});

  Widget control(IconData icon, Point<int> direction) => IconButton.filledTonal(
    onPressed: () => onDirection(direction),
    icon: Icon(icon, color: gold),
    iconSize: 30,
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      control(Icons.keyboard_arrow_up, const Point(0, -1)),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          control(Icons.keyboard_arrow_left, const Point(-1, 0)),
          const SizedBox(width: 55),
          control(Icons.keyboard_arrow_right, const Point(1, 0)),
        ],
      ),
      control(Icons.keyboard_arrow_down, const Point(0, 1)),
    ],
  );
}

class TicTacToePage extends StatefulWidget {
  final Future<void> Function(int) onAward;
  const TicTacToePage({super.key, required this.onAward});
  @override
  State<TicTacToePage> createState() => _TicTacToePageState();
}

class _TicTacToePageState extends State<TicTacToePage> {
  List<int> cells = List.filled(9, 0);
  int turn = 1;
  int? winner;
  bool draw = false;
  bool rewarded = false;

  void play(int index) {
    if (cells[index] != 0 || winner != null || draw) return;
    setState(() {
      cells[index] = turn;
      winner = _findWinner();
      if (winner == null && !cells.contains(0)) draw = true;
      if (winner == null) turn = turn == 1 ? 2 : 1;
    });
    if (winner != null && !rewarded) {
      rewarded = true;
      widget.onAward(10);
    }
  }

  int? _findWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final value = cells[line[0]];
      if (value != 0 && value == cells[line[1]] && value == cells[line[2]]) return value;
    }
    return null;
  }

  void reset() => setState(() {
    cells = List.filled(9, 0);
    turn = 1;
    winner = null;
    draw = false;
    rewarded = false;
  });

  @override
  Widget build(BuildContext context) {
    final status = winner != null
        ? 'Player ${winner == 1 ? 'X' : 'O'} জিতেছে! ১০ পয়েন্ট যোগ হয়েছে।'
        : draw ? 'খেলা ড্র হয়েছে।' : 'এখন Player ${turn == 1 ? 'X' : 'O'}-এর পালা';
    return Scaffold(
      appBar: AppBar(title: const Text('Tic Tac Toe')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(status, textAlign: TextAlign.center,
                style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 22),
              SizedBox(
                width: 330,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: 9,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => play(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text(
                        cells[i] == 1 ? 'X' : cells[i] == 2 ? 'O' : '',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: cells[i] == 1 ? gold : Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(onPressed: reset, child: const Text('নতুন খেলা')),
              const SizedBox(height: 8),
              const Text('এটি একই ফোনে দুইজনের খেলা।', style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryGamePage extends StatefulWidget {
  final Future<void> Function(int) onAward;
  const MemoryGamePage({super.key, required this.onAward});
  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  final List<String> symbols = ['🍎', '🚀', '🐱', '⚽', '🌟', '🎈', '🍀', '🎵'];
  late List<String> cards;
  final Set<int> openCards = {};
  final Set<int> matchedCards = {};
  bool checking = false;
  bool rewarded = false;
  int moves = 0;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    cards = [...symbols, ...symbols]..shuffle(Random());
    openCards.clear();
    matchedCards.clear();
    checking = false;
    rewarded = false;
    moves = 0;
  }

  Future<void> flip(int index) async {
    if (checking || matchedCards.contains(index) || openCards.contains(index)) return;
    setState(() {
      openCards.add(index);
      if (openCards.length == 2) {
        checking = true;
        moves++;
      }
    });
    if (openCards.length == 2) {
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      final pair = openCards.toList();
      setState(() {
        if (cards[pair[0]] == cards[pair[1]]) {
          matchedCards.addAll(pair);
        }
        openCards.clear();
        checking = false;
      });
      if (matchedCards.length == cards.length && !rewarded) {
        rewarded = true;
        await widget.onAward(20);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('অভিনন্দন! ২০ পয়েন্ট যোগ হয়েছে 🎉')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = matchedCards.length == cards.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Match')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('চাল: $moves', textAlign: TextAlign.center,
            style: const TextStyle(color: gold, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('একই রকম দুটি কার্ড খুঁজে বের করো।', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
            ),
            itemBuilder: (_, i) {
              final visible = openCards.contains(i) || matchedCards.contains(i);
              return InkWell(
                onTap: () => flip(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: matchedCards.contains(i) ? Colors.green.shade800 : panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gold.withOpacity(0.35)),
                  ),
                  alignment: Alignment.center,
                  child: Text(visible ? cards[i] : '?',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          if (complete)
            const Text('সব জোড়া মিলে গেছে! ২০ পয়েন্ট পেয়েছো।',
              textAlign: TextAlign.center, style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
          FilledButton(onPressed: () => setState(_newGame), child: const Text('আবার খেলুন')),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final bool preview;
  final User? user;
  final int demoPoints;
  const ProfilePage({
    super.key,
    required this.preview,
    required this.user,
    required this.demoPoints,
  });

  @override
  Widget build(BuildContext context) {
    Widget card(int points, String name, String email) => Card(
      color: panel,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_circle, size: 64, color: gold),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(email, style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 18),
            Text('মোট পয়েন্ট: $points ⭐', style: const TextStyle(color: gold, fontSize: 18)),
          ],
        ),
      ),
    );

    if (preview) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('আমার প্রোফাইল', style: TextStyle(fontSize: 24, color: gold)),
          card(demoPoints, 'Player', 'Preview mode'),
        ],
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (_, snap) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('আমার প্রোফাইল', style: TextStyle(fontSize: 24, color: gold)),
          card(
            (snap.data?.data()?['points'] as num?)?.toInt() ?? 0,
            user!.displayName ?? 'Player',
            user!.email ?? '',
          ),
        ],
      ),
    );
  }
}

class AdminInfoPage extends StatelessWidget {
  const AdminInfoPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'অ্যাডমিন প্যানেল',
        style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Card(
        color: panel,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('নিরাপদ অ্যাডমিন ব্যবস্থাপনা',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'এই স্টার্টার সংস্করণে অ্যাডমিন স্ক্রিনটি তথ্যভিত্তিক। বাস্তব অ্যাডমিন অ্যাক্সেস চালু করতে Firebase Authentication-এর UID-কে সার্ভার-নিয়ন্ত্রিত admin role দিতে হবে।',
              ),
              SizedBox(height: 8),
              Text(
                'সাধারণ ব্যবহারকারী নিজে role পরিবর্তন করতে পারবে না।',
                style: TextStyle(color: gold),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
