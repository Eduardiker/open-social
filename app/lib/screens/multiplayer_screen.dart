import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/multiplayer_service.dart';

class MultiplayerHostScreen extends StatefulWidget {
  final Function(String?) onPenalty;

  const MultiplayerHostScreen({super.key, required this.onPenalty});

  @override
  State<MultiplayerHostScreen> createState() => _MultiplayerHostScreenState();
}

class _MultiplayerHostScreenState extends State<MultiplayerHostScreen> {
  final MultiplayerHostService _hostService = MultiplayerHostService();
  StreamSubscription? _playerSub;
  StreamSubscription? _eventSub;

  bool isP2P = false;
  String roomCode = "FEST";
  List<ConnectedPlayer> connectedPlayers = [];

  // Estado del minijuego activo
  String activeGame = 'lobby'; // 'lobby', 'vote', 'undercover', 'binary', 'fakeit', 'hotpotato'
  String currentQuestion = '';
  Map<String, String> currentVotes = {}; // voterName -> targetName
  Map<String, bool> currentBinary = {}; // voterName -> true/false
  Map<String, String> undercoverWords = {}; // playerName -> word
  String? impostorPlayer;
  String? currentBombHolder;
  Timer? _bombTimer;
  int _bombSecondsLeft = 25;
  bool _bombExploded = false;

  final List<String> fakeItActions = [
    "Pon cara de asco profundo y mira al techo disimuladamente.",
    "Imita que estás tocando una guitarra eléctrica en un solo de rock.",
    "Haz como si estuvieras levantando una pesa de 150 kg sufriendo.",
    "Cruza los brazos, asiente con la cabeza y pon cara de juez enfadado.",
    "Imita que te estás tomando una taza de café hirviendo.",
    "Haz como si estuvieras en una montaña rusa a punto de caer.",
    "Pon cara de galán de telenovela y guiña un ojo a la persona enfrente.",
    "Haz como si te hubiera picado una avispa en la espalda.",
  ];

  final List<String> potatoCategories = [
    "Marcas de cerveza",
    "Excusas para no ir a trabajar o clase",
    "Cosas que puedes encontrar en un baño ajeno",
    "Razas de perro o animales salvajes",
    "Películas famosas de Disney o Pixar",
    "Cosas que te dan vergüenza ajena",
    "Ciudades o países de Europa",
    "Platos de comida rápida",
  ];

  final List<Map<String, String>> undercoverPairs = [
    {'civil': 'Playa', 'impostor': 'Piscina'},
    {'civil': 'Café', 'impostor': 'Té'},
    {'civil': 'Cerveza', 'impostor': 'Vino'},
    {'civil': 'Perro', 'impostor': 'Gato'},
    {'civil': 'Fútbol', 'impostor': 'Baloncesto'},
    {'civil': 'Pizza', 'impostor': 'Hamburguesa'},
    {'civil': 'Netflix', 'impostor': 'Cine'},
    {'civil': 'Guitarra', 'impostor': 'Piano'},
  ];

  @override
  void initState() {
    super.initState();
    _initHost();
  }

  Future<void> _initHost() async {
    roomCode = _generateRoomCode();
    await _hostService.startLocalServer(listenPort: 8080);

    _playerSub = _hostService.playersStream.listen((players) {
      setState(() {
        connectedPlayers = players;
      });
    });

    _eventSub = _hostService.eventsStream.listen((event) {
      final type = event['type'];
      if (type == 'vote_received') {
        final voter = connectedPlayers.firstWhere((p) => p.id == event['voterId'], orElse: () => connectedPlayers.first);
        setState(() {
          currentVotes[voter.name] = event['target'];
        });
      } else if (type == 'binary_received') {
        final voter = connectedPlayers.firstWhere((p) => p.id == event['voterId'], orElse: () => connectedPlayers.first);
        setState(() {
          currentBinary[voter.name] = event['value'];
        });
      } else if (type == 'bomb_passed') {
        setState(() {
          currentBombHolder = event['to'];
        });
        _hostService.updateHotPotato(currentQuestion, currentBombHolder!);
      }
    });

    setState(() {});
  }

  String _generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    final rand = Random();
    return List.generate(4, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _bombTimer?.cancel();
    _playerSub?.cancel();
    _eventSub?.cancel();
    _hostService.stop();
    super.dispose();
  }

