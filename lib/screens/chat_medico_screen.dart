import 'dart:convert';
import 'dart:ui'; // para blur
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatMedicoScreen extends StatefulWidget {
  final int consultaId;
  final int medicoId;
  final String nombreMedico;

  const ChatMedicoScreen({
    super.key,
    required this.consultaId,
    required this.medicoId,
    required this.nombreMedico,
  });

  @override
  State<ChatMedicoScreen> createState() => _ChatMedicoScreenState();
}

class _ChatMedicoScreenState extends State<ChatMedicoScreen> {
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  final List<Map<String, dynamic>> _messages = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();

  bool _showNewMsgIndicator = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _loadHistory();
  }

  // 🎧 reproducir sonido
  Future<void> _playSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
    } catch (e) {
      debugPrint("⚠️ Error al reproducir sonido: $e");
    }
  }

  // 🔔 vibrar
  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 200, amplitude: 180);
      }
    } catch (e) {
      debugPrint("⚠️ Error en vibración: $e");
    }
  }

  // 🧠 conectar WebSocket
  void _connectWebSocket() {
    final url =
        "wss://docya-railway-production.up.railway.app/ws/chat/${widget.consultaId}/profesional/${widget.medicoId}";
    debugPrint("👨‍⚕️🔌 Conectando WS a: $url");

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (event) {
        debugPrint("📩 WS recibido: $event");
        try {
          final data = jsonDecode(event);
          if (data is Map<String, dynamic>) {
            setState(() => _messages.add(data));

            // 📱 si el mensaje viene del paciente → vibrar, sonar y mostrar alerta
            if (data["remitente_tipo"] == "paciente") {
              _vibrate();
              _playSound();
              _mostrarNotificacionVisual();
            }

            // autoscroll si está abajo del todo
            if (_scrollController.hasClients &&
                _scrollController.offset >=
                    _scrollController.position.maxScrollExtent - 100) {
              Future.delayed(const Duration(milliseconds: 300), () {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              });
            } else {
              setState(() => _showNewMsgIndicator = true);
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error parseando WS: $e");
        }
      },
      onDone: () {
        debugPrint("🔌 WS cerrado, reintentando en 2s...");
        Future.delayed(const Duration(seconds: 2), _connectWebSocket);
      },
      onError: (err) {
        debugPrint("❌ Error WS: $err");
      },
    );
  }

  Future<void> _loadHistory() async {
    final url =
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/chat";
    debugPrint("🌐 GET historial: $url");

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List history = (decoded is List) ? decoded : [];
      setState(() {
        _messages.addAll(history.cast<Map<String, dynamic>>());
      });
      // autoscroll inicial
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent);
        }
      });
    } else {
      debugPrint("⚠️ Error cargando historial: ${response.statusCode}");
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty || _channel == null) return;
    final msg = {"mensaje": _controller.text.trim()};
    debugPrint("👨‍⚕️📤 Enviando mensaje: $msg");
    _channel!.sink.add(jsonEncode(msg));
    _controller.clear();

    _vibrate(); // feedback al enviar
    _playSound();
  }

  void _mostrarNotificacionVisual() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF14B8A6).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        content: const Text(
          "💬 Nuevo mensaje del paciente",
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Chat con ${widget.nombreMedico}",
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final maxWidth = isWide ? 600.0 : double.infinity;

            return Center(
              child: Container(
                width: maxWidth,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMine =
                              msg["remitente_tipo"] == "profesional" &&
                              msg["remitente_id"].toString() ==
                                  widget.medicoId.toString();

                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                  maxWidth: screenWidth * 0.75),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 14),
                              margin:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFF14B8A6)
                                        .withOpacity(0.9)
                                    : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                msg["mensaje"] ?? "",
                                style: TextStyle(
                                  color:
                                      isMine ? Colors.white : Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_showNewMsgIndicator)
                      GestureDetector(
                        onTap: () {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                          );
                          setState(() => _showNewMsgIndicator = false);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "⬇️ Nuevo mensaje",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    const Divider(color: Colors.white24, height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  color: Colors.white.withOpacity(0.15),
                                  child: TextField(
                                    controller: _controller,
                                    style:
                                        const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: "Escribe un mensaje...",
                                      hintStyle:
                                          TextStyle(color: Colors.white54),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send,
                                color: Color(0xFF14B8A6)),
                            onPressed: _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
