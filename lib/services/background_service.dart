// ==================================================
// 📌 DOCYA PRO – BACKGROUND SERVICE COMPLETO Y CORREGIDO
// ==================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart'; // NECESARIO para WidgetsFlutterBinding
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/local_notifications.dart';

// ==================================================
// 🚀 BACKGROUND ENTRY POINT
// ==================================================
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized(); // CORRECTO

  String? medicoId;
  WebSocketChannel? channel;

  //---------------------------------------------------------
  // RECIBE EL USER ID ENVIADO DESDE InicioScreen
  //---------------------------------------------------------
  service.on("setUserId").listen((data) {
    medicoId = data?["userId"];
    print("👤 [BG] Médico asignado → $medicoId");

    if (medicoId != null) {
      _conectarWebSocket(service, medicoId!, (ch) {
        channel = ch;
      });
    }
  });

  //---------------------------------------------------------
  // UBICACIÓN CADA 20 SEGUNDOS
  //---------------------------------------------------------
  Timer.periodic(const Duration(seconds: 20), (timer) async {
    if (medicoId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final disponible = prefs.getBool("disponible") ?? false;

    if (!disponible) return;

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print("❌ [BG] Error obteniendo ubicación: $e");
      return;
    }

    try {
      await http.post(
        Uri.parse(
            "https://docya-railway-production.up.railway.app/medico/$medicoId/ubicacion"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"lat": pos.latitude, "lng": pos.longitude}),
      );
      print("📡 [BG] Ubicación enviada");
    } catch (e) {
      print("❌ [BG] Error enviando ubicación: $e");
    }
  });

  //---------------------------------------------------------
  // STOP SERVICE
  //---------------------------------------------------------
  service.on("stopService").listen((event) {
    print("🛑 [BG] Servicio detenido manualmente");
    channel?.sink.close();
    service.stopSelf();
  });
}

// ==================================================
// 🔌 FUNCIÓN PARA CONECTAR WEBSOCKET (RECONEXIÓN AUTOMÁTICA)
// ==================================================
void _conectarWebSocket(
  ServiceInstance service,
  String medicoId,
  Function(WebSocketChannel) assignChannel,
) {
  final url =
      "wss://docya-railway-production.up.railway.app/ws/medico/$medicoId";

  print("🔌 [BG] Conectando WebSocket → $url");

  WebSocketChannel channel;

  try {
    channel = IOWebSocketChannel.connect(
      Uri.parse(url),
      pingInterval: const Duration(seconds: 20),
    );

    assignChannel(channel);

    channel.stream.listen(
      (event) async {
        if (event == "pong") return;

        print("📩 [BG] Evento WS → $event");

        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(event);
        } catch (_) {}

        if (data["tipo"] == "consulta_nueva") {
          print("🔥 [BG] CONSULTA NUEVA RECIBIDA");

          // enviar a UI
          service.invoke("consulta_nueva", data);

          // notificación local
          LocalNotification.show(
            title: "📢 Nueva consulta",
            body: "Tenés una consulta entrante",
          );
        }
      },
      onError: (err) {
        print("⚠️ [BG] Error WS → reconectando: $err");
        Future.delayed(
          const Duration(seconds: 3),
          () => _conectarWebSocket(service, medicoId, assignChannel),
        );
      },
      onDone: () {
        print("❌ [BG] WS cerrado → reconectando...");
        Future.delayed(
          const Duration(seconds: 3),
          () => _conectarWebSocket(service, medicoId, assignChannel),
        );
      },
    );
  } catch (e) {
    print("❌ [BG] Error conectando WS: $e");
    Future.delayed(
      const Duration(seconds: 3),
      () => _conectarWebSocket(service, medicoId, assignChannel),
    );
  }
}