  String get connectionUrl {
    if (isP2P) {
      return "https://eduardiker.github.io/open-social/play.html?room=$roomCode";
    } else {
      return "http://${_hostService.localIp}:${_hostService.port}";
    }
  }

  // Iniciar Votación Secreta
  void _startSecretVote() {
    if (connectedPlayers.length < 2) {
      _showWarning("Se necesitan al menos 2 jugadores conectados.");
      return;
    }

    final questions = [
      "¿Quién tiene más probabilidades de acabar en comisaría un sábado?",
      "¿Quién tardaría menos en vender a sus amigos por 1 millón de euros?",
      "¿Quién sería el peor compañero de piso de todos?",
      "¿Quién tiene el historial de Google más turbio o vergonzoso?",
      "¿Quién es el más dramático de todo el grupo?",
    ];
    final q = questions[Random().nextInt(questions.length)];

    currentVotes.clear();
    final options = connectedPlayers.map((p) => {'name': p.name, 'avatar': p.avatar}).toList();
    _hostService.startSecretVoting(q, options);

    setState(() {
      activeGame = 'vote';
      currentQuestion = q;
    });
  }

  // Iniciar Partida de El Impostor (Undercover)
  void _startUndercover() {
    if (connectedPlayers.length < 3) {
      _showWarning("El Impostor requiere al menos 3 jugadores.");
      return;
    }

    final pair = undercoverPairs[Random().nextInt(undercoverPairs.length)];
    final rand = Random();
    final impostorIndex = rand.nextInt(connectedPlayers.length);
    impostorPlayer = connectedPlayers[impostorIndex].name;

    final roles = <String, Map<String, String>>{};
    for (int i = 0; i < connectedPlayers.length; i++) {
      final p = connectedPlayers[i];
      if (i == impostorIndex) {
        roles[p.name] = {'role': 'IMPOSTOR 🤫', 'word': pair['impostor']!};
      } else {
        roles[p.name] = {'role': 'CIVIL 😇', 'word': pair['civil']!};
      }
    }

    _hostService.distributeUndercoverRoles(roles);

    setState(() {
      activeGame = 'undercover';
      currentQuestion = "Ronda de Pistas: Cada jugador dice 1 palabra sobre su secreto. ¡Atrapad al Impostor!";
    });
  }

  // Iniciar Yo Nunca Colectivo
  void _startBinaryGame() {
    final prompts = [
      "Yo nunca he fingido estar enfermo para librarme de un plan.",
      "Yo nunca he stalkeado el perfil de mi ex desde una cuenta secundaria.",
      "Yo nunca he enviado un mensaje comprometido al grupo de WhatsApp equivocado.",
      "Yo nunca he besado a más de dos personas en la misma fiesta.",
      "Yo nunca he usado el cepillo de dientes de otra persona sin decírselo.",
    ];
    final p = prompts[Random().nextInt(prompts.length)];

    currentBinary.clear();
    _hostService.startBinaryPrompt(p);

    setState(() {
      activeGame = 'binary';
      currentQuestion = p;
    });
  }

  void _startFakeItLive() {
    if (connectedPlayers.length < 3) {
      _showWarning("Fake It requiere al menos 3 jugadores.");
      return;
    }

    final act = fakeItActions[Random().nextInt(fakeItActions.length)];
    final imp = connectedPlayers[Random().nextInt(connectedPlayers.length)].name;
    impostorPlayer = imp;

    _hostService.startFakeItRound(act, imp);

    setState(() {
      activeGame = 'fakeit';
      currentQuestion = "Cuenta atrás: 3, 2, 1... ¡ACTUAD A LA VEZ! Atrapad al Camaleón.";
    });
  }

