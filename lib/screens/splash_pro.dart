import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../globals.dart';
import '../widgets/force_update_dialog.dart';
import 'login_screen_pro.dart';

class SplashPro extends StatefulWidget {
  const SplashPro({super.key});

  @override
  State<SplashPro> createState() => _SplashProState();
}

class _SplashProState extends State<SplashPro> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      String version = info.version.trim();

      // Normalizar versión: "1.0" → "1.0.0"
      final parts = version.split('.');
      if (parts.length == 2) {
        version = "${parts[0]}.${parts[1]}.0";
      }

      print("⚕️ DocYaPro versión detectada: $version");

      final url = "$API_URL/app/check_update?version=$version&app=pro";

      final r = await http.get(Uri.parse(url));

      if (r.statusCode != 200) {
        _goToLogin();
        return;
      }

      final data = json.decode(r.body);

      if (data["force_update"] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ForceUpdateDialog(
            mensaje: data["mensaje"],
            urlAndroid: data["url_android"],
            urlIos: data["url_ios"],
          ),
        );
      } else {
        _goToLogin();
      }
    } catch (e) {
      print("❌ Error check_update_pro: $e");
      _goToLogin();
    }
  }

  void _goToLogin() {
    Future.delayed(const Duration(milliseconds: 400), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreenPro()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
