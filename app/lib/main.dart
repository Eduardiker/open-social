import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/game_model.dart';
import 'services/github_content_service.dart';
import 'screens/multiplayer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final contentService = GitHubContentService(prefs: prefs);
  runApp(OpenSocialApp(contentService: contentService, prefs: prefs));
}

class OpenSocialApp extends StatelessWidget {
  final GitHubContentService contentService;
  final SharedPreferences prefs;

  const OpenSocialApp({super.key, required this.contentService, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JALEO',
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
      home: HomeScreen(contentService: contentService, prefs: prefs),
    );
  }
}

// ==========================================
// PANTALLA PRINCIPAL: HOME, JUGADORES Y MALDICIONES
// ==========================================
class HomeScreen extends StatefulWidget {
  final GitHubContentService contentService;
  final SharedPreferences prefs;

  const HomeScreen({super.key, required this.contentService, required this.prefs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ContentManifest? manifest;
  bool isLoading = true;
  List<String> players = [];
  String currentIntensity = "fiesta";

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _loadContent();
  }

  void _loadPlayers() {
    final saved = widget.prefs.getStringList('saved_players');
    if (saved != null && saved.isNotEmpty) {
      players = saved;
    } else {
      players = ["Iker", "Laura", "Marcos", "Sofía"];
    }
    setState(() {});
  }

  Future<void> _savePlayers() async {
    await widget.prefs.setStringList('saved_players', players);
  }

  Future<void> _loadContent({bool refresh = false}) async {
    setState(() => isLoading = true);
    final data = await widget.contentService.getManifest(forceRefresh: refresh);
    setState(() {
      manifest = data;
      isLoading = false;
    });
  }

  void _openPlayersDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2130),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("👥 Jugadores de la fiesta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              const Text("Añade a tus amigos. La app personalizará los duelos, maldiciones y turnos.", style: TextStyle(fontSize: 13, color: Colors.white60)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: "Nombre del jugador...",
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setModalState(() => players.add(val.trim()));
                          setState(() {});
                          _savePlayers();
                          controller.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        setModalState(() => players.add(controller.text.trim()));
                        setState(() {});
                        _savePlayers();
                        controller.clear();
                      }
                    },
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.map((p) => Chip(
                  backgroundColor: const Color(0xFF2D3436),
                  label: Text(p, style: const TextStyle(fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white60),
                  onDeleted: players.length > 2
                      ? () {
                          setModalState(() => players.remove(p));
                          setState(() {});
                          _savePlayers();
                        }
                      : null,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openCustomQuestions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomQuestionsScreen(prefs: widget.prefs)),
    );
  }

  void _openMultiplayerHost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MultiplayerHostScreen(onPenalty: _openPenaltiesWheel)),
    );
  }

  void _openPenaltiesWheel([String? loserName]) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2130),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => PenaltiesWheelSheet(service: widget.contentService, loserName: loserName),
    );
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'auto_awesome': return Icons.auto_awesome_rounded;
      case 'timer': return Icons.alarm_on_rounded;
      case 'people': return Icons.people_alt_rounded;
      case 'local_bar': return Icons.local_bar_rounded;
      case 'balance': return Icons.swap_horiz_rounded;
      case 'flash_on': return Icons.bolt_rounded;
      case 'theater_comedy': return Icons.theater_comedy_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'cancel': return Icons.highlight_off_rounded;
      case 'face': return Icons.face_rounded;
      default: return Icons.sports_esports_rounded;
    }
  }

  List<Color> _gameGradients(int index) {
    final gradients = [
      [const Color(0xFF6C5CE7), const Color(0xFF00CEC9)], // Maldiciones y Virus
      [const Color(0xFFFF7675), const Color(0xFFD63031)], // Rojo Bomba
      [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)], // Morado
      [const Color(0xFFFD79A8), const Color(0xFFFAB1A0)], // Coral
      [const Color(0xFF00CEC9), const Color(0xFF0984E3)], // Azul
      [const Color(0xFFE84393), const Color(0xFF6C5CE7)], // Magenta
      [const Color(0xFF00B894), const Color(0xFF55EFC4)], // Verde menta
      [const Color(0xFFFF7675), const Color(0xFFFD79A8)], // Rosa
      [const Color(0xFFFDCB6E), const Color(0xFFFFEAA7)], // Ámbar
      [const Color(0xFF0984E3), const Color(0xFF74B9FF)], // Azul
    ];
    return gradients[index % gradients.length];
  }

  void _openGame(GameDefinition game) {
    Widget targetScreen;
    switch (game.id) {
      case 'picolo_mode':
        targetScreen = PicoloModeScreen(game: game, service: widget.contentService, players: players, onPenalty: _openPenaltiesWheel);
        break;
      case 'hot_bomb':
        targetScreen = HotBombScreen(game: game, service: widget.contentService, players: players, prefs: widget.prefs, onPenalty: _openPenaltiesWheel);
        break;
      case 'most_likely_to':
        targetScreen = MostLikelyScreen(game: game, service: widget.contentService, players: players, intensity: currentIntensity, prefs: widget.prefs);
        break;
      case 'never_have_i_ever':
        targetScreen = NeverHaveIEverScreen(game: game, service: widget.contentService, players: players, intensity: currentIntensity, prefs: widget.prefs);
        break;
      case 'would_you_rather':
        targetScreen = WouldYouRatherScreen(game: game, service: widget.contentService);
        break;
      case 'truth_or_dare':
        targetScreen = TruthOrDareScreen(game: game, service: widget.contentService, players: players, intensity: currentIntensity, prefs: widget.prefs);
        break;
      case 'fake_it':
        targetScreen = FakeItScreen(game: game, service: widget.contentService, players: players);
        break;
      case 'couples':
        targetScreen = CouplesScreen(game: game, service: widget.contentService, players: players);
        break;
      case 'wrong_answers_only':
        targetScreen = WrongAnswersScreen(game: game, service: widget.contentService, players: players);
        break;
      case 'charades':
        targetScreen = CharadesScreen(game: game, service: widget.contentService, players: players);
        break;
      default:
        targetScreen = const Scaffold(body: Center(child: Text("Juego")));
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
                gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFFF7675)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Row(
              children: const [
                Text('JALEO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5, color: Colors.white)),
                SizedBox(width: 6),
                Text('PARTY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Color(0xFF00CEC9))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sala Multijugador (Web & QR)',
            icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00CEC9), size: 28),
            onPressed: _openMultiplayerHost,
          ),
          IconButton(
            tooltip: 'Mis Preguntas Privadas (100% Local)',
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF00CEC9), size: 28),
            onPressed: _openCustomQuestions,
          ),
          IconButton(
            tooltip: 'Ruleta de Castigos',
            icon: const Icon(Icons.casino_rounded, color: Color(0xFFFDCB6E)),
            onPressed: () => _openPenaltiesWheel(),
          ),
          IconButton(
            tooltip: 'Sincronizar packs desde GitHub',
            icon: const Icon(Icons.sync_rounded, color: Colors.white70),
            onPressed: () => _loadContent(refresh: true),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Fila: Jugadores + Botón Mis Preguntas Privadas
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _openPlayersDialog,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2130),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.group_rounded, color: Color(0xFFA29BFE), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Jugadores: ${players.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(players.join(", "), style: const TextStyle(fontSize: 11, color: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _openCustomQuestions,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00CEC9).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.lock_rounded, color: Color(0xFF00CEC9), size: 18),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text("Mis Preguntas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00CEC9)), maxLines: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Selector de Intensidad / Picante
                Row(
                  children: [
                    _intensityChip("🟢 Colegas", "tranqui", const Color(0xFF00B894)),
                    const SizedBox(width: 8),
                    _intensityChip("🟡 Fiesta", "fiesta", const Color(0xFFFDCB6E)),
                    const SizedBox(width: 8),
                    _intensityChip("🔴 Picante +18", "picante", const Color(0xFFFF7675)),
                  ],
                ),
                const SizedBox(height: 20),

                // Banner Multijugador estilo Jackbox
                InkWell(
                  onTap: _openMultiplayerHost,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6C5CE7).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("SALA MULTIJUGADOR (LOCAL & P2P)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 0.5)),
                              SizedBox(height: 2),
                              Text("Tus amigos juegan escaneando un QR sin instalar nada", style: TextStyle(fontSize: 11, color: Colors.white70)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Top Juegos de Fiesta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () => _openPenaltiesWheel(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFDCB6E).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text("🎰 Ruleta Prendas", style: TextStyle(color: Color(0xFFFDCB6E), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (manifest != null)
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
                            border: Border.all(color: gradient[0].withOpacity(0.3), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: gradient),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(_resolveIcon(game.icon), size: 28, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(game.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (game.id == 'picolo_mode') ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFF00CEC9).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                            child: const Text("TOP", style: TextStyle(color: Color(0xFF00CEC9), fontSize: 10, fontWeight: FontWeight.w900)),
                                          )
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(game.description, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white30),
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

  Widget _intensityChip(String label, String value, Color color) {
    final isSelected = currentIntensity == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentIntensity = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.25) : const Color(0xFF1E2130),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? color : Colors.white12, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// JUEGO: MALDICIONES Y DUELOS (VIRUS, DUELOS Y REGLAS)
// ==========================================
class PicoloModeScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;
  final Function(String?) onPenalty;

  const PicoloModeScreen({super.key, required this.game, required this.service, required this.players, required this.onPenalty});

  @override
  State<PicoloModeScreen> createState() => _PicoloModeScreenState();
}

class _PicoloModeScreenState extends State<PicoloModeScreen> {
  List<Map<String, dynamic>> allCards = [];
  Map<String, dynamic>? currentCard;
  int currentRound = 1;
  List<Map<String, dynamic>> activeViruses = [];
  String? cureAlert;
  String selectedPackId = 'all'; // 'all' o un id específico de pack
  bool drinkingMode = true; // true: tragos 🍻, false: retos ⚡

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    List<Map<String, dynamic>> loaded = [];
    if (selectedPackId == 'all') {
      for (var pack in widget.game.packs) {
        final data = await widget.service.loadPackContent(pack.file);
        if (data != null && data['cards'] != null) {
          loaded.addAll(List<Map<String, dynamic>>.from(data['cards']));
        }
      }
    } else {
      final pack = widget.game.packs.firstWhere(
        (p) => p.id == selectedPackId,
        orElse: () => widget.game.packs.first,
      );
      final data = await widget.service.loadPackContent(pack.file);
      if (data != null && data['cards'] != null) {
        loaded.addAll(List<Map<String, dynamic>>.from(data['cards']));
      }
    }

    setState(() {
      allCards = loaded;
    });

    if (allCards.isNotEmpty) {
      _nextCard();
    }
  }

  void _nextCard() {
    if (allCards.isEmpty) return;

    // Actualizar duración de virus activos
    cureAlert = null;
    List<Map<String, dynamic>> remainingViruses = [];
    for (var v in activeViruses) {
      v['turnsLeft'] = (v['turnsLeft'] as int) - 1;
      if (v['turnsLeft'] <= 0) {
        cureAlert = "🎉 ¡${v['player']} ya está curado del virus: '${v['name']}'!";
      } else {
        remainingViruses.add(v);
      }
    }
    activeViruses = remainingViruses;

    // Seleccionar tarjeta aleatoria
    final raw = allCards[Random().nextInt(allCards.length)];

    // Asignar jugadores aleatorios de la partida
    final rand = Random();
    final p1 = widget.players.isNotEmpty ? widget.players[rand.nextInt(widget.players.length)] : "Jugador 1";
    String p2 = "Jugador 2";
    if (widget.players.length > 1) {
      final others = widget.players.where((p) => p != p1).toList();
      p2 = others[rand.nextInt(others.length)];
    }

    final turns = raw['duration'] ?? 3;
    String formattedText = (raw['text'] as String)
        .replaceAll("{p1}", p1)
        .replaceAll("{p2}", p2)
        .replaceAll("{turns}", turns.toString());

    // Si está en modo sobrio/retos, adaptar términos si el usuario lo prefiere
    if (!drinkingMode) {
      formattedText = formattedText
          .replaceAll("tragos", "puntos de castigo")
          .replaceAll("trago", "penalización")
          .replaceAll("chupito", "reto")
          .replaceAll("bebe", "paga prenda");
    }

    // Si es un virus nuevo, registrarlo
    if (raw['type'] == 'virus') {
      activeViruses.add({
        'player': p1,
        'name': raw['title'] ?? 'Maldición',
        'desc': formattedText,
        'turnsLeft': turns,
      });
    }

    setState(() {
      currentCard = {
        'type': raw['type'],
        'title': raw['title'],
        'text': formattedText,
        'p1': p1,
        'p2': p2,
      };
      currentRound++;
    });
  }

  Color _cardColor(String? type) {
    switch (type) {
      case 'virus': return const Color(0xFF00B894); // Verde veneno
      case 'duel': return const Color(0xFFFF7675); // Rojo duelo
      case 'rule': return const Color(0xFF6C5CE7); // Morado ley
      case 'vote': return const Color(0xFFFD79A8); // Rosa votación
      case 'category': return const Color(0xFF0984E3); // Azul cadena
      default: return const Color(0xFF00CEC9); // Turquesa reto
    }
  }

  IconData _cardIcon(String? type) {
    switch (type) {
      case 'virus': return Icons.coronavirus_rounded;
      case 'duel': return Icons.sports_kabaddi_rounded;
      case 'rule': return Icons.gavel_rounded;
      case 'vote': return Icons.how_to_vote_rounded;
      case 'category': return Icons.format_list_bulleted_rounded;
      default: return Icons.bolt_rounded;
    }
  }

  void _showPackSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2130),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Packs de Maldiciones", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shuffle_rounded, color: Color(0xFF00CEC9)),
                title: const Text("Todos Mezclados (Party Mix)", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Combina previos, fiesta, picante y sin piedad"),
                trailing: selectedPackId == 'all' ? const Icon(Icons.check_circle, color: Color(0xFF00CEC9)) : null,
                onTap: () {
                  setState(() => selectedPackId = 'all');
                  Navigator.pop(ctx);
                  _loadCards();
                },
              ),
              const Divider(color: Colors.white12),
              ...widget.game.packs.map((pack) {
                final isSelected = selectedPackId == pack.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    pack.rating == '18+' ? Icons.local_fire_department_rounded : Icons.celebration_rounded,
                    color: pack.rating == '18+' ? const Color(0xFFFF7675) : const Color(0xFFFDCB6E),
                  ),
                  title: Text(pack.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${pack.rating} • ${pack.language.toUpperCase()}"),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF00CEC9)) : null,
                  onTap: () {
                    setState(() => selectedPackId = pack.id);
                    Navigator.pop(ctx);
                    _loadCards();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentCard == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cardType = currentCard!['type'] as String?;
    final themeColor = _cardColor(cardType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maldiciones & Duelos'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Cambiar Pack',
            icon: const Icon(Icons.layers_rounded, color: Colors.white70),
            onPressed: _showPackSelector,
          ),
          IconButton(
            tooltip: drinkingMode ? 'Modo Tragos Activado (Toca para Retos)' : 'Modo Retos Activado (Toca para Tragos)',
            icon: Icon(drinkingMode ? Icons.local_bar_rounded : Icons.flash_on_rounded, color: drinkingMode ? const Color(0xFFFDCB6E) : const Color(0xFF00CEC9)),
            onPressed: () {
              setState(() {
                drinkingMode = !drinkingMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(drinkingMode ? "🍻 Modo Tragos activado" : "⚡ Modo Retos / Sobrio activado"),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ruleta de castigos para el perdedor',
            icon: const Icon(Icons.casino_rounded, color: Color(0xFFFDCB6E)),
            onPressed: () => widget.onPenalty(currentCard!['p1']),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Alerta de Virus Curado si lo hay
            if (cureAlert != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF00CEC9).withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF00CEC9))),
                child: Row(
                  children: [
                    const Text("✨", style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cureAlert!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00CEC9)))),
                  ],
                ),
              ),

            // Barra de Virus y Maldiciones Activos
            if (activeViruses.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1E2130), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF00B894).withOpacity(0.5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.coronavirus_rounded, color: Color(0xFF00B894), size: 16),
                            SizedBox(width: 6),
                            Text("MALDICIONES ACTIVAS:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF00B894), letterSpacing: 1.5)),
                          ],
                        ),
                        Text("${activeViruses.length} vigentes", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...activeViruses.map((v) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "• ${v['player']} — ${v['name']} (${v['turnsLeft']} rondas)",
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                activeViruses.remove(v);
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.close, size: 14, color: Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

            // Tarjeta Principal Interactiva
            Expanded(
              child: GestureDetector(
                onTap: _nextCard,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor.withOpacity(0.2), const Color(0xFF1E2130)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: themeColor, width: 2),
                    boxShadow: [
                      BoxShadow(color: themeColor.withOpacity(0.18), blurRadius: 22, spreadRadius: 2)
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: themeColor.withOpacity(0.25), shape: BoxShape.circle),
                        child: Icon(_cardIcon(cardType), size: 48, color: themeColor),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        currentCard!['title'] ?? 'TARJETA',
                        style: TextStyle(letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.w900, color: themeColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        currentCard!['text'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                        child: const Text("Toca la pantalla para la siguiente ➔", style: TextStyle(fontSize: 12, color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Botones inferiores
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDCB6E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => widget.onPenalty(currentCard!['p1']),
                      icon: const Icon(Icons.casino_rounded, color: Colors.black87),
                      label: const Text('Castigo / Falló 🎰', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    onPressed: _nextCard,
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
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
// RESTO DE PANTALLAS (HOT BOMB, MOST LIKELY, NEVER, TRUTH/DARE, WOULD YOU RATHER, COUPLES, FAKE IT, WRONG, CHARADES, CUSTOM QUESTIONS, PENALTIES)
// ==========================================
class CustomQuestionsScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const CustomQuestionsScreen({super.key, required this.prefs});

  @override
  State<CustomQuestionsScreen> createState() => _CustomQuestionsScreenState();
}

class _CustomQuestionsScreenState extends State<CustomQuestionsScreen> {
  String selectedGame = "most_likely_to";
  final TextEditingController _textController = TextEditingController();
  List<String> currentCustomList = [];

  final Map<String, String> gameLabels = {
    "most_likely_to": "¿Quién es más probable?",
    "never_have_i_ever": "Yo Nunca",
    "truth_or_dare_truth": "Verdad o Reto (Verdad)",
    "truth_or_dare_dare": "Verdad o Reto (Reto)",
    "hot_bomb": "La Bomba (Categoría)",
  };

  @override
  void initState() {
    super.initState();
    _loadQuestionsForGame();
  }

  void _loadQuestionsForGame() {
    final list = widget.prefs.getStringList("custom_$selectedGame") ?? [];
    setState(() => currentCustomList = list);
  }

  Future<void> _addQuestion() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final updated = List<String>.from(currentCustomList)..add(text);
    await widget.prefs.setStringList("custom_$selectedGame", updated);
    _textController.clear();
    setState(() => currentCustomList = updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🔒 Pregunta guardada en local (no se sube a internet)."),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF00CEC9),
      ),
    );
  }

  Future<void> _deleteQuestion(int index) async {
    final updated = List<String>.from(currentCustomList)..removeAt(index);
    await widget.prefs.setStringList("custom_$selectedGame", updated);
    setState(() => currentCustomList = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Preguntas Privadas"), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF00CEC9).withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.4))),
              child: Row(
                children: const [
                  Icon(Icons.shield_rounded, color: Color(0xFF00CEC9), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("100% Privado en este dispositivo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00CEC9))),
                        SizedBox(height: 2),
                        Text("Tus preguntas y secretos solo se guardan en este móvil. Jamás se suben a GitHub.", style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("Elige el juego donde aparecerá:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: const Color(0xFF1E2130), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedGame,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E2130),
                  items: gameLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedGame = val);
                      _loadQuestionsForGame();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Escribe tu pregunta secreta...",
                      filled: true,
                      fillColor: const Color(0xFF1E2130),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _addQuestion(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CEC9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  onPressed: _addQuestion,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("Tus preguntas guardadas (${currentCustomList.length}):", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: currentCustomList.isEmpty
                  ? const Center(child: Text("Aún no tienes preguntas privadas para este juego.", style: TextStyle(color: Colors.white54, fontSize: 13)))
                  : ListView.builder(
                      itemCount: currentCustomList.length,
                      itemBuilder: (ctx, i) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF1E2130), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                        child: Row(
                          children: [
                            const Text("🔒", style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(currentCustomList[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _deleteQuestion(i)),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PenaltiesWheelSheet extends StatefulWidget {
  final GitHubContentService service;
  final String? loserName;

  const PenaltiesWheelSheet({super.key, required this.service, this.loserName});

  @override
  State<PenaltiesWheelSheet> createState() => _PenaltiesWheelSheetState();
}

class _PenaltiesWheelSheetState extends State<PenaltiesWheelSheet> {
  List<String> penalties = [];
  String? selectedPenalty;
  bool isSpinning = false;

  @override
  void initState() {
    super.initState();
    _loadPenalties();
  }

  Future<void> _loadPenalties() async {
    final data = await widget.service.loadPackContent("es/penalties/penalties.json");
    if (data != null && data['penalties'] != null) {
      setState(() => penalties = List<String>.from(data['penalties']));
      _spin();
    } else {
      setState(() {
        penalties = ["Bebe 2 sorbos.", "Envía un emoji a un chat.", "Habla con acento extranjero."];
      });
      _spin();
    }
  }

  void _spin() {
    if (penalties.isEmpty || isSpinning) return;
    setState(() => isSpinning = true);

    int count = 0;
    Timer.periodic(const Duration(milliseconds: 90), (timer) {
      setState(() {
        selectedPenalty = penalties[Random().nextInt(penalties.length)];
      });
      count++;
      if (count > 12) {
        timer.cancel();
        setState(() => isSpinning = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("🎰 Ruleta de Castigos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFDCB6E))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.loserName != null ? "¡Castigo directo para ${widget.loserName}!" : "Gira la ruleta para aplicar una prenda.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2C1924), Color(0xFF1E2130)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFDCB6E).withOpacity(0.5))),
            child: Text(selectedPenalty ?? "Girando la ruleta...", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSpinning ? Colors.white60 : const Color(0xFFFF7675), height: 1.4)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDCB6E), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSpinning ? null : _spin,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
                  label: const Text('Girar otra vez', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cumplido ✔️', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HotBombScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;
  final SharedPreferences prefs;
  final Function(String?) onPenalty;

  const HotBombScreen({super.key, required this.game, required this.service, required this.players, required this.prefs, required this.onPenalty});

  @override
  State<HotBombScreen> createState() => _HotBombScreenState();
}

class _HotBombScreenState extends State<HotBombScreen> {
  List<String> categories = [];
  String currentCategory = "Cosas que dan vergüenza ajena";
  bool isPlaying = false;
  bool isExploded = false;
  int currentTurn = 0;
  Timer? _bombTimer;
  int bombDuration = 20;
  int elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    List<String> baseCategories = [];
    if (data != null && data['categories'] != null) {
      baseCategories = List<String>.from(data['categories']);
    }
    final custom = widget.prefs.getStringList("custom_hot_bomb") ?? [];
    categories = [...baseCategories, ...custom];
  }

  void _startBomb() {
    if (categories.isNotEmpty) {
      currentCategory = categories[Random().nextInt(categories.length)];
    }
    bombDuration = 15 + Random().nextInt(20);
    elapsedSeconds = 0;

    setState(() {
      isPlaying = true;
      isExploded = false;
      currentTurn = 0;
    });

    _bombTimer?.cancel();
    _bombTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;
      if (elapsedSeconds >= bombDuration) {
        timer.cancel();
        setState(() {
          isPlaying = false;
          isExploded = true;
        });
      }
    });
  }

  void _passToNext() {
    if (!isPlaying) return;
    setState(() {
      currentTurn = (currentTurn + 1) % widget.players.length;
    });
  }

  @override
  void dispose() {
    _bombTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = widget.players.isNotEmpty ? widget.players[currentTurn] : "Jugador 1";

    if (isExploded) {
      return Scaffold(
        backgroundColor: const Color(0xFFD63031),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("💥", style: TextStyle(fontSize: 84)),
                const SizedBox(height: 16),
                const Text("¡BOOOOOOM!", style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 12),
                Text("¡La bomba le ha explotado en las manos a $currentPlayer!", textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDCB6E), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => widget.onPenalty(currentPlayer),
                  icon: const Icon(Icons.casino_rounded, color: Colors.black87),
                  label: const Text("Aplicar Castigo 🎰", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: _startBomb, child: const Text("Jugar otra ronda de Bomba", style: TextStyle(color: Colors.white70, fontSize: 15)))
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('La Bomba (Hot Bomb)'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isPlaying
            ? Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                    child: Text("Tiene el móvil: $currentPlayer", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF7675))),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2D3436), Color(0xFF1E2130)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFF7675), width: 1.5)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.alarm_on_rounded, size: 70, color: Color(0xFFFF7675)),
                            const SizedBox(height: 20),
                            const Text("CATEGORÍA:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
                            const SizedBox(height: 10),
                            Text(currentCategory, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3)),
                            const SizedBox(height: 24),
                            const Text("¡Di una palabra válida y pásalo volando!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: _passToNext,
                      child: Text("¡Hecho! Pasar a ${widget.players[(currentTurn + 1) % widget.players.length]} ➔", style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.alarm_on_rounded, size: 80, color: Color(0xFFFF7675)),
                    const SizedBox(height: 20),
                    const Text("¿Listos para la bomba?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text("La pantalla mostrará un tema. Di una palabra válida y pasa el móvil rápido.\nEl tiempo es secreto... ¡pierde a quien le explote!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.4)),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: _startBomb,
                      child: const Text('¡Encender mecha!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}

class MostLikelyScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;
  final String intensity;
  final SharedPreferences prefs;

  const MostLikelyScreen({super.key, required this.game, required this.service, required this.players, required this.intensity, required this.prefs});

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
    List<String> baseQuestions = [];
    if (data != null && data['items'] != null) {
      baseQuestions = List<String>.from(data['items']);
    }
    final custom = widget.prefs.getStringList("custom_most_likely_to") ?? [];
    final all = [...baseQuestions, ...custom];
    all.shuffle();
    setState(() => questions = all);
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
        setState(() => countdown = 0);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => isCountingDown = false);
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
    final currentQ = questions.isNotEmpty ? questions[currentIndex] : "¿Quién es más probable que termine detenido por un malentendido?";

    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2D3436), Color(0xFF1E2130)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.5))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 54, color: Color(0xFFA29BFE)),
                      const SizedBox(height: 24),
                      Text(currentQ, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
                      const SizedBox(height: 32),
                      if (isCountingDown)
                        Text(countdown > 0 ? '$countdown' : '👉 ¡SEÑALEN YA! 👈', style: TextStyle(fontSize: countdown > 0 ? 54 : 26, fontWeight: FontWeight.w900, color: countdown > 0 ? const Color(0xFFFDCB6E) : const Color(0xFFFF7675)))
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

class NeverHaveIEverScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;
  final String intensity;
  final SharedPreferences prefs;

  const NeverHaveIEverScreen({super.key, required this.game, required this.service, required this.players, required this.intensity, required this.prefs});

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
    final pack = (widget.intensity == "picante" && widget.game.packs.length > 1) ? widget.game.packs[1] : widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    List<String> baseList = [];
    if (data != null && data['items'] != null) {
      baseList = List<String>.from(data['items']);
    }
    final custom = widget.prefs.getStringList("custom_never_have_i_ever") ?? [];
    final all = [...baseList, ...custom];
    all.shuffle();
    setState(() => statements = all);
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
    final phrase = statements.isNotEmpty ? statements[currentIndex] : "Yo nunca he fingido hablar por teléfono para evitar a alguien.";

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
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2C1924), Color(0xFF1E2130)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFF7675).withOpacity(0.4))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_bar_rounded, size: 56, color: Color(0xFFFF7675)),
                      const SizedBox(height: 24),
                      Text(phrase, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                        child: const Text("¡Si lo has hecho alguna vez, bebes o pierdes 1 vida!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

class TruthOrDareScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;
  final String intensity;
  final SharedPreferences prefs;

  const TruthOrDareScreen({super.key, required this.game, required this.service, required this.players, required this.intensity, required this.prefs});

  @override
  State<TruthOrDareScreen> createState() => _TruthOrDareScreenState();
}

class _TruthOrDareScreenState extends State<TruthOrDareScreen> {
  List<String> truths = [];
  List<String> dares = [];
  String? currentText;
  bool isTruth = true;
  int playerTurn = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    List<String> baseTruths = [];
    List<String> baseDares = [];
    if (data != null) {
      baseTruths = List<String>.from(data['truths'] ?? []);
      baseDares = List<String>.from(data['dares'] ?? []);
    }
    final customTruths = widget.prefs.getStringList("custom_truth_or_dare_truth") ?? [];
    final customDares = widget.prefs.getStringList("custom_truth_or_dare_dare") ?? [];

    setState(() {
      truths = [...baseTruths, ...customTruths];
      dares = [...baseDares, ...customDares];
    });
  }

  String _formatWithPlayers(String template) {
    if (widget.players.length < 2) return template;
    final target = widget.players[(playerTurn + 1) % widget.players.length];
    return template.replaceAll("{target}", target);
  }

  void _choose(bool truth) {
    final list = truth ? truths : dares;
    if (list.isNotEmpty) {
      final raw = list[Random().nextInt(list.length)];
      setState(() {
        isTruth = truth;
        currentText = _formatWithPlayers(raw);
      });
    }
  }

  void _nextPlayer() {
    setState(() {
      playerTurn = (playerTurn + 1) % widget.players.length;
      currentText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePlayer = widget.players.isNotEmpty ? widget.players[playerTurn] : "Jugador 1";

    return Scaffold(
      appBar: AppBar(title: const Text('Verdad o Reto'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4))),
              child: Text("Turno de: $activePlayer", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFA29BFE))),
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
                    border: Border.all(color: currentText == null ? Colors.white24 : isTruth ? const Color(0xFF00CEC9) : const Color(0xFFFD79A8), width: 1.5),
                  ),
                  child: currentText == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 60, color: Color(0xFFFD79A8)),
                            const SizedBox(height: 16),
                            Text('$activePlayer, elige tu destino', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('¿Te atreves a confesar la verdad o prefieres cumplir un reto?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(isTruth ? 'VERDAD' : 'RETO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isTruth ? const Color(0xFF00CEC9) : const Color(0xFFFD79A8), letterSpacing: 2)),
                            const SizedBox(height: 18),
                            Text(currentText!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.4)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (currentText == null)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CEC9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFD79A8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () => _choose(false),
                        child: const Text('Reto 😈', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _nextPlayer,
                  child: const Text('Siguiente turno →', style: TextStyle(fontSize: 17, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WouldYouRatherScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;

  const WouldYouRatherScreen({super.key, required this.game, required this.service});

  @override
  State<WouldYouRatherScreen> createState() => _WouldYouRatherScreenState();
}

class _WouldYouRatherScreenState extends State<WouldYouRatherScreen> {
  List<Map<String, dynamic>> dilemmas = [];
  int currentIndex = 0;
  bool hasVoted = false;
  int? chosenOption;

  @override
  void initState() {
    super.initState();
    _loadDilemmas();
  }

  Future<void> _loadDilemmas() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null && data['dilemmas'] != null) {
      final list = List<Map<String, dynamic>>.from(data['dilemmas']);
      list.shuffle();
      setState(() => dilemmas = list);
    }
  }

  void _vote(int option) {
    if (hasVoted) return;
    setState(() {
      hasVoted = true;
      chosenOption = option;
    });
  }

  void _next() {
    if (currentIndex < dilemmas.length - 1) {
      setState(() {
        currentIndex++;
        hasVoted = false;
        chosenOption = null;
      });
    } else {
      dilemmas.shuffle();
      setState(() {
        currentIndex = 0;
        hasVoted = false;
        chosenOption = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dilemma = dilemmas.isNotEmpty
        ? dilemmas[currentIndex]
        : {"a": "Saber el día de tu muerte.", "b": "Saber la causa pero no cuándo.", "votesA": 38, "votesB": 62};

    return Scaffold(
      appBar: AppBar(title: const Text('¿Qué prefieres?'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _vote(1),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF2D3436)]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: chosenOption == 1 ? Colors.white : Colors.white24, width: chosenOption == 1 ? 2.5 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("OPCIÓN A", style: TextStyle(letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 14),
                      Text(dilemma['a'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
                      if (hasVoted) ...[
                        const SizedBox(height: 18),
                        Text("${dilemma['votesA']}% de la gente", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFDCB6E))),
                      ]
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text("O", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white60)),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _vote(2),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF7675), Color(0xFF2D3436)]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: chosenOption == 2 ? Colors.white : Colors.white24, width: chosenOption == 2 ? 2.5 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("OPCIÓN B", style: TextStyle(letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 14),
                      Text(dilemma['b'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
                      if (hasVoted) ...[
                        const SizedBox(height: 18),
                        Text("${dilemma['votesB']}% de la gente", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF00CEC9))),
                      ]
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (hasVoted)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _next,
                  child: const Text('Siguiente dilema ➔', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            else
              const Text("Toca una opción para votar y ver qué piensa la gente.", style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class CouplesScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;

  const CouplesScreen({super.key, required this.game, required this.service, required this.players});

  @override
  State<CouplesScreen> createState() => _CouplesScreenState();
}

class _CouplesScreenState extends State<CouplesScreen> {
  List<String> questions = [];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final pack = widget.game.packs.first;
    final data = await widget.service.loadPackContent(pack.file);
    if (data != null && data['questions'] != null) {
      final list = List<String>.from(data['questions']);
      list.shuffle();
      setState(() => questions = list);
    }
  }

  void _next() {
    if (currentIndex < questions.length - 1) {
      setState(() => currentIndex++);
    } else {
      questions.shuffle();
      setState(() => currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1 = widget.players.isNotEmpty ? widget.players[0] : "Pareja 1";
    final p2 = widget.players.length > 1 ? widget.players[1] : "Pareja 2";
    final question = questions.isNotEmpty ? questions[currentIndex] : "¿Quién pide antes perdón?";

    return Scaffold(
      appBar: AppBar(title: const Text('Modo Parejas & Citas'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFF7675).withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
              child: Text("Jugando: $p1 y $p2", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFFF7675))),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2C1924), Color(0xFF1E2130)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFF7675).withOpacity(0.5))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_rounded, size: 60, color: Color(0xFFFF7675)),
                      const SizedBox(height: 24),
                      Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
                      const SizedBox(height: 24),
                      const Text("Señalen a la vez o confiesen con total sinceridad.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _next,
                child: const Text('Siguiente pregunta ❤️', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FakeItScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;

  const FakeItScreen({super.key, required this.game, required this.service, required this.players});

  @override
  State<FakeItScreen> createState() => _FakeItScreenState();
}

class _FakeItScreenState extends State<FakeItScreen> {
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
      impostorIndex = Random().nextInt(widget.players.length);
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
    if (currentPrompt == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                  style: TextStyle(fontSize: countdown > 0 ? 70 : 32, fontWeight: FontWeight.w900, color: countdown > 0 ? const Color(0xFFFDCB6E) : const Color(0xFFFF7675)),
                ),
                const SizedBox(height: 20),
                const Text('Observen atentamente las reacciones: ¿quién dudó o copió al resto?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                  onPressed: _startNewRound,
                  child: const Text('Nueva ronda'),
                )
              ],
            ),
          ),
        ),
      );
    }

    final currentPlayer = widget.players[currentPass];
    final isImpostor = currentPass == impostorIndex;

    return Scaffold(
      appBar: AppBar(title: const Text('Fake It (Fíngelo)'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('Turno de $currentPlayer (${currentPass + 1}/${widget.players.length})', style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: (currentPass + 1) / widget.players.length, color: const Color(0xFF00CEC9), backgroundColor: Colors.white10),
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
                            ? (isImpostor ? [const Color(0xFFE84393), const Color(0xFF2C1924)] : [const Color(0xFF00CEC9), const Color(0xFF1E2130)])
                            : [const Color(0xFF2D3436), const Color(0xFF1E2130)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(showSecret ? Icons.visibility_rounded : Icons.fingerprint_rounded, size: 64, color: Colors.white),
                        const SizedBox(height: 20),
                        if (!showSecret) ...[
                          Text('$currentPlayer, mantén pulsado', textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Solo tú puedes ver la pantalla.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ] else ...[
                          if (isImpostor) ...[
                            const Text('🕵️ ¡ERES EL IMPOSTOR! 🕵️', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 12),
                            const Text('No tienes ninguna instrucción.\nCuando termine la cuenta atrás, finge y copia rápidamente lo que hagan los demás.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white)),
                          ] else ...[
                            Text('Categoría: ${currentPrompt!['category']}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                            const SizedBox(height: 12),
                            Text(currentPrompt!['instruction'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CEC9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  if (currentPass < widget.players.length - 1) {
                    setState(() {
                      currentPass++;
                      showSecret = false;
                    });
                  } else {
                    _startCountdown();
                  }
                },
                child: Text(
                  currentPass < widget.players.length - 1 ? 'Pasa el móvil a ${widget.players[currentPass + 1]} →' : '¡Iniciar cuenta atrás!',
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WrongAnswersScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;

  const WrongAnswersScreen({super.key, required this.game, required this.service, required this.players});

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
                        decoration: BoxDecoration(color: const Color(0xFF1E2130), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFDCB6E).withOpacity(0.5))),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('¡PROHIBIDO DECIR LA VERDAD!', style: TextStyle(color: Color(0xFFFF7675), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            Text(q['q'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                    Text(score > 0 ? '¡Ronda terminada! Puntos: $score' : '¿Listo para mentir?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('El jugador debe contestar tantas preguntas como pueda en 30 segundos sin decir NUNCA la verdad.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDCB6E), padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

class CharadesScreen extends StatefulWidget {
  final GameDefinition game;
  final GitHubContentService service;
  final List<String> players;

  const CharadesScreen({super.key, required this.game, required this.service, required this.players});

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
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0984E3), Color(0xFF1E2130)]), borderRadius: BorderRadius.circular(24)),
                        child: Center(
                          child: Text(word, textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0984E3), padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
