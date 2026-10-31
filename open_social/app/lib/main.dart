import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/game_model.dart';
import 'services/github_content_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final contentService = GitHubContentService(prefs: prefs);
  runApp(OpenSocialApp(contentService: contentService));
}

class OpenSocialApp extends StatelessWidget {
  final GitHubContentService contentService;

  const OpenSocialApp({super.key, required this.contentService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFFFF7675),
          surface: Color(0xFF1E2130),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E2130),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(contentService: contentService),
    );
  }
}

// ==========================================
// PANTALLA PRINCIPAL: HOME & CATÁLOGO
// ==========================================
class HomeScreen extends StatefulWidget {
  final GitHubContentService contentService;

  const HomeScreen({super.key, required this.contentService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ContentManifest? manifest;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent({bool refresh = false}) async {
    setState(() => isLoading = true);
    final data = await widget.contentService.getManifest(forceRefresh: refresh);
    setState(() {
      manifest = data;
      isLoading = false;
    });
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'people':
        return Icons.people_alt_rounded;
      case 'local_bar':
        return Icons.local_bar_rounded;
      case 'flash_on':
        return Icons.bolt_rounded;
      case 'theater_comedy':
        return Icons.theater_comedy_rounded;
      case 'cancel':
        return Icons.highlight_off_rounded;
      case 'face':
        return Icons.face_rounded;
      default:
        return Icons.sports_esports_rounded;
    }
  }

  List<Color> _gameGradients(int index) {
    final gradients = [
      [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)], // Morado
      [const Color(0xFFFF7675), const Color(0xFFFAB1A0)], // Coral / Rosa
      [const Color(0xFFFD79A8), const Color(0xFFE84393)], // Fucsia
      [const Color(0xFF00CEC9), const Color(0xFF81ECEC)], // Turquesa
      [const Color(0xFFFDCB6E), const Color(0xFFFFEAA7)], // Ámbar
      [const Color(0xFF0984E3), const Color(0xFF74B9FF)], // Azul eléctrico
    ];
    return gradients[index % gradients.length];
  }

  void _openGame(GameDefinition game) {
    Widget targetScreen;
    switch (game.id) {
      case 'most_likely_to':
        targetScreen = MostLikelyScreen(game: game, service: widget.contentService);
        break;
      case 'never_have_i_ever':
        targetScreen = NeverHaveIEverScreen(game: game, service: widget.contentService);
        break;
      case 'truth_or_dare':
        targetScreen = TruthOrDareScreen(game: game, service: widget.contentService);
        break;
      case 'fake_it':
        targetScreen = FakeItScreen(game: game, service: widget.contentService);
        break;
      case 'wrong_answers_only':
        targetScreen = WrongAnswersScreen(game: game, service: widget.contentService);
        break;
      case 'charades':
        targetScreen = CharadesScreen(game: game, service: widget.contentService);
        break;
      default:
        targetScreen = GenericGameScreen(game: game);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFFF7675)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Open Social',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar packs desde GitHub',
            icon: const Icon(Icons.sync_rounded, color: Colors.white70),
            onPressed: () => _loadContent(refresh: true),
          ),
          IconButton(
            tooltip: 'Acerca del proyecto',
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : manifest == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudieron cargar los juegos.'),
                      ElevatedButton(
                        onPressed: () => _loadContent(refresh: true),
                        child: const Text('Reintentar'),
                      )
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6C5CE7).withOpacity(0.25),
                            const Color(0xFF1E2130),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.code_rounded, color: Color(0xFFA29BFE), size: 32),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Modo Pass & Play 100% Abierto",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Pasa el móvil, juega en grupo y añade nuevas preguntas directamente en GitHub.",
                                  style: TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Juegos disponibles",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...manifest!.games.asMap().entries.map((entry) {
                      final index = entry.key;
                      final game = entry.value;
                      final gradient = _gameGradients(index);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _openGame(game),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2130),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: gradient[0].withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                              border: Border.all(
                                color: gradient[0].withOpacity(0.3),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: gradient),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    _resolveIcon(game.icon),
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        game.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        game.description,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${game.packs.length} ${game.packs.length == 1 ? "pack" : "packs"}',
                                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Pass & Play',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF00CEC9)),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.white30),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2130),
        title: const Text('Open Social'),
        content: const Text(
          'Open Social es una iniciativa de código abierto para fiestas y reuniones.\n\n'
          'Los packs de preguntas y reglas se alojan en GitHub y cualquier miembro de la comunidad puede añadir contenido abriendo una Pull Request.\n\n'
          'Totalmente gratuito, sin anuncios y 100% offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }
}

