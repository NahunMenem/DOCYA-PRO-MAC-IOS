// ==========================================================
// DOCYA PRO – MAIN FINAL (MÉDICOS / ENFERMEROS)
// Notificaciones + Sonido + Modal Consulta Entrante
// iOS + Android 100% compatible
// ==========================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:docya_pro/theme/docya_theme.dart';

import 'screens/splash_pro.dart';
import 'screens/login_screen_pro.dart';
import 'screens/chat_medico_screen.dart';

// MODAL consulta entrante
import 'widgets/consulta_entrante_modal.dart';

// Navegación global
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ==========================================================
// 🔥 BACKGROUND HANDLER
// ==========================================================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📩 Background push: ${message.data}");

  if (message.data["tipo"] == "consulta_nueva") {
    await _mostrarNotificacionLocalConsulta();
  }

  if (message.data["tipo"] == "nuevo_mensaje") {
    await _mostrarNotificacionLocalChat(
      message.data["mensaje"] ?? "",
    );
  }
}

// ==========================================================
// 🔔 Notificación Local para consulta entrante
// ==========================================================
Future<void> _mostrarNotificacionLocalConsulta() async {
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    "Nueva consulta entrante",
    "Tienes una consulta para aceptar",
    NotificationDetails(
      android: AndroidNotificationDetails(
        'docya_channel',
        'Notificaciones DocYa',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alerta'),
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: "alert.caf",
      ),
    ),
    payload: jsonEncode({"tipo": "consulta"}),
  );
}

// ==========================================================
// 🔔 Notificación Local para chat
// ==========================================================
Future<void> _mostrarNotificacionLocalChat(String mensaje) async {
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    "Nuevo mensaje",
    mensaje,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'docya_channel',
        'Notificaciones DocYa',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alerta'),
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: "alert.caf",
      ),
    ),
    payload: jsonEncode({"tipo": "chat"}),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Canal Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
    const AndroidNotificationChannel(
      'docya_channel',
      'Notificaciones DocYa',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alerta'),
    ),
  );

  // Inicialización de notificaciones locales
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      _onNotificationTap(resp.payload);
    },
  );

  runApp(const DocYaApp());

  // 🚀 Después del runApp inicializamos FCM
  NotificationService.init();
}

// ==========================================================
// TAP de notificación
// ==========================================================
void _onNotificationTap(String? payload) {
  if (payload == null) return;

  final data = jsonDecode(payload);

  if (data["tipo"] == "chat") {
    // Abrir chat si querés
  }
}

// ==========================================================
// APP PRINCIPAL
// ==========================================================
class DocYaApp extends StatelessWidget {
  const DocYaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocYa Pro',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: DocYaTheme.light,
      darkTheme: DocYaTheme.dark,
      themeMode: ThemeMode.dark,
      home: const SplashPro(),
    );
  }
}

// ==========================================================
// 🔔 NOTIFICATION SERVICE – MÉDICOS
// ==========================================================
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Permisos iOS
    await Permission.notification.request();

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint("🔔 Permisos: ${settings.authorizationStatus}");

    // Token
    String? token = await _messaging.getToken();
    debugPrint("🔑 FCM Token Médico: $token");

    // ==========================================================
    // 🟢 1) getInitialMessage (APP CERRADA)
    // ==========================================================
    RemoteMessage? initialMsg =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMsg != null) {
      Future.microtask(() {
        _handlePush(initialMsg);
      });
    }

    // ==========================================================
    // 🟢 2) FOREGROUND
    // ==========================================================
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("📨 Foreground: ${message.data}");
      _handlePush(message);
    });

    // ==========================================================
    // 🟢 3) APP EN BACKGROUND → abierta desde notificación
    // ==========================================================
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      Future.microtask(() {
        _handlePush(message);
      });
    });

    // 🔥 iOS — obtener APNS + token real
    await _fixAPNS();
  }

  // ==========================================================
  // HANDLER GENERAL
  // ==========================================================
  static void _handlePush(RemoteMessage message) {
    final data = message.data;

    // CONSULTA ENTRANTE
    if (data["tipo"] == "consulta_nueva") {
      final profesionalId =
          data["medico_id"] ?? data["enfermero_id"];

      if (profesionalId != null && navigatorKey.currentContext != null) {
        mostrarConsultaEntrante(
          navigatorKey.currentContext!,
          profesionalId.toString(),
        );
      }

      _mostrarNotificacionLocalConsulta();
    }

    // CHAT
    if (data["tipo"] == "nuevo_mensaje") {
      final consultaId = int.tryParse(data["consulta_id"] ?? "0");
      final remitenteId = data["remitente_id"] ?? "";

      if (consultaId != null && consultaId > 0) {
        _mostrarNotificacionLocalChat(
          data["mensaje"] ?? "",
        );
      }
    }
  }

  // ==========================================================
  // FIX APNS
  // ==========================================================
  static Future<void> _fixAPNS() async {
    debugPrint("🍏 Esperando APNS…");

    String? apns = await FirebaseMessaging.instance.getAPNSToken();
    int retry = 0;

    while (apns == null && retry < 8) {
      await Future.delayed(const Duration(milliseconds: 500));
      apns = await FirebaseMessaging.instance.getAPNSToken();
      retry++;
    }

    debugPrint("🍏 APNS Token: $apns");
    debugPrint("🔥 FCM Token Final: ${await FirebaseMessaging.instance.getToken()}");
  }
}
