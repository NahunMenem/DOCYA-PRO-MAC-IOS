// ==========================================================
// DOCYA PRO – MAIN FINAL (iOS + Android)
// Notificaciones, Sonido, Background Service, Modal Consulta
// ==========================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// 🔥 IMPORTS NUEVOS (FALTABAN)
import 'services/background_service.dart';
import 'utils/local_notifications.dart';

import 'package:docya_pro/theme/docya_theme.dart';

import 'screens/splash_pro.dart';
import 'screens/login_screen_pro.dart';
import 'screens/chat_medico_screen.dart';
import 'widgets/consulta_entrante_modal.dart';

// Navegación global
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();


// ==========================================================
// 🔥 BACKGROUND HANDLER (FCM)
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


// ==========================================================
// 🚀 MAIN
// ==========================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Inicialización que FALTABA
  await LocalNotification.init();     // <---- NECESARIO EN iOS Y ANDROID
  await initializeService();          // <---- Inicializa FlutterBackgroundService

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Crear canal Android
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

  // Inicializar notificaciones locales
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

  // 🔥 Inicializar FCM después del runApp
  NotificationService.init();
}


// ==========================================================
// TAP DE NOTIFICACIÓN
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
// 🔔 NOTIFICATION SERVICE – iOS + ANDROID
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

    // APP CERRADA
    RemoteMessage? initialMsg =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMsg != null) {
      Future.microtask(() {
        _handlePush(initialMsg);
      });
    }

    // FOREGROUND
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("📨 Foreground: ${message.data}");
      _handlePush(message);
    });

    // BACKGROUND → abierta desde notificación
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      Future.microtask(() {
        _handlePush(message);
      });
    });

    // iOS
    await _fixAPNS();
  }


  static void _handlePush(RemoteMessage message) {
    final data = message.data;

    // CONSULTA ENTRANTE
    if (data["tipo"] == "consulta_nueva") {
    // 🔥 INICIAR EL TIMER REAL APENAS LLEGA LA NOTIFICACIÓN
      iniciarTimerConsultaGlobal();
      final profesionalId = data["medico_id"] ?? data["enfermero_id"];

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
      _mostrarNotificacionLocalChat(data["mensaje"] ?? "");
    }
  }

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
