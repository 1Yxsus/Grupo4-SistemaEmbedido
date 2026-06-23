import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/custom_modal.dart';
import 'monitor_screen.dart';
import 'settings_screen.dart';

class LoteSelectionScreen extends StatefulWidget {
  const LoteSelectionScreen({super.key});

  @override
  State<LoteSelectionScreen> createState() => _LoteSelectionScreenState();
}

class _LoteSelectionScreenState extends State<LoteSelectionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String _userName = 'Usuario';
  String _userRole = 'Almacenero';
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final snapshot = await _dbRef.child('usuarios').child(user.uid).get();
        if (snapshot.exists) {
          final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
          if (mounted) {
            setState(() {
              _userRole = data['rol']?.toString() ?? 'Almacenero';
              _userName = data['nombre']?.toString() ?? 'Usuario';
              _isLoadingUser = false;
            });
          }
        } else {
          // Si no existe, crear perfil bÃ¡sico para evitar bucles
          await _dbRef.child('usuarios').child(user.uid).set({
            'nombre': user.displayName ?? 'Usuario',
            'correo': user.email ?? '',
            'fecha_registro': ServerValue.timestamp,
            'rol': 'Almacenero',
          });
          if (mounted) {
            setState(() {
              _userRole = 'Almacenero';
              _userName = user.displayName ?? 'Usuario';
              _isLoadingUser = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _userRole = 'Almacenero';
            _isLoadingUser = false;
          });
        }
      }
    }
  }

  // Diálogo para Agregar Lote (Solo Admin)
  void _mostrarAgregarLoteDialog() {
    final formKey = GlobalKey<FormState>();
    final keyController = TextEditingController();
    final nameController = TextEditingController();
    final camController = TextEditingController();
    final tempController = TextEditingController(text: '27.0');
    final humController = TextEditingController(text: '70.0');

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return CustomModal(
              title: 'Agregar Nuevo Lote',
              icon: Icons.add_business_rounded,
              confirmLabel: 'AGREGAR',
              isLoading: isLoading,
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: keyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'ID del Lote (Ej: Lote_Alpha)',
                        labelStyle: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.tag_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nombre del Lote',
                        labelStyle: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.label_outline_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: camController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'ID Cámara ESP32',
                        labelStyle: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.videocam_outlined,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tempController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Temp. (°C)',
                              labelStyle: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF10B981),
                                  width: 1.5,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.thermostat_outlined,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                            ),
                            validator: (val) =>
                                double.tryParse(val ?? '') == null
                                ? 'Número'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: humController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Humedad (%)',
                              labelStyle: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF10B981),
                                  width: 1.5,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.water_drop_outlined,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                            ),
                            validator: (val) =>
                                double.tryParse(val ?? '') == null
                                ? 'Número'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              onConfirm: () async {
                if (formKey.currentState!.validate()) {
                  setModalState(() {
                    isLoading = true;
                  });
                  try {
                    final key = keyController.text.trim().replaceAll(' ', '_');
                    final name = nameController.text.trim();
                    final cam = camController.text.trim();
                    final temp = double.parse(tempController.text);
                    final hum = double.parse(humController.text);

                    // Verificar si existe
                    final checkSnapshot = await _dbRef
                        .child('lotes')
                        .child(key)
                        .get();
                    if (checkSnapshot.exists) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('El ID del lote ya existe.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      setModalState(() {
                        isLoading = false;
                      });
                      return;
                    }

                    // Escribir estructura de lote
                    await _dbRef.child('lotes').child(key).set({
                      'configuracion': {
                        'id_espcam': cam,
                        'modo_ventilador': 'AUTO',
                        'nombre_lote': name,
                        'umbral_humedad': hum,
                        'umbral_temperatura': temp,
                      },
                      'monitoreo_actual': {
                        'humedad_promedio': 0.0,
                        'temperatura_promedio': 0.0,
                        'ventilador_estado': false,
                        'ultima_actualizacion': 'N/A',
                      },
                      'historial_ia_fotos': {
                        'placeholder': {'placeholder': true},
                      },
                      'sensores': {
                        'placeholder': {'placeholder': true},
                      },
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lote agregado exitosamente.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    setModalState(() {
                      isLoading = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  // Eliminar Lote (Solo Admin)
  Future<void> _eliminarLote(String loteId, String loteNombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Eliminar Lote',
        icon: Icons.delete_forever_rounded,
        iconColor: Colors.redAccent,
        confirmLabel: 'ELIMINAR',
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente el lote "$loteNombre" junto con todos sus sensores e historial?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (confirm == true) {
      await _dbRef.child('lotes').child(loteId).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lote "$loteNombre" eliminado.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  // Abre la pantalla de ConfiguraciÃ³n de Lote y Sensores
  void _mostrarConfigurarLote(String loteId, Map<dynamic, dynamic> loteData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LoteManagementScreen(loteId: loteId, initialData: loteData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'RipnessAI - Lotes',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF090D16),
        actions: [
          IconButton(
            tooltip: 'ConfiguraciÃ³n / Perfil',
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingUser
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta de bienvenida premium
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _userRole == 'Owner'
                                  ? const Color(0xFFF97316)
                                  : (_userRole == 'Administrador'
                                        ? Colors.purpleAccent
                                        : const Color(0xFF10B981)),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_userRole == 'Owner'
                                            ? const Color(0xFFF97316)
                                            : (_userRole == 'Administrador'
                                                  ? Colors.purpleAccent
                                                  : const Color(0xFF10B981)))
                                        .withValues(alpha: 0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF0F172A),
                            child: Icon(
                              _userRole == 'Owner'
                                  ? Icons.star_rounded
                                  : (_userRole == 'Administrador'
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.person_rounded),
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Hola, $_userName!',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_userRole == 'Owner'
                                              ? const Color(0xFFF97316)
                                              : (_userRole == 'Administrador'
                                                    ? Colors.purpleAccent
                                                    : const Color(0xFF10B981)))
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _userRole.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _userRole == 'Owner'
                                        ? const Color(0xFFF97316)
                                        : (_userRole == 'Administrador'
                                              ? const Color(0xFFD8B4FE)
                                              : const Color(0xFF34D399)),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Selecciona el Lote de monitoreo:',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stream de Lotes
                  Expanded(
                    child: StreamBuilder<DatabaseEvent>(
                      stream: _dbRef.child('lotes').onValue,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF10B981),
                            ),
                          );
                        }
                        if (!snapshot.hasData ||
                            snapshot.data!.snapshot.value == null) {
                          return const Center(
                            child: Text(
                              'No hay lotes registrados en la base de datos.',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        try {
                          final dataMap = Map<dynamic, dynamic>.from(
                            snapshot.data!.snapshot.value as Map,
                          );
                          final lotesList = dataMap.entries.toList();

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: lotesList.length,
                            itemBuilder: (context, index) {
                              final entry = lotesList[index];
                              final loteId = entry.key.toString();
                              final loteMap = Map<dynamic, dynamic>.from(
                                entry.value as Map,
                              );

                              final config = Map<dynamic, dynamic>.from(
                                loteMap['configuracion'] as Map? ?? {},
                              );
                              final monitoreo = Map<dynamic, dynamic>.from(
                                loteMap['monitoreo_actual'] as Map? ?? {},
                              );

                              final nombreLote =
                                  config['nombre_lote']?.toString() ?? loteId;
                              final camId =
                                  config['id_espcam']?.toString() ?? 'N/A';

                              final tempProm =
                                  (monitoreo['temperatura_promedio'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              final humProm =
                                  (monitoreo['humedad_promedio'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              final vent =
                                  monitoreo['ventilador_estado'] ?? false;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.04),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 6,
                                          color: const Color(
                                            0xFF10B981,
                                          ), // Emerald indicator bar
                                        ),
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topRight: Radius.circular(
                                                      20,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(20),
                                                  ),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        MonitorScreen(
                                                          loteId: loteId,
                                                          userRole: _userRole,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  18.0,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                nombreLote,
                                                                style: const TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                  letterSpacing:
                                                                      0.2,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 6,
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .videocam_rounded,
                                                                    color: Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.35,
                                                                        ),
                                                                    size: 14,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    'Cámara: $camId',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .white
                                                                          .withValues(
                                                                            alpha:
                                                                                0.5,
                                                                          ),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (_userRole ==
                                                                'Administrador' ||
                                                            _userRole ==
                                                                'Owner') ...[
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .settings_suggest_rounded,
                                                                  color: Color(
                                                                    0xFF10B981,
                                                                  ),
                                                                  size: 20,
                                                                ),
                                                                tooltip:
                                                                    'Configurar Lote',
                                                                style: IconButton.styleFrom(
                                                                  backgroundColor:
                                                                      const Color(
                                                                        0xFF10B981,
                                                                      ).withValues(
                                                                        alpha:
                                                                            0.08,
                                                                      ),
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        8,
                                                                      ),
                                                                ),
                                                                onPressed: () =>
                                                                    _mostrarConfigurarLote(
                                                                      loteId,
                                                                      loteMap,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .delete_outline_rounded,
                                                                  color: Colors
                                                                      .redAccent,
                                                                  size: 20,
                                                                ),
                                                                tooltip:
                                                                    'Eliminar Lote',
                                                                style: IconButton.styleFrom(
                                                                  backgroundColor: Colors
                                                                      .redAccent
                                                                      .withValues(
                                                                        alpha:
                                                                            0.08,
                                                                      ),
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        8,
                                                                      ),
                                                                ),
                                                                onPressed: () =>
                                                                    _eliminarLote(
                                                                      loteId,
                                                                      nombreLote,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const Divider(
                                                      height: 28,
                                                      color: Colors.white10,
                                                    ),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        _buildConditionMiniCard(
                                                          Icons
                                                              .thermostat_rounded,
                                                          '${tempProm.toStringAsFixed(1)}°C',
                                                          Colors.orangeAccent,
                                                        ),
                                                        _buildConditionMiniCard(
                                                          Icons
                                                              .water_drop_rounded,
                                                          '${humProm.toStringAsFixed(1)}%',
                                                          Colors
                                                              .lightBlueAccent,
                                                        ),
                                                        _buildConditionMiniCard(
                                                          Icons.air_rounded,
                                                          vent
                                                              ? 'ACTIVO'
                                                              : 'APAGADO',
                                                          vent
                                                              ? const Color(
                                                                  0xFF10B981,
                                                                )
                                                              : Colors
                                                                    .redAccent,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        } catch (e) {
                          return Center(
                            child: Text(
                              'Error al procesar lotes: $e',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _userRole == 'Administrador' || _userRole == 'Owner'
          ? FloatingActionButton(
              onPressed: _mostrarAgregarLoteDialog,
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildConditionMiniCard(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Pantalla para que el Administrador configure el Lote y Gestione Sensores
class LoteManagementScreen extends StatefulWidget {
  final String loteId;
  final Map<dynamic, dynamic> initialData;

  const LoteManagementScreen({
    super.key,
    required this.loteId,
    required this.initialData,
  });

  @override
  State<LoteManagementScreen> createState() => _LoteManagementScreenState();
}

class _LoteManagementScreenState extends State<LoteManagementScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final _formKey = GlobalKey<FormState>();
  bool _isSavingConfig = false;

  late TextEditingController _nameController;
  late TextEditingController _camController;
  late TextEditingController _tempController;
  late TextEditingController _humController;

  @override
  void initState() {
    super.initState();
    final config = Map<dynamic, dynamic>.from(
      widget.initialData['configuracion'] as Map? ?? {},
    );
    _nameController = TextEditingController(
      text: config['nombre_lote']?.toString() ?? widget.loteId,
    );
    _camController = TextEditingController(
      text: config['id_espcam']?.toString() ?? '',
    );
    _tempController = TextEditingController(
      text: (config['umbral_temperatura'] ?? 27.0).toString(),
    );
    _humController = TextEditingController(
      text: (config['umbral_humidity'] ?? config['umbral_humedad'] ?? 70.0)
          .toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _camController.dispose();
    _tempController.dispose();
    _humController.dispose();
    super.dispose();
  }

  Future<void> _guardarConfiguracionLote() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSavingConfig = true;
      });
      try {
        await _dbRef
            .child('lotes')
            .child(widget.loteId)
            .child('configuracion')
            .update({
              'nombre_lote': _nameController.text.trim(),
              'id_espcam': _camController.text.trim(),
              'umbral_temperatura': double.parse(_tempController.text),
              'umbral_humedad': double.parse(_humController.text),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lote actualizado con éxito.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSavingConfig = false;
          });
        }
      }
    }
  }

  // Diálogo para Agregar/Editar Sensor
  void _mostrarSensorDialog([
    String? sensorKey,
    Map<dynamic, dynamic>? sensorData,
  ]) {
    final formKey = GlobalKey<FormState>();
    final keyController = TextEditingController(text: sensorKey ?? '');
    final espController = TextEditingController(
      text: sensorData?['esp_id']?.toString() ?? '',
    );
    final tagController = TextEditingController(
      text: sensorData?['etiqueta']?.toString() ?? '',
    );
    final tempController = TextEditingController(
      text: (sensorData?['temperatura'] ?? 25.0).toString(),
    );
    final humController = TextEditingController(
      text: (sensorData?['humedad'] ?? 65.0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return CustomModal(
              title: sensorKey == null
                  ? 'Agregar Nuevo Sensor'
                  : 'Editar Sensor',
              icon: sensorKey == null
                  ? Icons.sensors_rounded
                  : Icons.edit_note_rounded,
              confirmLabel: sensorKey == null ? 'AGREGAR' : 'GUARDAR',
              isLoading: isLoading,
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sensorKey == null) ...[
                      TextFormField(
                        controller: keyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'ID del Sensor (Ej: Sensor_01)',
                          labelStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B981),
                              width: 1.5,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.tag_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: espController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'ID del ESP32 físico (Ej: ESP32_NODE_A1)',
                        labelStyle: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.developer_board_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: tagController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Etiqueta / Ubicación (Ej: Zona Norte)',
                        labelStyle: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.place_outlined,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tempController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Temp. inicial (°C)',
                              labelStyle: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF10B981),
                                  width: 1.5,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.thermostat_outlined,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                            ),
                            validator: (val) =>
                                double.tryParse(val ?? '') == null
                                ? 'Número'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: humController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Hum. inicial (%)',
                              labelStyle: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF10B981),
                                  width: 1.5,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.water_drop_outlined,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                            ),
                            validator: (val) =>
                                double.tryParse(val ?? '') == null
                                ? 'Número'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              onConfirm: () async {
                if (formKey.currentState!.validate()) {
                  setModalState(() {
                    isLoading = true;
                  });
                  try {
                    final key = keyController.text.trim().replaceAll(' ', '_');
                    final esp = espController.text.trim();
                    final tag = tagController.text.trim();
                    final temp = double.parse(tempController.text);
                    final hum = double.parse(humController.text);

                    // Crear/Actualizar sensor
                    await _dbRef
                        .child('lotes')
                        .child(widget.loteId)
                        .child('sensores')
                        .child(key)
                        .set({
                          'esp_id': esp,
                          'etiqueta': tag,
                          'fecha':
                              sensorData?['fecha']?.toString() ??
                              '21/06/26 20:00',
                          'humedad': hum,
                          'temperatura': temp,
                          'historial_sensor':
                              sensorData?['historial_sensor'] ??
                              {
                                'placeholder': {'placeholder': true},
                              },
                        });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sensorKey == null
                                ? 'Sensor agregado.'
                                : 'Sensor actualizado.',
                          ),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    setModalState(() {
                      isLoading = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  // Eliminar Sensor
  Future<void> _eliminarSensor(String sensorId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Eliminar Sensor',
        icon: Icons.delete_forever_rounded,
        iconColor: Colors.redAccent,
        confirmLabel: 'ELIMINAR',
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
        content: Text(
          '¿Deseas eliminar permanentemente el sensor "$sensorId"?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (confirm == true) {
      await _dbRef
          .child('lotes')
          .child(widget.loteId)
          .child('sensores')
          .child(sensorId)
          .remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sensor "$sensorId" eliminado.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: StreamBuilder<DatabaseEvent>(
          stream: _dbRef
              .child('lotes')
              .child(widget.loteId)
              .child('configuracion')
              .child('nombre_lote')
              .onValue,
          builder: (context, snapshot) {
            String displayName = widget.loteId;
            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              displayName = snapshot.data!.snapshot.value.toString();
            } else {
              final config = Map<dynamic, dynamic>.from(
                widget.initialData['configuracion'] as Map? ?? {},
              );
              displayName = config['nombre_lote']?.toString() ?? widget.loteId;
            }
            return Text(
              'Gestionar: $displayName',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
        backgroundColor: const Color(0xFF090D16),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.settings_suggest_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Configuración del Lote',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.white10),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nombre del Lote',
                          labelStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B981),
                              width: 1.5,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.label_outline_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _camController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'ID Cámara ESP32',
                          labelStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B981),
                              width: 1.5,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.videocam_outlined,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tempController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Umbral Temp. (°C)',
                                labelStyle: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF10B981),
                                    width: 1.5,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.thermostat_outlined,
                                  color: Color(0xFF10B981),
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  double.tryParse(val ?? '') == null
                                  ? 'Número'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _humController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Umbral Hum. (%)',
                                labelStyle: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF10B981),
                                    width: 1.5,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.water_drop_outlined,
                                  color: Color(0xFF10B981),
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  double.tryParse(val ?? '') == null
                                  ? 'Número'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isSavingConfig
                            ? null
                            : _guardarConfiguracionLote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isSavingConfig
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.save_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'GUARDAR CONFIGURACIÓN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // GestiÃ³n de Sensores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sensores en este Lote',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _mostrarSensorDialog(),
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF10B981)),
                  label: const Text(
                    'Agregar Sensor',
                    style: TextStyle(color: Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            StreamBuilder<DatabaseEvent>(
              stream: _dbRef
                  .child('lotes')
                  .child(widget.loteId)
                  .child('sensores')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  );
                }
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No hay sensores en este lote.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  );
                }

                try {
                  final sensorsMap = Map<dynamic, dynamic>.from(
                    snapshot.data!.snapshot.value as Map,
                  );
                  sensorsMap.removeWhere((key, value) => key == 'placeholder');

                  if (sensorsMap.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No hay sensores en este lote.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    );
                  }

                  final sensorList = sensorsMap.entries.toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sensorList.length,
                    itemBuilder: (context, index) {
                      final entry = sensorList[index];
                      final sId = entry.key.toString();
                      final sData = Map<dynamic, dynamic>.from(
                        entry.value as Map,
                      );

                      final espId = sData['esp_id']?.toString() ?? 'N/A';
                      final tag = sData['etiqueta']?.toString() ?? 'N/A';
                      final temp =
                          (sData['temperatura'] as num?)?.toDouble() ?? 0.0;
                      final hum = (sData['humedad'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(
                              0xFF34D399,
                            ).withValues(alpha: 0.15),
                            child: const Icon(
                              Icons.sensors_rounded,
                              color: Color(0xFF34D399),
                            ),
                          ),
                          title: Text(
                            tag,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'ID: $sId  |  Nodo ESP: $espId',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.thermostat_rounded,
                                    color: Colors.orangeAccent,
                                    size: 14,
                                  ),
                                  Text(
                                    ' ${temp.toStringAsFixed(1)}Â°C',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(
                                    Icons.water_drop_rounded,
                                    color: Colors.lightBlueAccent,
                                    size: 14,
                                  ),
                                  Text(
                                    ' ${hum.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white70,
                                ),
                                onPressed: () =>
                                    _mostrarSensorDialog(sId, sData),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _eliminarSensor(sId),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                } catch (e) {
                  return Text(
                    'Error al procesar sensores: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
