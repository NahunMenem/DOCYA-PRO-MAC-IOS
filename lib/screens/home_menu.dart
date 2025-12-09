import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inicio_screen.dart';
import 'historial_screen.dart';
import 'consultas_en_curso_screen.dart';
import 'perfil_screen.dart';
import 'MedicoEnCasaScreen.dart';

// ⭐ IMPORTAR SNACKBAR
import '../widgets/docya_snackbar.dart';

class HomeMenu extends StatefulWidget {
  final String userId;
  final String nombreUsuario;

  const HomeMenu({
    super.key,
    required this.userId,
    required this.nombreUsuario,
  });

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  int _selectedIndex = 0;

  // Estado actual de consulta activa
  Map<String, dynamic>? _consultaActiva;

  // 📌 Estado de disponibilidad (lo leemos de SharedPreferences)
  bool disponible = false;

  // =====================================================
  // 🔥 Chequear disponibilidad antes de navegar
  // =====================================================
  Future<bool> _estaDisponible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("disponible") ?? false;
  }

  void _bloquearNavegacion() {
    DocYaSnackbar.show(
      context,
      title: "⚠️ Modo disponible activado",
      message: "Ponete en NO disponible para navegar por la app.",
      type: SnackType.warning,
    );
  }

  void _setConsultaActiva(Map<String, dynamic>? consulta) {
    setState(() => _consultaActiva = consulta);
  }

  List<Widget> _screens() {
    return [
      InicioScreen(
        userId: widget.userId,
        onAceptarConsulta: _setConsultaActiva,
      ),
      HistorialScreen(medicoId: int.parse(widget.userId)),
      _consultaActiva != null
          ? MedicoEnCasaScreen(
              tipo: "medico",
              consultaId: _consultaActiva!["id"],
              medicoId: _consultaActiva!["medico_id"] ??
                  int.parse(widget.userId),
              pacienteUuid: _consultaActiva!["paciente_uuid"],
              pacienteNombre:
                  _consultaActiva!["paciente_nombre"] ?? "Paciente",
              direccion: _consultaActiva!["direccion"],
              telefono:
                  _consultaActiva!["telefono"] ?? "Sin número",
              motivo: _consultaActiva!["motivo"],
              lat: _consultaActiva!["lat"] ?? 0.0,
              lng: _consultaActiva!["lng"] ?? 0.0,
              onFinalizar: () => _setConsultaActiva(null),
            )
          : const ConsultasEnCursoScreen(),
      PerfilScreen(
        nombreUsuario: widget.nombreUsuario,
        medicoId: widget.userId,
      ),
    ];
  }

  // =====================================================
  // 🟩 Control de navegación
  // =====================================================
  Future<void> _onItemTapped(int index) async {
    final activo = await _estaDisponible();

    // Si está disponible → bloquear todo excepto la pantalla 0 (Inicio)
    if (activo && index != 0) {
      _bloquearNavegacion();
      return;
    }

    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens();

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: const Color(0xFF14B8A6),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Consultas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'En curso',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
