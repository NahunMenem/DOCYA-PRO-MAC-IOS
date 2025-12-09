import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:docya_pro/theme/docya_theme.dart';
import 'screens/splash_pro.dart';

// 📌 Pantalla de login principal
import 'screens/login_screen_pro.dart';
// 📌 Modal de consultas entrantes
import 'widgets/consulta_entrante_modal.dart';
// 📌 Chat de médico
import 'screens/chat_medico_screen.dart';

// 👇 Clave global para acceder al Navigator desde cualquier parte
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔔 Handler para notificaciones en segundo plano
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📩 Notificación en background: ${message.messageId}");
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DocYaApp());

  // 🔥 Inicializamos Firebase/FCM después del runApp
  _initFirebase();
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();

    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Inicializar notificaciones
    await NotificationService.init();
  } catch (e) {
    debugPrint("❌ Error inicializando Firebase: $e");
  }
}

class DocYaApp extends StatelessWidget {
  const DocYaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocYa Pro',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // 👈 permite abrir modales o pantallas desde notificaciones
      theme: DocYaTheme.light, // 🌞 Tema claro DocYa
      darkTheme: DocYaTheme.dark, // 🌙 Tema oscuro DocYa Pro
      themeMode: ThemeMode.dark, // 👈 usamos modo oscuro por defecto
      home: const SplashPro(),
    );
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Inicializa la configuración de notificaciones y listeners FCM
  static Future<void> init() async {
    // Solicitar permisos (solo iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint("🔔 Permisos notificaciones: ${settings.authorizationStatus}");

    // Obtener token FCM
    String? token = await _messaging.getToken();
    debugPrint("🔑 Token FCM: $token");

    // TODO: enviar este token a tu backend
    // await api.guardarTokenMedico(token);

    // 🔹 Listener para notificaciones en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📨 Notificación foreground: ${message.data}");

      if (message.data["tipo"] == "consulta_nueva") {
        final profesionalId =
            message.data["medico_id"] ?? message.data["enfermero_id"];
        if (profesionalId != null && navigatorKey.currentContext != null) {
          mostrarConsultaEntrante(
            navigatorKey.currentContext!,
            profesionalId.toString(),
          );
        }
      }

      // 💬 Nuevo mensaje de chat
      if (message.data["tipo"] == "nuevo_mensaje") {
        final consultaId = int.tryParse(message.data["consulta_id"] ?? "0");
        final remitenteId = message.data["remitente_id"] ?? "";
        if (consultaId != null && consultaId > 0) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text("💬 Nuevo mensaje en consulta $consultaId"),
            ),
          );

          // 👉 Si querés abrir el chat directamente al recibirlo en foreground:
          // navigatorKey.currentState!.push(MaterialPageRoute(
          //   builder: (_) => ChatMedicoScreen(
          //     consultaId: consultaId,
          //     medicoId: int.tryParse(remitenteId) ?? 0,
          //     nombreMedico: "Dr. $remitenteId",
          //   ),
          // ));
        }
      }
    });

    // 🔹 Listener cuando la app está en background y se abre por una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data["tipo"] == "nuevo_mensaje") {
        final consultaId = int.tryParse(message.data["consulta_id"] ?? "0");
        final remitenteId = message.data["remitente_id"] ?? "";
        if (consultaId != null && consultaId > 0) {
          navigatorKey.currentState!.push(MaterialPageRoute(
            builder: (_) => ChatMedicoScreen(
              consultaId: consultaId,
              medicoId: int.tryParse(remitenteId) ?? 0,
              nombreMedico: "Dr. $remitenteId",
            ),
          ));
        }
      }
    });
  }
}