// ==========================================
// JUEGO 1: ¿QUIÉN ES MÁS PROBABLE?
// ==========================================
class MostLikelyScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;

  const MostLikelyScreen({super.key, required this.game, required this.service});

  @override
  State<MostLikelyScreen> createState() => _MostLikelyScreenState();
}

class _MostLikelyScreenState extends State<MostLikelyScreen> {
  List<String> questions = [];
  int currentIndex = 0;
  bool isCountingDown = false;
  int countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null && data['items'] != null) {
      final list = List<String>.from(data['items']);
      list.shuffle();
      setState(() => questions = list);
    }
  }

  void _triggerCountdown() {
    if (isCountingDown) return;
    setState(() {
      isCountingDown = true;
      countdown = 3;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        setState(() => countdown--);
      } else {
        timer.cancel();
        setState(() {
          countdown = 0; // "¡SEÑALEN YA!"
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => isCountingDown = false);
          }
        });
      }
    });
  }

  void _nextQuestion() {
    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        isCountingDown = false;
      });
    } else {
      questions.shuffle();
      setState(() {
        currentIndex = 0;
        isCountingDown = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = questions.isNotEmpty
        ? questions[currentIndex]
        : "¿Quién es más probable que termine detenido por un malentendido absurdo?";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.name),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: questions.isNotEmpty ? (currentIndex + 1) / questions.length : 1.0,
              color: const Color(0xFF6C5CE7),
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D3436), Color(0xFF1E2130)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 54, color: Color(0xFFA29BFE)),
                      const SizedBox(height: 24),
                      Text(
                        currentQ,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                      const SizedBox(height: 32),
                      if (isCountingDown)
                        AnimatedScale(
                          scale: 1.2,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            countdown > 0 ? '$countdown' : '👉 ¡SEÑALEN YA! 👈',
                            style: TextStyle(
                              fontSize: countdown > 0 ? 48 : 28,
                              fontWeight: FontWeight.w900,
                              color: countdown > 0 ? const Color(0xFFFDCB6E) : const Color(0xFFFF7675),
                            ),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _triggerCountdown,
                          icon: const Icon(Icons.timer, color: Colors.white),
                          label: const Text('Cuenta atrás (3s)', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _nextQuestion,
                child: const Text('Siguiente pregunta', style: TextStyle(fontSize: 17, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// JUEGO 2: YO NUNCA
// ==========================================
class NeverHaveIEverScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;

  const NeverHaveIEverScreen({super.key, required this.game, required this.service});

  @override
  State<NeverHaveIEverScreen> createState() => _NeverHaveIEverScreenState();
}

class _NeverHaveIEverScreenState extends State<NeverHaveIEverScreen> {
  List<String> statements = [];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPack();
  }

  Future<void> _loadPack() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null && data['items'] != null) {
      final list = List<String>.from(data['items']);
      list.shuffle();
      setState(() => statements = list);
    }
  }

  void _next() {
    if (currentIndex < statements.length - 1) {
      setState(() => currentIndex++);
    } else {
      statements.shuffle();
      setState(() => currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrase = statements.isNotEmpty
        ? statements[currentIndex]
        : "Yo nunca he fingido hablar por teléfono para evitar a alguien.";

    return Scaffold(
      appBar: AppBar(title: const Text('Yo Nunca'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C1924), Color(0xFF1E2130)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFF7675).withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_bar_rounded, size: 56, color: Color(0xFFFF7675)),
                      const SizedBox(height: 24),
                      Text(
                        phrase,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "¡Si lo has hecho alguna vez, bebes o pierdes 1 vida!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7675),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _next,
                child: const Text('Siguiente tarjeta', style: TextStyle(fontSize: 17, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// JUEGO 3: VERDAD O RETO
// ==========================================
class TruthOrDareScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;

  const TruthOrDareScreen({super.key, required this.game, required this.service});

  @override
  State<TruthOrDareScreen> createState() => _TruthOrDareScreenState();
}

class _TruthOrDareScreenState extends State<TruthOrDareScreen> {
  List<String> truths = [];
  List<String> dares = [];
  String? currentText;
  bool isTruth = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null) {
      setState(() {
        truths = List<String>.from(data['truths'] ?? []);
        dares = List<String>.from(data['dares'] ?? []);
      });
    }
  }

  void _choose(bool truth) {
    final list = truth ? truths : dares;
    if (list.isNotEmpty) {
      final item = list[Random().nextInt(list.length)];
      setState(() {
        isTruth = truth;
        currentText = item;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verdad o Reto'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2130),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: currentText == null
                          ? Colors.white24
                          : isTruth
                              ? const Color(0xFF00CEC9)
                              : const Color(0xFFFD79A8),
                      width: 1.5,
                    ),
                  ),
                  child: currentText == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.bolt_rounded, size: 60, color: Color(0xFFFD79A8)),
                            SizedBox(height: 16),
                            Text(
                              'Elige tu destino',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '¿Te atreves a confesar la verdad o prefieres cumplir un reto?',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isTruth ? 'VERDAD' : 'RETO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isTruth ? const Color(0xFF00CEC9) : const Color(0xFFFD79A8),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              currentText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00CEC9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _choose(true),
                      child: const Text('Verdad 😇', style: TextStyle(fontSize: 17, color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFD79A8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _choose(false),
                      child: const Text('Reto 😈', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// JUEGO 4: FAKE IT (FÍNGELO - IMPOSTOR)
// ==========================================
class FakeItScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;

  const FakeItScreen({super.key, required this.game, required this.service});

  @override
  State<FakeItScreen> createState() => _FakeItScreenState();
}

class _FakeItScreenState extends State<FakeItScreen> {
  int playerCount = 4;
  int currentPass = 0;
  int impostorIndex = 0;
  bool showSecret = false;
  bool isReadyForAction = false;
  int countdown = 3;
  Timer? _actionTimer;
  List<Map<String, dynamic>> prompts = [];
  Map<String, dynamic>? currentPrompt;

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null && data['prompts'] != null) {
      prompts = List<Map<String, dynamic>>.from(data['prompts']);
      _startNewRound();
    }
  }

  void _startNewRound() {
    if (prompts.isEmpty) return;
    setState(() {
      currentPrompt = prompts[Random().nextInt(prompts.length)];
      impostorIndex = Random().nextInt(playerCount);
      currentPass = 0;
      showSecret = false;
      isReadyForAction = false;
    });
  }

  void _startCountdown() {
    setState(() {
      isReadyForAction = true;
      countdown = 3;
    });

    _actionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        setState(() => countdown--);
      } else {
        timer.cancel();
        setState(() => countdown = 0);
      }
    });
  }

  @override
  void dispose() {
    _actionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentPrompt == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Pantalla de ejecución simultánea de la acción
    if (isReadyForAction) {
      return Scaffold(
        appBar: AppBar(title: const Text('¡ACCIÓN!'), backgroundColor: Colors.transparent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  countdown > 0 ? '$countdown' : '💥 ¡ACTÚEN TODOS YA! 💥',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: countdown > 0 ? 70 : 32,
                    fontWeight: FontWeight.w900,
                    color: countdown > 0 ? const Color(0xFFFDCB6E) : const Color(0xFFFF7675),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Observen atentamente las reacciones: ¿quién dudó o copió al resto?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  onPressed: _startNewRound,
                  child: const Text('Nueva ronda'),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Pantalla de pasar el teléfono
    final isImpostor = currentPass == impostorIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake It (Fíngelo)'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Jugador ${currentPass + 1} de $playerCount',
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (currentPass + 1) / playerCount,
              color: const Color(0xFF00CEC9),
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTapDown: (_) => setState(() => showSecret = true),
                  onTapUp: (_) => setState(() => showSecret = false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: showSecret
                            ? (isImpostor
                                ? [const Color(0xFFE84393), const Color(0xFF2C1924)]
                                : [const Color(0xFF00CEC9), const Color(0xFF1E2130)])
                            : [const Color(0xFF2D3436), const Color(0xFF1E2130)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          showSecret ? Icons.visibility_rounded : Icons.fingerprint_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 20),
                        if (!showSecret) ...[
                          const Text(
                            'Mantén pulsado para ver tu instrucción secreta',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text('Asegúrate de que nadie más mire la pantalla.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ] else ...[
                          if (isImpostor) ...[
                            const Text(
                              '🕵️ ¡ERES EL IMPOSTOR! 🕵️',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No tienes ninguna instrucción.\nCuando termine la cuenta atrás, finge y copia rápidamente lo que hagan los demás.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ] else ...[
                            Text(
                              'Categoría: ${currentPrompt!['category']}',
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              currentPrompt!['instruction'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ]
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CEC9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  if (currentPass < playerCount - 1) {
                    setState(() {
                      currentPass++;
                      showSecret = false;
                    });
                  } else {
                    _startCountdown();
                  }
                },
                child: Text(
                  currentPass < playerCount - 1 ? 'Pasar al siguiente jugador' : '¡Iniciar cuenta atrás!',
                  style: const TextStyle(fontSize: 17, color: Colors.black87, fontWeight: FontWeight.bold),
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
// JUEGO 5: SOLO RESPUESTAS INCORRECTAS
// ==========================================
class WrongAnswersScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;

  const WrongAnswersScreen({super.key, required this.game, required this.service});

  @override
  State<WrongAnswersScreen> createState() => _WrongAnswersScreenState();
}

class _WrongAnswersScreenState extends State<WrongAnswersScreen> {
  List<Map<String, dynamic>> questions = [];
  int currentIndex = 0;
  int timerSeconds = 30;
  int score = 0;
  bool isPlaying = false;
  Timer? _gameTimer;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null && data['questions'] != null) {
      final list = List<Map<String, dynamic>>.from(data['questions']);
      list.shuffle();
      setState(() => questions = list);
    }
  }

  void _startGame() {
    questions.shuffle();
    setState(() {
      isPlaying = true;
      timerSeconds = 30;
      score = 0;
      currentIndex = 0;
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timerSeconds > 1) {
        setState(() => timerSeconds--);
      } else {
        timer.cancel();
        setState(() => isPlaying = false);
      }
    });
  }

  void _answer(bool success) {
    if (!isPlaying) return;
    setState(() {
      if (success) score++;
      if (currentIndex < questions.length - 1) {
        currentIndex++;
      } else {
        currentIndex = 0;
      }
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = questions.isNotEmpty ? questions[currentIndex] : {"q": "¿De qué color es el cielo?", "trap": "Azul"};

    return Scaffold(
      appBar: AppBar(title: const Text('Solo Respuestas Incorrectas'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isPlaying
            ? Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tiempo: ${timerSeconds}s', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFDCB6E))),
                      Text('Puntos: $score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2130),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFDCB6E).withOpacity(0.5)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('¡PROHIBIDO DECIR LA VERDAD!', style: TextStyle(color: Color(0xFFFF7675), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            Text(
                              q['q'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                              child: Text('Trampa obvia: ${q['trap']}', style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () => _answer(false),
                            child: const Text('Dijo la verdad ❌', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CEC9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () => _answer(true),
                            child: const Text('¡Mentira válida! ✔️', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_rounded, size: 70, color: Color(0xFFFDCB6E)),
                    const SizedBox(height: 16),
                    Text(score > 0 ? '¡Fin de la ronda! Puntos: $score' : '¿Listo para mentir?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('El jugador debe contestar tantas preguntas como pueda en 30 segundos sin decir NUNCA la verdad.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDCB6E),
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _startGame,
                      child: const Text('Comenzar ronda (30s)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}

// ==========================================
// JUEGO 6: CHARADAS EN LA FRENTE
// ==========================================
class CharadesScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;

  const CharadesScreen({super.key, required this.game, required this.service});

  @override
  State<CharadesScreen> createState() => _CharadesScreenState();
}

class _CharadesScreenState extends State<CharadesScreen> {
  List<String> words = [];
  int currentIndex = 0;
  int score = 0;
  bool isPlaying = false;
  int timeLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null && data['words'] != null) {
      final list = List<String>.from(data['words']);
      list.shuffle();
      setState(() => words = list);
    }
  }

  void _startGame() {
    words.shuffle();
    setState(() {
      isPlaying = true;
      score = 0;
      timeLeft = 60;
      currentIndex = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 1) {
        setState(() => timeLeft--);
      } else {
        timer.cancel();
        setState(() => isPlaying = false);
      }
    });
  }

  void _action(bool correct) {
    if (!isPlaying) return;
    setState(() {
      if (correct) score++;
      if (currentIndex < words.length - 1) {
        currentIndex++;
      } else {
        currentIndex = 0;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = words.isNotEmpty ? words[currentIndex] : "Harry Potter";

    return Scaffold(
      appBar: AppBar(title: const Text('Charadas en la Frente'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isPlaying
            ? Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tiempo: ${timeLeft}s', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0984E3))),
                      Text('Aciertos: $score', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0984E3), Color(0xFF1E2130)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            word,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () => _action(false),
                            child: const Text('Paso ⏩', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CEC9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () => _action(true),
                            child: const Text('¡Acertó! 🎉', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.face_rounded, size: 70, color: Color(0xFF0984E3)),
                    const SizedBox(height: 16),
                    Text(score > 0 ? '¡Ronda terminada! Aciertos: $score' : '¡Ponte el móvil en la frente!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('Los demás deben darte pistas o hacer mímica sin decir la palabra prohibida.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0984E3),
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _startGame,
                      child: const Text('Iniciar ronda (60s)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}

class GenericGameScreen extends StatelessWidget {
  final GameDefinition game;
  const GenericGameScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: Center(child: Text('Pantalla para ${game.name}')),
    );
  }
}
