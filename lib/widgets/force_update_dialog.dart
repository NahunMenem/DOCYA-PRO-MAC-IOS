import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String mensaje;
  final String urlAndroid;
  final String urlIos;

  const ForceUpdateDialog({
    super.key,
    required this.mensaje,
    required this.urlAndroid,
    required this.urlIos,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black87,
      title: const Text(
        "Actualización requerida",
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        mensaje,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            launchUrl(
              Uri.parse(urlAndroid),
              mode: LaunchMode.externalApplication,
            );
          },
          child: const Text("Actualizar"),
        ),
      ],
    );
  }
}