  void _startHotPotatoLive() {
    if (connectedPlayers.length < 2) {
      _showWarning("La Patata Caliente requiere al menos 2 jugadores.");
      return;
    }

    _bombTimer?.cancel();
    final cat = potatoCategories[Random().nextInt(potatoCategories.length)];
    final initial = connectedPlayers[Random().nextInt(connectedPlayers.length)].name;
    currentBombHolder = initial;
    _bombSecondsLeft = 18 + Random().nextInt(14);
    _bombExploded = false;

    _hostService.updateHotPotato(cat, initial);

    _bombTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _bombSecondsLeft--;
        if (_bombSecondsLeft <= 0) {
          timer.cancel();
          _bombExploded = true;
          _hostService.sendPenaltyAlert(currentBombHolder!, "¡BOOM! Te ha explotado la bomba.");
        }
      });
    });

    setState(() {
      activeGame = 'hotpotato';
      currentQuestion = "Categoría: $cat. ¡Pasa la bomba antes de que estalle!";
    });
  }

  void _returnToLobby() {
    _bombTimer?.cancel();
    _hostService.resetToLobby();
    setState(() {
      activeGame = 'lobby';
    });
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sala Multijugador (Host)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Cambiar modo (WiFi / Online)',
            icon: Icon(isP2P ? Icons.public_rounded : Icons.wifi_rounded, color: const Color(0xFF00CEC9)),
            onPressed: () {
              setState(() {
                isP2P = !isP2P;
              });
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
        child: Column(
          children: [
            // Cabecera con Selector de Modo
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => isP2P = false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !isP2P ? const Color(0xFF00CEC9).withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: !isP2P ? const Color(0xFF00CEC9) : Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.wifi_rounded, size: 16, color: Color(0xFF00CEC9)),
                          SizedBox(width: 6),
                          Text("Misma WiFi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => isP2P = true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isP2P ? const Color(0xFF6C5CE7).withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isP2P ? const Color(0xFF6C5CE7) : Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.public_rounded, size: 16, color: Color(0xFF6C5CE7)),
                          SizedBox(width: 6),
                          Text("Online (Código)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CONTENIDO SEGÚN ESTADO DE JUEGO
            Expanded(
              child: activeGame == 'lobby'
                  ? _buildLobbyView()
                  : _buildActiveGameView(),
            ),
          ],
        ),
      ),
    );
  }

  // Vista 1: Lobby con QR, Código y Lista de Jugadores
  Widget _buildLobbyView() {
    final qrApi = "https://quickchart.io/qr?size=220&text=${Uri.encodeComponent(connectionUrl)}";

    return Column(
      children: [
        // Tarjeta con QR y Enlace
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2130),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2D3250)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
          ),
          child: Column(
            children: [
              if (isP2P) ...[
                const Text("CÓDIGO DE SALA ONLINE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF6C5CE7), letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(roomCode, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 4, color: Color(0xFFFDCB6E))),
                const SizedBox(height: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.network(
                    qrApi,
                    width: 140,
                    height: 140,
                    errorBuilder: (ctx, err, stack) => const SizedBox(
                      width: 140,
                      height: 140,
                      child: Center(child: Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.black54)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Apunta la cámara para entrar:",
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  connectionUrl,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Jugadores Conectados
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.people_rounded, size: 18, color: Color(0xFF00CEC9)),
                const SizedBox(width: 6),
                Text("JUGADORES EN SALA (${connectedPlayers.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF00CEC9), letterSpacing: 1.2)),
              ],
            ),
            if (connectedPlayers.isEmpty)
              const Text("Esperando escaneo...", style: TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: connectedPlayers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_iphone_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text("¡Dile a tus amigos que escaneen el QR!", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: connectedPlayers.length,
                  itemBuilder: (ctx, idx) {
                    final p = connectedPlayers[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2130),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Text(p.avatar, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF00CEC9), size: 18),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Botones de Juegos Multijugador
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Text("🕵️", style: TextStyle(fontSize: 16)),
                    label: const Text("El Impostor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    onPressed: _startUndercover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE84393),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Text("🎭", style: TextStyle(fontSize: 16)),
                    label: const Text("Fake It Live", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    onPressed: _startFakeItLive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00CEC9),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Text("🗳️", style: TextStyle(fontSize: 16)),
                    label: const Text("Votación Secreta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F111A))),
                    onPressed: _startSecretVote,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD63031),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Text("💣", style: TextStyle(fontSize: 16)),
                    label: const Text("Patata Caliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    onPressed: _startHotPotatoLive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7675),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Text("🍻", style: TextStyle(fontSize: 16)),
                label: const Text("Yo Nunca Live (Respuestas en Vivo)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                onPressed: _startBinaryGame,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Vista 2: Minijuego en Pantalla Central (Host TV / Móvil)
  Widget _buildActiveGameView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D3250), Color(0xFF1E2130)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF6C5CE7)),
          ),
          child: Column(
            children: [
              Text(
                activeGame == 'undercover'
                    ? "🕵️ EL IMPOSTOR EN JUEGO"
                    : activeGame == 'fakeit'
                        ? "🎭 FAKE IT • EL CAMALEÓN"
                        : activeGame == 'hotpotato'
                            ? "💣 LA PATATA CALIENTE EN VIVO"
                            : activeGame == 'vote'
                                ? "🗳️ VOTACIÓN SECRETA EN CURSO"
                                : "🍻 RESPUESTAS EN VIVO",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF00CEC9), letterSpacing: 2),
              ),
              const SizedBox(height: 14),
              Text(
                currentQuestion,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Resultados o Progreso en Vivo
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2130),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: activeGame == 'vote'
                ? _buildVoteResults()
                : activeGame == 'binary'
                    ? _buildBinaryResults()
                    : activeGame == 'fakeit'
                        ? _buildFakeItHostView()
                        : activeGame == 'hotpotato'
                            ? _buildHotPotatoHostView()
                            : _buildUndercoverHostView(),
          ),
        ),
        const SizedBox(height: 14),

        // Botones de Control de Ronda
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                label: const Text("Volver al Lobby", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _returnToLobby,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDCB6E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.casino_rounded, color: Colors.black87),
                label: const Text("Girar Ruleta 🎰", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                onPressed: () => widget.onPenalty(impostorPlayer),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Resultados de Votación Secreta
  Widget _buildVoteResults() {
    final votesCount = <String, int>{};
    for (var target in currentVotes.values) {
      votesCount[target] = (votesCount[target] ?? 0) + 1;
    }

    final totalVotes = currentVotes.length;
    final pending = connectedPlayers.length - totalVotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Votos recibidos: $totalVotes de ${connectedPlayers.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00CEC9))),
            if (pending > 0)
              Text("Faltan $pending...", style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: connectedPlayers.map((p) {
              final count = votesCount[p.name] ?? 0;
              final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${p.avatar} ${p.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("$count votos", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFDCB6E))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 10,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF00CEC9)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Resultados de Yo Nunca en Vivo
  Widget _buildBinaryResults() {
    int yesCount = 0;
    int noCount = 0;
    for (var val in currentBinary.values) {
      if (val) yesCount++; else noCount++;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFF7675).withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFF7675))),
                child: Column(
                  children: [
                    const Text("¡YO SÍ! (CULPABLES)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF7675))),
                    const SizedBox(height: 6),
                    Text("$yesCount", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFFF7675))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF00B894).withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF00B894))),
                child: Column(
                  children: [
                    const Text("YO NUNCA (INOCENTES)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
                    const SizedBox(height: 6),
                    Text("$noCount", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF00B894))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text("Detalle de Respuestas:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: currentBinary.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: entry.value ? const Color(0xFFFF7675).withOpacity(0.2) : const Color(0xFF00B894).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.value ? "¡Yo Sí! 🙋" : "Yo Nunca 😇",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: entry.value ? const Color(0xFFFF7675) : const Color(0xFF00B894)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Vista Host de El Impostor
  Widget _buildUndercoverHostView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_rounded, size: 48, color: Color(0xFFFDCB6E)),
        const SizedBox(height: 12),
        const Text("Palabras enviadas en secreto a cada móvil.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Text("Cada jugador debe decir una pista por turnos.", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Revelar Impostor (Solo Host): ", style: TextStyle(fontSize: 12, color: Colors.white54)),
              Text(impostorPlayer ?? "Desconocido", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF7675))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFakeItHostView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.theater_comedy_rounded, size: 54, color: Color(0xFFE84393)),
        const SizedBox(height: 14),
        const Text("¡Acción enviada a los móviles!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text("Contad hasta 3 y actuad a la vez.", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("El Camaleón es: ", style: TextStyle(fontSize: 12, color: Colors.white60)),
              Text(impostorPlayer ?? "Desconocido", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF7675))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHotPotatoHostView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _bombExploded ? "💥" : "💣",
          style: const TextStyle(fontSize: 54),
        ),
        const SizedBox(height: 12),
        if (!_bombExploded) ...[
          Text("$_bombSecondsLeft s", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFFFF7675))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFF7675).withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFF7675))),
            child: Text("Bomba en manos de: $currentBombHolder", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFF7675))),
          ),
        ] else ...[
          const Text("¡BOOOOOM! EXPLOTÓ", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF7675))),
          const SizedBox(height: 8),
          Text("¡Le explotó a $currentBombHolder en la mano!", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDCB6E)),
            onPressed: () => widget.onPenalty(currentBombHolder),
            child: const Text("Girar Ruleta para el Perdedor 🎰", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
