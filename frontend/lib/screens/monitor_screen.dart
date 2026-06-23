import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/live_pulse_indicator.dart';
import 'monitor/clima_tab.dart';
import 'monitor/ia_tab.dart';
import 'monitor/camera_tab.dart';
import 'monitor/control_tab.dart';
import 'settings_screen.dart';

/// Pantalla Principal del Monitor que contiene la estructura general de pestañas:
/// ClimaTab (Historial y datos de clima), IATab (Diagnósticos) y CameraTab (Cámara IA).
class MonitorScreen extends StatefulWidget {
  final String loteId;
  final String userRole;

  const MonitorScreen({
    super.key,
    required this.loteId,
    required this.userRole,
  });

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late final DatabaseReference _actualRef;
  late final DatabaseReference _iaRef;
  late final DatabaseReference _configRef;
  late final DatabaseReference _sensoresRef;

  @override
  void initState() {
    super.initState();
    _actualRef = FirebaseDatabase.instance.ref(
      'lotes/${widget.loteId}/monitoreo_actual',
    );
    _iaRef = FirebaseDatabase.instance.ref(
      'lotes/${widget.loteId}/historial_ia_fotos',
    );
    _configRef = FirebaseDatabase.instance.ref(
      'lotes/${widget.loteId}/configuracion',
    );
    _sensoresRef = FirebaseDatabase.instance.ref(
      'lotes/${widget.loteId}/sensores',
    );
    debugPrint("[MonitorScreen] Inicializado para lote: ${widget.loteId}.");
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        appBar: AppBar(
          centerTitle: false,
          elevation: 0,
          backgroundColor: const Color(0xFF090D16), // Dark Slate-black
          title: Row(
            children: [
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _configRef.child('nombre_lote').onValue,
                  builder: (context, snapshot) {
                    String displayName = widget.loteId;
                    if (snapshot.hasData &&
                        snapshot.data!.snapshot.value != null) {
                      displayName = snapshot.data!.snapshot.value.toString();
                    }
                    return Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LivePulseIndicator(),
                    SizedBox(width: 6),
                    Text(
                      'EN VIVO',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Configuración / Perfil',
              icon: const Icon(
                Icons.account_circle_outlined,
                color: Colors.white70,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF10B981), // Emerald
            unselectedLabelColor: Colors.white60,
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(icon: Icon(Icons.cloud_outlined), text: "Clima"),
              Tab(
                icon: Icon(Icons.psychology_outlined),
                text: "Diagnóstico IA",
              ),
              Tab(icon: Icon(Icons.camera_alt_outlined), text: "Cámara"),
              Tab(icon: Icon(Icons.tune_outlined), text: "Control"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ClimaTab(
              actualRef: _actualRef,
              configRef: _configRef,
              sensoresRef: _sensoresRef,
            ),
            IATab(iaRef: _iaRef),
            const CameraTab(),
            ControlTab(configRef: _configRef),
          ],
        ),
      ),
    );
  }
}
