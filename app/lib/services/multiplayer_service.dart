import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class ConnectedPlayer {
  final String id;
  final String name;
  final String avatar;
  final dynamic connection; // WebSocket or Peer Connection
  final bool isLocal;

  ConnectedPlayer({
    required this.id,
    required this.name,
    required this.avatar,
    this.connection,
    this.isLocal = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
  };
}

class MultiplayerHostService {
  HttpServer? _server;
  final List<ConnectedPlayer> _players = [];
  final StreamController<List<ConnectedPlayer>> _playersController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _eventsController = StreamController.broadcast();

  String localIp = "127.0.0.1";
  int port = 8080;
  String roomCode = "FEST";
  bool isRunning = false;

  Stream<List<ConnectedPlayer>> get playersStream => _playersController.stream;
  Stream<Map<String, dynamic>> get eventsStream => _eventsController.stream;
  List<ConnectedPlayer> get players => List.unmodifiable(_players);

  // Registro del Host como jugador activo
  void addHostPlayer({required String name, required String avatar}) {
    _players.removeWhere((p) => p.id == 'host');
    _players.insert(0, ConnectedPlayer(
      id: 'host',
      name: name,
      avatar: avatar,
      connection: null,
      isLocal: true,
    ));
    _playersController.add(List.from(_players));
    broadcastLobbyState();
  }

  void removeHostPlayer() {
    _players.removeWhere((p) => p.id == 'host');
    _playersController.add(List.from(_players));
    broadcastLobbyState();
  }

  bool get hasHostPlayer => _players.any((p) => p.id == 'host');

  // Acciones emitidas directamente por el Host en la pantalla principal
  void submitHostVote(String target, {String voterName = 'Host (Tú)'}) {
    _eventsController.add({
      'type': 'vote_received',
      'voterId': 'host',
      'voterName': voterName,
      'target': target,
    });
  }

  void submitHostBinary(String value, {String voterName = 'Host (Tú)'}) {
    _eventsController.add({
      'type': 'binary_received',
      'voterId': 'host',
      'voterName': voterName,
      'value': value == 'YES' || value == 'true',
    });
  }

  void passHostBomb(String toTarget) {
    _eventsController.add({
      'type': 'bomb_passed',
      'from': 'host',
      'to': toTarget,
    });
  }

  // Iniciar servidor local HTTP y WebSocket con fallback de puertos
  Future<void> startLocalServer({int listenPort = 8080}) async {
    await detectLocalIp();
    final portsToTry = [listenPort, 8081, 8082, 8088, 8000];

    for (var p in portsToTry) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        port = p;
        isRunning = true;

        _server!.listen((HttpRequest request) async {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            final socket = await WebSocketTransformer.upgrade(request);
            _handleWebSocket(socket);
          } else {
            _handleHttpRequest(request);
          }
        }, onError: (err) {
          print("Error en HttpServer stream: $err");
        });
        break;
      } catch (e) {
        print("Puerto $p ocupado o inaccesible: $e");
      }
    }

    if (_server == null) {
      isRunning = false;
      print("No se pudo iniciar el servidor local en ningún puerto");
    }
  }

  // Detectar IP WiFi local en la subred
  Future<String> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith("192.168.") ||
              addr.address.startsWith("10.") ||
              addr.address.startsWith("172.")) {
            localIp = addr.address;
            return localIp;
          }
        }
      }
    } catch (e) {
      print("Error obteniendo IP de interfaz: $e");
    }
    return localIp;
  }

  // Servir la Web App embebida desde assets
  Future<void> _handleHttpRequest(HttpRequest request) async {
    final res = request.response;
    res.headers.set('Access-Control-Allow-Origin', '*');

    try {
      if (request.uri.path.endsWith('.png') || request.uri.path.endsWith('.ico')) {
        final bytes = await rootBundle.load('assets/icon/app_icon.png');
        res.headers.contentType = ContentType('image', 'png');
        res.add(bytes.buffer.asUint8List());
      } else {
        final html = await rootBundle.loadString('assets/webapp/index.html');
        res.headers.contentType = ContentType.html;
        res.write(html);
      }
    } catch (e) {
      res.statusCode = HttpStatus.internalServerError;
      res.write("Error cargando recurso Web: $e");
    }
    await res.close();
  }

  // Procesar comunicación WebSocket con cada jugador
  void _handleWebSocket(WebSocket socket) {
    String? playerId;
    String? playerName;

    socket.listen((event) {
      try {
        final data = jsonDecode(event as String);
        final type = data['type'];

        if (type == 'join') {
          String rawName = (data['name'] ?? 'Jugador').toString().trim();
          if (rawName.isEmpty) rawName = 'Jugador';
          if (rawName.length > 15) rawName = rawName.substring(0, 15);
          rawName = rawName.replaceAll(RegExp(r'[<>/\\"]'), '');
          if (rawName.isEmpty) rawName = 'Jugador';

          final avatar = (data['avatar'] ?? '👤').toString();
          playerName = rawName;
          playerId = "${playerName}_${DateTime.now().millisecondsSinceEpoch}";

          final player = ConnectedPlayer(
            id: playerId!,
            name: rawName,
            avatar: avatar,
            connection: socket,
            isLocal: true,
          );

          _players.removeWhere((p) => p.name == rawName);
          _players.add(player);
          _playersController.add(_players);

          // Notificar al nuevo jugador y actualizar estado de sala
          broadcastLobbyState();
          _eventsController.add({'type': 'player_joined', 'player': player});
        } else if (type == 'vote_submitted') {
          _eventsController.add({
            'type': 'vote_received',
            'voterId': playerId,
            'voterName': playerName ?? 'Jugador',
            'target': data['target'],
          });
        } else if (type == 'binary_submitted') {
          _eventsController.add({
            'type': 'binary_received',
            'voterId': playerId,
            'voterName': playerName ?? 'Jugador',
            'value': data['value'],
          });
        } else if (type == 'pass_bomb') {
          _eventsController.add({
            'type': 'bomb_passed',
            'from': playerId,
            'to': data['to'],
          });
        }
      } catch (e) {
        print("Error parseando mensaje WS: $e");
      }
    }, onError: (err) {
      if (playerId != null) {
        _players.removeWhere((p) => p.id == playerId);
        _playersController.add(_players);
        broadcastLobbyState();
        _eventsController.add({'type': 'player_left', 'playerId': playerId});
      }
    }, onDone: () {
      if (playerId != null) {
        _players.removeWhere((p) => p.id == playerId);
        _playersController.add(_players);
        broadcastLobbyState();
        _eventsController.add({'type': 'player_left', 'playerId': playerId});
      }
    });
  }

  // Enviar mensaje a todos los móviles conectados
  void broadcast(Map<String, dynamic> message) {
    final payload = jsonEncode(message);
    for (var player in _players) {
      if (player.connection is WebSocket) {
        final ws = player.connection as WebSocket;
        if (ws.readyState == WebSocket.open) {
          ws.add(payload);
        }
      }
    }
  }

  // Enviar mensaje a un jugador específico
  void sendToPlayer(String playerId, Map<String, dynamic> message) {
    final player = _players.firstWhere((p) => p.id == playerId, orElse: () => _players.first);
    if (player.connection is WebSocket) {
      final ws = player.connection as WebSocket;
      if (ws.readyState == WebSocket.open) {
        ws.add(jsonEncode(message));
      }
    }
  }

  // Acciones de Juego
  void broadcastLobbyState() {
    broadcast({
      'type': 'lobby_state',
      'playerCount': _players.length,
      'players': _players.map((p) => p.toJson()).toList(),
    });
  }

  void broadcastVoteResults({required String winnerName, required int votes, required Map<String, int> counts, required String question}) {
    broadcast({
      'type': 'vote_results',
      'winner': winnerName,
      'votes': votes,
      'counts': counts,
      'question': question,
    });
  }

  void broadcastBinaryResults({required List<String> guilty, required int yesCount, required int noCount, required String prompt}) {
    broadcast({
      'type': 'binary_results',
      'guilty': guilty,
      'yesCount': yesCount,
      'noCount': noCount,
      'prompt': prompt,
    });
  }

  void broadcastCountdown(dynamic value) {
    broadcast({
      'type': 'fakeit_countdown',
      'count': value,
    });
  }

  void startSecretVoting(String question, List<Map<String, String>> options) {
    broadcast({
      'type': 'start_vote',
      'question': question,
      'options': options,
    });
  }

  void distributeUndercoverRoles(Map<String, Map<String, String>> roles) {
    for (var player in _players) {
      final roleInfo = roles[player.name] ?? {'role': 'CIVIL', 'word': 'PLAYA'};
      sendToPlayer(player.id, {
        'type': 'secret_role',
        'role': roleInfo['role'],
        'word': roleInfo['word'],
      });
    }
  }

  void startBinaryPrompt(String prompt) {
    broadcast({
      'type': 'start_binary',
      'text': prompt,
    });
  }

  void startFakeItRound(String action, String impostorName) {
    for (var player in _players) {
      final isImp = player.name == impostorName;
      sendToPlayer(player.id, {
        'type': 'fake_it_prompt',
        'isImpostor': isImp,
        'action': action,
      });
    }
  }

  void updateHotPotato(String category, String currentHolderName) {
    final others = _players.map((p) => p.name).where((n) => n != currentHolderName).toList();
    for (var player in _players) {
      final isHolding = player.name == currentHolderName;
      sendToPlayer(player.id, {
        'type': 'bomb_holding',
        'isHolding': isHolding,
        'category': category,
        'holderName': currentHolderName,
        'others': others,
      });
    }
  }

  void sendPenaltyAlert(String playerName, String reason) {
    final player = _players.firstWhere((p) => p.name == playerName, orElse: () => _players.first);
    sendToPlayer(player.id, {
      'type': 'penalty_alert',
      'reason': reason,
    });
  }

  void resetToLobby() {
    broadcast({'type': 'reset_to_lobby'});
  }

  Future<void> stop() async {
    isRunning = false;
    await _server?.close(force: true);
    _players.clear();
    _playersController.add(_players);
  }
}
