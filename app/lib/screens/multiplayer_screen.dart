import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Configuración del Host como jugador activo
  String hostPlayerName = "Host (Tú)";
  String hostPlayerAvatar = "👑";
  bool hostParticipates = true;
  bool isHostRoleRevealed = false;
  bool isImpostorRevealed = false;
  bool isVoteFinalized = false;
  Timer? _autoFinalizeTimer;
  int _autoFinalizeCountdown = 5;
  int fakeItCountdownVal = 3;
  bool isFakeItCounting = false;
  Timer? _fakeItTimer;
  Map<String, Map<String, String>> currentUndercoverRoles = {};
  String currentUndercoverCivilWord = '';
  String currentUndercoverImpostorWord = '';
  String currentFakeItAction = '';

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

    if (hostParticipates) {
      _hostService.addHostPlayer(name: hostPlayerName, avatar: hostPlayerAvatar);
    }
    connectedPlayers = List.from(_hostService.players);

    _playerSub = _hostService.playersStream.listen((players) {
      if (mounted) {
        setState(() {
          connectedPlayers = players;
        });
      }
    });

    _eventSub = _hostService.eventsStream.listen((event) {
      final type = event['type'];
      if (type == 'vote_received') {
        final voterId = event['voterId'];
        final voterName = (voterId == 'host')
            ? hostPlayerName
            : (event['voterName'] ??
                (connectedPlayers.where((p) => p.id == voterId).isNotEmpty
                    ? connectedPlayers.firstWhere((p) => p.id == voterId).name
                    : 'Jugador'));
        if (mounted) {
          setState(() {
            currentVotes[voterName] = event['target'];
          });
        }
        _checkAutoFinalizeVote();
      } else if (type == 'binary_received') {
        final voterId = event['voterId'];
        final voterName = (voterId == 'host')
            ? hostPlayerName
            : (event['voterName'] ??
                (connectedPlayers.where((p) => p.id == voterId).isNotEmpty
                    ? connectedPlayers.firstWhere((p) => p.id == voterId).name
                    : 'Jugador'));
        if (mounted) {
          setState(() {
            currentBinary[voterName] = (event['value'] == true || event['value'] == 'YES');
          });
        }
        _checkAutoFinalizeBinary();
      } else if (type == 'bomb_passed') {
        if (mounted) {
          setState(() {
            currentBombHolder = event['to'];
          });
        }
        _hostService.updateHotPotato(currentQuestion, currentBombHolder!);
      }
    });

    if (mounted) setState(() {});
  }

  String _generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    final rand = Random();
    return List.generate(4, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _autoFinalizeTimer?.cancel();
    _fakeItTimer?.cancel();
    _bombTimer?.cancel();
    _playerSub?.cancel();
    _eventSub?.cancel();
    _hostService.stop();
    super.dispose();
  }

  String get connectionUrl => "http://${_hostService.localIp}:${_hostService.port}";

  final List<String> secretVoteQuestions = [
    "¿Quién tiene más probabilidades de acabar en comisaría un sábado?",
    "¿Quién tardaría menos en vender a sus amigos por 1 millón de euros?",
    "¿Quién sería el peor compañero de piso de todos?",
    "¿Quién tiene el historial de Google más turbio o vergonzoso?",
    "¿Quién es el más dramático o dramática de todo el grupo?",
    "¿Quién volvería con su peor ex solo por no estar soltero/a?",
    "¿Quién sobreviviría menos tiempo en un apocalipsis zombi?",
    "¿Quién se emborracha más rápido y empieza a enviar audios peligrosos?",
    "¿Quién gastaría todo su sueldo en tonterías la primera semana del mes?",
    "¿Quién sería el peor cuidando de un bebé durante un fin de semana?",
    "¿Quién oculta más secretos inconfesables en su galería de fotos?",
    "¿Quién se inventaría una boda para no ir a trabajar?",
    "¿Quién sería arrestado por hacer algo absurdo en una fiesta?",
    "¿Quién liga más por redes pero luego en persona se bloquea?",
    "¿Quién es más probable que se case en Las Vegas con alguien que conoció ayer?",
    "¿Quién tardaría más en darse cuenta de que le están tomando el pelo?",
    "¿Quién es más probable que termine viviendo debajo de un puente por gastón?",
    "¿Quién fingiría su propia muerte para escapar de una deuda o vergüenza?",
  ];

  final List<String> yoNuncaPrompts = [
    "Yo nunca he fingido estar enfermo para librarme de un plan con amigos.",
    "Yo nunca he stalkeado el perfil de mi ex desde una cuenta secundaria falsa.",
    "Yo nunca he enviado una captura de pantalla a la misma persona de la que hablaba.",
    "Yo nunca he besado a más de dos personas en la misma fiesta.",
    "Yo nunca he usado el cepillo de dientes de otra persona sin decírselo.",
    "Yo nunca he mentido sobre mi edad para ligar o entrar a una discoteca.",
    "Yo nunca he mirado el móvil de mi pareja o ligue a escondidas.",
    "Yo nunca me he quedado dormido en el baño de un bar o discoteca.",
    "Yo nunca he borrado mensajes de WhatsApp para que nadie los descubriera.",
    "Yo nunca he fingido un orgasmo para terminar antes.",
    "Yo nunca he tenido un crush secreto con alguien de este grupo.",
    "Yo nunca he salido a la calle sin ropa interior por pereza.",
    "Yo nunca he vomitado en una fiesta y he culpado disimuladamente a otro.",
    "Yo nunca me he enamorado del crush o ex de un amigo/a.",
    "Yo nunca he robado un vaso, copa o cenicero de un bar.",
    "Yo nunca he mandado una foto provocativa de la que luego me he arrepentido.",
    "Yo nunca he dicho 'te quiero' solo por compromiso sin sentirlo.",
    "Yo nunca he fingido no ver a alguien por la calle para no saludarle.",
  ];

  final List<String> hotPotatoCategories = [
    "Marcas de cerveza o alcohol",
    "Razas de perro",
    "Países que empiecen por M, C o B",
    "Excusas típicas para llegar tarde",
    "Películas de superhéroes o Marvel",
    "Ingredientes de pizza",
    "Cosas que encuentras en el baño",
    "Marcas de coches o motos",
    "Cantantes de reggaeton o música urbana",
    "Deportes olímpicos",
    "Series populares de Netflix o HBO",
    "Comida rápida o hamburgueserías",
    "Cosas que no deberías decir en una primera cita",
    "Marcas de ropa o zapatillas",
    "Capitales de Europa o del mundo",
    "Animales salvajes peligrosos",
  ];

  List<ConnectedPlayer> get activeParticipants {
    return hostParticipates
        ? connectedPlayers
        : connectedPlayers.where((p) => p.id != 'host').toList();
  }

  void _checkAutoFinalizeVote() {
    if (isVoteFinalized) return;
    final totalExpected = activeParticipants.length;
    if (totalExpected > 0 && currentVotes.length >= totalExpected) {
      if (_autoFinalizeTimer == null) {
        _autoFinalizeCountdown = 5;
        _autoFinalizeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() {
            _autoFinalizeCountdown--;
            if (_autoFinalizeCountdown <= 0) {
              t.cancel();
              _autoFinalizeTimer = null;
              _finalizeVote();
            }
          });
        });
      }
    }
  }

  void _finalizeVote() {
    _autoFinalizeTimer?.cancel();
    _autoFinalizeTimer = null;

    final votesCount = <String, int>{};
    for (var target in currentVotes.values) {
      votesCount[target] = (votesCount[target] ?? 0) + 1;
    }

    String maxVoted = "Nadie";
    int maxCount = 0;
    votesCount.forEach((k, v) {
      if (v > maxCount) {
        maxCount = v;
        maxVoted = k;
      }
    });

    _hostService.broadcastVoteResults(
      winnerName: maxVoted,
      votes: maxCount,
      counts: votesCount,
      question: currentQuestion,
    );

    setState(() {
      isVoteFinalized = true;
    });
  }

  void _checkAutoFinalizeBinary() {
    if (isVoteFinalized) return;
    final totalExpected = activeParticipants.length;
    if (totalExpected > 0 && currentBinary.length >= totalExpected) {
      if (_autoFinalizeTimer == null) {
        _autoFinalizeCountdown = 5;
        _autoFinalizeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() {
            _autoFinalizeCountdown--;
            if (_autoFinalizeCountdown <= 0) {
              t.cancel();
              _autoFinalizeTimer = null;
              _finalizeBinary();
            }
          });
        });
      }
    }
  }

  void _finalizeBinary() {
    _autoFinalizeTimer?.cancel();
    _autoFinalizeTimer = null;

    final guilty = currentBinary.entries.where((e) => e.value).map((e) => e.key).toList();
    int yesCount = currentBinary.values.where((v) => v).length;
    int noCount = currentBinary.values.where((v) => !v).length;

    _hostService.broadcastBinaryResults(
      guilty: guilty,
      yesCount: yesCount,
      noCount: noCount,
      prompt: currentQuestion,
    );

    setState(() {
      isVoteFinalized = true;
    });
  }

  void _startFakeItCountdown() {
    if (isFakeItCounting) return;
    setState(() {
      isFakeItCounting = true;
      fakeItCountdownVal = 3;
    });

    _hostService.broadcastCountdown(3);

    _fakeItTimer?.cancel();
    _fakeItTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        fakeItCountdownVal--;
        if (fakeItCountdownVal > 0) {
          _hostService.broadcastCountdown(fakeItCountdownVal);
        } else if (fakeItCountdownVal == 0) {
          _hostService.broadcastCountdown("¡ACTUAD!");
        } else {
          t.cancel();
          _fakeItTimer = null;
          isFakeItCounting = false;
        }
      });
    });
  }

  // Iniciar Votación Secreta
  void _startSecretVote() {
    _autoFinalizeTimer?.cancel();
    _autoFinalizeTimer = null;
    isVoteFinalized = false;
    currentVotes.clear();

    final players = activeParticipants;
    if (players.length < 2) {
      _showWarning("Votación Secreta requiere al menos 2 jugadores activos (actualmente: ${players.length}).");
      return;
    }

    final q = secretVoteQuestions[Random().nextInt(secretVoteQuestions.length)];
    final options = players.map((p) => {'name': p.name, 'avatar': p.avatar}).toList();
    _hostService.startSecretVoting(q, options);

    setState(() {
      activeGame = 'vote';
      currentQuestion = q;
      isVoteFinalized = false;
    });
  }

  // Iniciar Partida de El Impostor (Undercover)
  void _startUndercover() {
    _autoFinalizeTimer?.cancel();
    _autoFinalizeTimer = null;

    final players = activeParticipants;
    if (players.length < 3) {
      _showWarning("El Impostor requiere al menos 3 jugadores activos (actualmente: ${players.length}).");
      return;
    }

    final pair = undercoverPairs[Random().nextInt(undercoverPairs.length)];
    final impostorIndex = Random().nextInt(players.length);
    impostorPlayer = players[impostorIndex].name;
    currentUndercoverCivilWord = pair['civil']!;
    currentUndercoverImpostorWord = pair['impostor']!;

    final roles = <String, Map<String, String>>{};
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if (i == impostorIndex) {
        roles[p.name] = {'role': 'IMPOSTOR 🤫', 'word': pair['impostor']!};
      } else {
        roles[p.name] = {'role': 'CIVIL 😇', 'word': pair['civil']!};
      }
    }

    currentUndercoverRoles = roles;
    isHostRoleRevealed = false;
    isImpostorRevealed = false;
    _hostService.distributeUndercoverRoles(roles);

    setState(() {
      activeGame = 'undercover';
      currentQuestion = "Ronda de Pistas: Cada jugador dice 1 palabra sobre su secreto. ¡Atrapad al Impostor!";
      isHostRoleRevealed = false;
      isImpostorRevealed = false;
    });
  }

  // Iniciar Yo Nunca Colectivo
  void _startBinaryGame() {
    _autoFinalizeTimer?.cancel();
    _autoFinalizeTimer = null;
    isVoteFinalized = false;
    currentBinary.clear();

    final players = activeParticipants;
    if (players.isEmpty) {
      _showWarning("Se necesita al menos 1 jugador para jugar a Yo Nunca.");
      return;
    }

    final p = yoNuncaPrompts[Random().nextInt(yoNuncaPrompts.length)];
    _hostService.startBinaryPrompt(p);

    setState(() {
      activeGame = 'binary';
      currentQuestion = p;
      isVoteFinalized = false;
    });
  }

  void _startFakeItLive() {
    _autoFinalizeTimer?.cancel();
    _autoFinalizeTimer = null;
    _fakeItTimer?.cancel();
    _fakeItTimer = null;
    isFakeItCounting = false;

    final players = activeParticipants;
    if (players.length < 3) {
      _showWarning("Fake It requiere al menos 3 jugadores activos (actualmente: ${players.length}).");
      return;
    }

    final act = fakeItActions[Random().nextInt(fakeItActions.length)];
    final imp = players[Random().nextInt(players.length)].name;
    impostorPlayer = imp;
    currentFakeItAction = act;
    isHostRoleRevealed = false;
    isImpostorRevealed = false;

    _hostService.startFakeItRound(act, imp);

    setState(() {
      activeGame = 'fakeit';
      currentQuestion = "Pulsa 'Iniciar Cuenta Atrás 3, 2, 1' y actuad a la vez. ¡Atrapad al Camaleón!";
      isHostRoleRevealed = false;
      isImpostorRevealed = false;
      isFakeItCounting = false;
    });
  }

  void _startHotPotatoLive() {
    final players = activeParticipants;
    if (players.length < 2) {
      _showWarning("La Patata Caliente requiere al menos 2 jugadores activos (actualmente: ${players.length}).");
      return;
    }

    _bombTimer?.cancel();
    final cat = potatoCategories[Random().nextInt(potatoCategories.length)];
    final initial = players[Random().nextInt(players.length)].name;
    currentBombHolder = initial;
    _bombSecondsLeft = 18 + Random().nextInt(14);
    _bombExploded = false;

    _hostService.updateHotPotato(cat, initial);

    _bombTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    _autoFinalizeTimer?.cancel();
    _autoFinalizeTimer = null;
    _fakeItTimer?.cancel();
    _fakeItTimer = null;
    isFakeItCounting = false;
    isVoteFinalized = false;
    isImpostorRevealed = false;
    currentVotes.clear();
    currentBinary.clear();
    _hostService.resetToLobby();
    setState(() {
      activeGame = 'lobby';
    });
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sala Multijugador (Host)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
        child: Column(
          children: [
            if (activeGame == 'lobby') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00CEC9).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_rounded, color: Color(0xFF00CEC9), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("CONEXIÓN LOCAL DIRECTA", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF00CEC9), letterSpacing: 1.2)),
                          SizedBox(height: 2),
                          Text("Misma red WiFi o 'Zona WiFi / Compartir Internet' de este móvil. Sin lag y sin internet.", style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

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
                "Escanea este QR con la cámara de tu móvil para entrar:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: connectionUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("📋 Dirección copiada al portapapeles"), duration: Duration(seconds: 1)),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: Color(0xFF00CEC9)),
                      const SizedBox(width: 6),
                      Text(
                        connectionUrl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tarjeta de Participación del Host
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hostParticipates ? const Color(0xFF6C5CE7).withOpacity(0.2) : Colors.white10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hostParticipates ? const Color(0xFF6C5CE7) : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(hostPlayerAvatar, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hostParticipates ? "👑 El Host participa activamente" : "📺 Host en Modo Presentador / TV",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hostParticipates
                          ? "Votas, recibes la bomba y juegas en esta pantalla."
                          : "Solo juegan tus amigos desde sus móviles; tú actúas de árbitro.",
                      style: TextStyle(fontSize: 11, color: hostParticipates ? const Color(0xFF00CEC9) : Colors.white60),
                    ),
                  ],
                ),
              ),
              Switch(
                value: hostParticipates,
                activeColor: const Color(0xFF00CEC9),
                onChanged: (val) {
                  setState(() {
                    hostParticipates = val;
                    if (val) {
                      _hostService.addHostPlayer(name: hostPlayerName, avatar: hostPlayerAvatar);
                    } else {
                      _hostService.removeHostPlayer();
                    }
                    connectedPlayers = List.from(_hostService.players);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Jugadores Conectados
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.people_rounded, size: 18, color: Color(0xFF00CEC9)),
                const SizedBox(width: 6),
                Text(
                  "JUGADORES ACTIVOS (${activeParticipants.length})",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF00CEC9), letterSpacing: 1.2),
                ),
              ],
            ),
            if (activeParticipants.isEmpty)
              const Text("Esperando escaneo...", style: TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: activeParticipants.isEmpty
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
                  itemCount: activeParticipants.length,
                  itemBuilder: (ctx, idx) {
                    final p = activeParticipants[idx];
                    final isHost = p.id == 'host';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2130),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isHost ? const Color(0xFFFDCB6E).withOpacity(0.6) : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Text(p.avatar, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (isHost) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDCB6E).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDCB6E), width: 1),
                                    ),
                                    child: const Text("ANFITRIÓN", style: TextStyle(color: Color(0xFFFDCB6E), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(isHost ? Icons.verified_user_rounded : Icons.check_circle_rounded, color: isHost ? const Color(0xFFFDCB6E) : const Color(0xFF00CEC9), size: 18),
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
                    label: const Text("El Impostor (Mín. 3)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
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
                    label: const Text("Fake It Live (Mín. 3)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
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
                    label: const Text("Votación Secreta (Mín. 2)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F111A))),
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
                    label: const Text("Patata Caliente (Mín. 2)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
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

        // 1. Botón Principal Inteligente según Estado del Juego
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _getMainActionButtonColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            icon: Icon(_getMainActionButtonIcon(), size: 22, color: Colors.white),
            label: Text(
              _getMainActionButtonText(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            onPressed: isFakeItCounting ? null : _handleMainActionButtonPressed,
          ),
        ),
        const SizedBox(height: 10),

        // 2. Fila Secundaria: Volver al Lobby y Ruleta de Castigos
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text("Volver al Lobby", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _returnToLobby,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDCB6E),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.casino_rounded, color: Colors.black87, size: 18),
                label: const Text("Girar Ruleta 🎰", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  String? targetLoser;
                  if (activeGame == 'vote') {
                    final votesCount = <String, int>{};
                    for (var t in currentVotes.values) {
                      votesCount[t] = (votesCount[t] ?? 0) + 1;
                    }
                    int maxC = 0;
                    votesCount.forEach((k, v) {
                      if (v > maxC) {
                        maxC = v;
                        targetLoser = k;
                      }
                    });
                  } else if (activeGame == 'binary') {
                    final guilty = currentBinary.entries.where((e) => e.value).map((e) => e.key).toList();
                    if (guilty.isNotEmpty) {
                      targetLoser = guilty[Random().nextInt(guilty.length)];
                    }
                  } else if (activeGame == 'undercover' || activeGame == 'fakeit') {
                    targetLoser = impostorPlayer;
                  } else if (activeGame == 'hotpotato') {
                    targetLoser = currentBombHolder;
                  }
                  widget.onPenalty(targetLoser);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getMainActionButtonText() {
    switch (activeGame) {
      case 'vote':
        if (!isVoteFinalized) {
          if (_autoFinalizeTimer != null) {
            return "⚡ Ver Resultados Ya (o en $_autoFinalizeCountdown s)";
          }
          return "⏹️ Finalizar Votación y Revelar Ganador";
        }
        return "➡️ Siguiente Votación";
      case 'binary':
        if (!isVoteFinalized) {
          if (_autoFinalizeTimer != null) {
            return "⚡ Ver Culpables Ya (o en $_autoFinalizeCountdown s)";
          }
          return "⏹️ Finalizar Ronda y Ver Culpables";
        }
        return "➡️ Siguiente Yo Nunca";
      case 'undercover':
        if (!isImpostorRevealed) {
          return "🔓 Revelar Quién Era el Impostor";
        }
        return "➡️ Nueva Partida de Impostor 🕵️";
      case 'fakeit':
        if (fakeItCountdownVal > 0 && !isFakeItCounting && !isImpostorRevealed) {
          return "⏱️ Iniciar Cuenta Atrás (3, 2, 1...)";
        } else if (isFakeItCounting) {
          return "⏳ ¡Preparados! (${fakeItCountdownVal > 0 ? fakeItCountdownVal : '¡YA!'})";
        } else if (!isImpostorRevealed) {
          return "🔓 Revelar Quién Era el Camaleón";
        }
        return "➡️ Siguiente Acción 🎭";
      case 'hotpotato':
        if (!_bombExploded) {
          return "💣 ¡Bomba en Juego! Pásala rápido";
        }
        return "➡️ Nueva Ronda de Bomba 💣";
      default:
        return "Continuar";
    }
  }

  IconData _getMainActionButtonIcon() {
    switch (activeGame) {
      case 'vote':
        return isVoteFinalized ? Icons.arrow_forward_rounded : Icons.stop_circle_rounded;
      case 'binary':
        return isVoteFinalized ? Icons.arrow_forward_rounded : Icons.stop_circle_rounded;
      case 'undercover':
        return isImpostorRevealed ? Icons.replay_rounded : Icons.visibility_rounded;
      case 'fakeit':
        if (fakeItCountdownVal > 0 && !isFakeItCounting && !isImpostorRevealed) {
          return Icons.timer_rounded;
        } else if (isFakeItCounting) {
          return Icons.hourglass_bottom_rounded;
        } else if (!isImpostorRevealed) {
          return Icons.visibility_rounded;
        }
        return Icons.arrow_forward_rounded;
      case 'hotpotato':
        return _bombExploded ? Icons.replay_rounded : Icons.local_fire_department_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  Color _getMainActionButtonColor() {
    switch (activeGame) {
      case 'vote':
        if (!isVoteFinalized) {
          return _autoFinalizeTimer != null ? const Color(0xFF00CEC9) : const Color(0xFFE17055);
        }
        return const Color(0xFF6C5CE7);
      case 'binary':
        if (!isVoteFinalized) {
          return _autoFinalizeTimer != null ? const Color(0xFF00CEC9) : const Color(0xFFE17055);
        }
        return const Color(0xFFFF7675);
      case 'undercover':
        return isImpostorRevealed ? const Color(0xFF6C5CE7) : const Color(0xFFD63031);
      case 'fakeit':
        if (fakeItCountdownVal > 0 && !isFakeItCounting && !isImpostorRevealed) {
          return const Color(0xFFE84393);
        } else if (isFakeItCounting) {
          return const Color(0xFFFDCB6E);
        } else if (!isImpostorRevealed) {
          return const Color(0xFFD63031);
        }
        return const Color(0xFFE84393);
      case 'hotpotato':
        return const Color(0xFFD63031);
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  void _handleMainActionButtonPressed() {
    switch (activeGame) {
      case 'vote':
        if (!isVoteFinalized) {
          _finalizeVote();
        } else {
          _startSecretVote();
        }
        break;
      case 'binary':
        if (!isVoteFinalized) {
          _finalizeBinary();
        } else {
          _startBinaryGame();
        }
        break;
      case 'undercover':
        if (!isImpostorRevealed) {
          setState(() {
            isImpostorRevealed = true;
          });
        } else {
          _startUndercover();
        }
        break;
      case 'fakeit':
        if (fakeItCountdownVal > 0 && !isFakeItCounting && !isImpostorRevealed) {
          _startFakeItCountdown();
        } else if (!isFakeItCounting && !isImpostorRevealed) {
          setState(() {
            isImpostorRevealed = true;
          });
        } else if (isImpostorRevealed) {
          _startFakeItLive();
        }
        break;
      case 'hotpotato':
        if (_bombExploded) {
          _startHotPotatoLive();
        }
        break;
    }
  }

  // Resultados de Votación Secreta
  Widget _buildVoteResults() {
    final votesCount = <String, int>{};
    for (var target in currentVotes.values) {
      votesCount[target] = (votesCount[target] ?? 0) + 1;
    }

    final totalVotes = currentVotes.length;
    final totalPlayers = activeParticipants.length;
    final allVoted = totalPlayers > 0 && totalVotes >= totalPlayers;
    final pendingPlayers = activeParticipants
        .where((p) => !currentVotes.containsKey(p.name))
        .map((p) => p.name)
        .toList();

    String? maxVotedName;
    int maxVotedCount = 0;
    votesCount.forEach((name, count) {
      if (count > maxVotedCount) {
        maxVotedCount = count;
        maxVotedName = name;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isVoteFinalized && maxVotedName != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFFD79A8)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
            ),
            child: Row(
              children: [
                const Text("🏆", style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "¡SENTENCIA! $maxVotedName ha sido el más votado ($maxVotedCount votos). ¡Paga castigo!",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_autoFinalizeTimer != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00CEC9).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00CEC9)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF00CEC9))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "⏳ ¡Todos han votado! Revelando automáticamente en $_autoFinalizeCountdown s...",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00CEC9)),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isVoteFinalized
                  ? "🏁 VOTACIÓN FINALIZADA"
                  : allVoted
                      ? "✅ ¡TODOS HAN VOTADO!"
                      : "Votos recibidos: $totalVotes de $totalPlayers",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isVoteFinalized || allVoted ? const Color(0xFF00CEC9) : Colors.white70,
              ),
            ),
            if (!isVoteFinalized && pendingPlayers.isNotEmpty)
              Text("Faltan (${pendingPlayers.length}): ${pendingPlayers.join(', ')}", style: const TextStyle(fontSize: 11, color: Color(0xFFFDCB6E), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: activeParticipants.map((p) {
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
        if (hostParticipates) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2130),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6C5CE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("👑 Tu Voto Secreto (Host):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFFDCB6E))),
                    Text(
                      currentVotes[hostPlayerName] != null ? "✅ Votado: ${currentVotes[hostPlayerName]}" : "Toca a quién votas",
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: activeParticipants.map((p) {
                      final isSelected = currentVotes[hostPlayerName] == p.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          avatar: Text(p.avatar),
                          label: Text(
                            p.name,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00CEC9),
                          backgroundColor: Colors.white10,
                          onSelected: (_) {
                            setState(() {
                              currentVotes[hostPlayerName] = p.name;
                            });
                            _hostService.submitHostVote(p.name, voterName: hostPlayerName);
                            _checkAutoFinalizeVote();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tv_rounded, size: 16, color: Color(0xFF00CEC9)),
                SizedBox(width: 8),
                Text("Modo Presentador: Esperando los votos de tus amigos en sus teléfonos", style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
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

    final totalAnswers = currentBinary.length;
    final totalPlayers = activeParticipants.length;
    final allAnswered = totalPlayers > 0 && totalAnswers >= totalPlayers;
    final guiltyList = currentBinary.entries.where((e) => e.value).map((e) => e.key).toList();
    final pendingPlayers = activeParticipants
        .where((p) => !currentBinary.containsKey(p.name))
        .map((p) => p.name)
        .toList();

    return Column(
      children: [
        if (isVoteFinalized) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: guiltyList.isNotEmpty
                    ? [const Color(0xFFFF7675), const Color(0xFFD63031)]
                    : [const Color(0xFF00B894), const Color(0xFF00CEC9)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
            ),
            child: Row(
              children: [
                Text(guiltyList.isNotEmpty ? "🍻" : "😇", style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    guiltyList.isNotEmpty
                        ? "¡${guiltyList.length} Culpable(s) beben!: ${guiltyList.join(', ')}"
                        : "¡Nadie lo ha hecho! El que propuso la pregunta bebe solo.",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_autoFinalizeTimer != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00CEC9).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00CEC9)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF00CEC9))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "⏳ ¡Todos han respondido! Revelando automáticamente en $_autoFinalizeCountdown s...",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00CEC9)),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7675).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF7675)),
                ),
                child: Column(
                  children: [
                    const Text("¡YO SÍ! (CULPABLES)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF7675))),
                    const SizedBox(height: 6),
                    Text("$yesCount", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFFFF7675))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00B894)),
                ),
                child: Column(
                  children: [
                    const Text("YO NUNCA (INOCENTES)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
                    const SizedBox(height: 6),
                    Text("$noCount", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF00B894))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Detalle de Respuestas:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              isVoteFinalized
                  ? "Finalizado"
                  : allAnswered
                      ? "✅ ¡Todos listos!"
                      : pendingPlayers.isNotEmpty
                          ? "Faltan: ${pendingPlayers.join(', ')}"
                          : "Respondidos: $totalAnswers / $totalPlayers",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: allAnswered || isVoteFinalized ? const Color(0xFF00CEC9) : const Color(0xFFFDCB6E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
        if (hostParticipates) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2130),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6C5CE7)),
            ),
            child: Row(
              children: [
                const Text("👑 Tu Respuesta:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFFDCB6E))),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentBinary[hostPlayerName] == true
                        ? const Color(0xFFFF7675)
                        : Colors.white12,
                    side: currentBinary[hostPlayerName] == true
                        ? const BorderSide(color: Colors.white, width: 2)
                        : BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      currentBinary[hostPlayerName] = true;
                    });
                    _hostService.submitHostBinary("YES", voterName: hostPlayerName);
                    _checkAutoFinalizeBinary();
                  },
                  child: Text(
                    currentBinary[hostPlayerName] == true ? "✅ ¡Yo Sí! 🙋" : "¡Yo Sí! 🙋",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentBinary[hostPlayerName] == false
                        ? const Color(0xFF00B894)
                        : Colors.white12,
                    side: currentBinary[hostPlayerName] == false
                        ? const BorderSide(color: Colors.white, width: 2)
                        : BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      currentBinary[hostPlayerName] = false;
                    });
                    _hostService.submitHostBinary("NO", voterName: hostPlayerName);
                    _checkAutoFinalizeBinary();
                  },
                  child: Text(
                    currentBinary[hostPlayerName] == false ? "✅ Yo Nunca 😇" : "Yo Nunca 😇",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tv_rounded, size: 16, color: Color(0xFF00CEC9)),
                SizedBox(width: 8),
                Text("Modo Presentador: Esperando las respuestas de tus amigos en sus teléfonos", style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Vista Host de El Impostor (El host NO sabe quién es el impostor hasta revelar)
  Widget _buildUndercoverHostView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_rounded, size: 48, color: Color(0xFFFDCB6E)),
        const SizedBox(height: 12),
        const Text(
          "Palabras secretas repartidas a cada móvil.",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Cada jugador dice 1 pista por turnos. ¡Debatid y descubrid al sospechoso!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (hostParticipates) ...[
          GestureDetector(
            onTap: () {
              setState(() {
                isHostRoleRevealed = !isHostRoleRevealed;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C5CE7), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("👑 Tu Rol Secreto (Host): ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFDCB6E))),
                      Icon(isHostRoleRevealed ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF00CEC9)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHostRoleRevealed
                        ? "${currentUndercoverRoles[hostPlayerName]?['word'] ?? 'Desconocido'} (${currentUndercoverRoles[hostPlayerName]?['role']})"
                        : "Toca para ver / ocultar tu palabra",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isHostRoleRevealed ? const Color(0xFF00CEC9) : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tv_rounded, size: 16, color: Color(0xFF00CEC9)),
                SizedBox(width: 8),
                Text("Modo Presentador: Eres el moderador de la ronda", style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (!isImpostorRevealed) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD63031),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            icon: const Icon(Icons.visibility_rounded, color: Colors.white),
            label: const Text(
              "🔓 Revelar Quién Era el Impostor",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () {
              setState(() {
                isImpostorRevealed = true;
              });
            },
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD63031).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD63031), width: 2),
            ),
            child: Column(
              children: [
                const Text("🕵️ ¡EL IMPOSTOR ERA!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFFF7675), letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(
                  impostorPlayer ?? "Desconocido",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  "Civil: $currentUndercoverCivilWord   •   Impostor: $currentUndercoverImpostorWord",
                  style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Vista Host de Fake It (El camaleón) - Con cuenta atrás 3, 2, 1 automática y rol oculto al host
  Widget _buildFakeItHostView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.theater_comedy_rounded, size: 50, color: Color(0xFFE84393)),
        const SizedBox(height: 12),
        const Text(
          "¡Acción repartida a cada móvil!",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          "Pulsa el botón de cuenta atrás para sincronizar a todos los móviles.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 16),

        // Cuenta atrás 3, 2, 1 automática en pantalla
        if (isFakeItCounting) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: fakeItCountdownVal == 0
                    ? [const Color(0xFFE84393), const Color(0xFFFF7675)]
                    : [const Color(0xFF6C5CE7), const Color(0xFF00CEC9)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
            ),
            child: Column(
              children: [
                Text(
                  fakeItCountdownVal > 0 ? "$fakeItCountdownVal" : "💥 ¡¡ACTUAD YA!! 💥",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fakeItCountdownVal > 0 ? 56 : 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (fakeItCountdownVal > 0)
                  const Text("¡Preparad vuestros gestos!", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE84393),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              icon: const Icon(Icons.timer_rounded, size: 24),
              label: const Text("🚀 INICIAR CUENTA ATRÁS (3, 2, 1)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              onPressed: _startFakeItCountdown,
            ),
          ),
        ],
        const SizedBox(height: 16),

        if (hostParticipates) ...[
          GestureDetector(
            onTap: () {
              setState(() {
                isHostRoleRevealed = !isHostRoleRevealed;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE84393).withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE84393), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("👑 Tu Acción Secreta (Host): ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFDCB6E))),
                      Icon(isHostRoleRevealed ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF00CEC9)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHostRoleRevealed
                        ? (hostPlayerName == impostorPlayer
                            ? "🕵️ ¡ERES EL CAMALEÓN! (Imita disimuladamente a los demás)"
                            : "🎭 $currentFakeItAction")
                        : "Toca para ver / ocultar tu acción",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isHostRoleRevealed ? const Color(0xFF00CEC9) : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tv_rounded, size: 16, color: Color(0xFF00CEC9)),
                SizedBox(width: 8),
                Text("Modo Presentador: Pulsa el botón para dar la salida a todos", style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (!isImpostorRevealed) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF7675),
              side: const BorderSide(color: Color(0xFFFF7675)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: const Text("🔓 Revelar Quién Era el Camaleón", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () {
              setState(() {
                isImpostorRevealed = true;
              });
            },
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE84393).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE84393), width: 2),
            ),
            child: Column(
              children: [
                const Text("🎭 ¡EL CAMALEÓN ERA!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFFD79A8), letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(impostorPlayer ?? "Desconocido", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white)),
                const SizedBox(height: 6),
                Text("Acción: $currentFakeItAction", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
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
          if (hostParticipates && currentBombHolder == hostPlayerName) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7675).withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF7675), width: 2),
              ),
              child: Column(
                children: [
                  const Text("🔥 ¡TIENES LA BOMBA EN TU PANTALLA! 🔥", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13)),
                  const Text("Di una palabra rápido y toca a quién pasársela:", style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeParticipants.where((p) => p.name != hostPlayerName).map((p) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        onPressed: () {
                          _hostService.passHostBomb(p.name);
                        },
                        child: Text("👉 Pasársela a ${p.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
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
