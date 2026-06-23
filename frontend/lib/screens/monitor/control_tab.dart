import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/section_title.dart';
import '../../widgets/error_card.dart';

/// Pestaña de Control de Actuadores y Configuración de Umbrales Ambientales.
/// Permite gestionar en tiempo real la ruta '/configuracion' en Firebase.
class ControlTab extends StatefulWidget {
  final DatabaseReference configRef;

  const ControlTab({super.key, required this.configRef});

  @override
  State<ControlTab> createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab>
    with AutomaticKeepAliveClientMixin {
  String _modo = 'AUTO';
  double _temp = 27.0;
  double _hum = 70.0;

  double? _localTemp;
  double? _localHum;
  bool _isDraggingTemp = false;
  bool _isDraggingHum = false;

  bool _isLoading = true;
  Object? _error;

  StreamSubscription<DatabaseEvent>? _configSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Escucha en tiempo real los cambios desde Firebase Realtime Database
    _configSubscription = widget.configRef.onValue.listen(
      (event) {
        if (event.snapshot.value != null) {
          try {
            final data = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            setState(() {
              _modo = data['modo_ventilador']?.toString() ?? 'AUTO';

              final dbTemp =
                  (data['umbral_temperatura'] as num?)?.toDouble() ?? 27.0;
              final dbHum =
                  (data['umbral_humedad'] as num?)?.toDouble() ?? 70.0;

              _temp = dbTemp;
              _hum = dbHum;

              // Solo actualizamos el valor local si el usuario no está arrastrando el control
              if (!_isDraggingTemp) {
                _localTemp = dbTemp;
              }
              if (!_isDraggingHum) {
                _localHum = dbHum;
              }

              _isLoading = false;
              _error = null;
            });
          } catch (e) {
            setState(() {
              _error = "Error al procesar los datos de configuración: $e";
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _error = "El nodo 'configuracion' no existe en Firebase.";
            _isLoading = false;
          });
        }
      },
      onError: (err) {
        setState(() {
          _error = "Error de conexión con Firebase: $err";
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    super.dispose();
  }

  /// Actualiza de forma asíncrona el modo del ventilador en Firebase.
  Future<void> _cambiarModoVentilador(String modo) async {
    try {
      await widget.configRef.update({'modo_ventilador': modo});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Modo de ventilador cambiado a $modo'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar el modo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Actualiza de forma asíncrona el umbral de temperatura en Firebase.
  Future<void> _cambiarUmbralTemperatura(double temp) async {
    try {
      await widget.configRef.update({'umbral_temperatura': temp});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Umbral de temperatura actualizado: ${temp.toStringAsFixed(1)}°C',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar temperatura: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Actualiza de forma asíncrona el umbral de humedad en Firebase.
  Future<void> _cambiarUmbralHumedad(double hum) async {
    try {
      await widget.configRef.update({'umbral_humedad': hum});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Umbral de humedad actualizado: ${hum.toStringAsFixed(1)}%',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar humedad: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: ErrorCard(error: _error!),
      );
    }

    // Determinar la paleta de color y estado visual según la selección del modo
    Color activeColor;
    IconData statusIcon;
    String modeDescription;
    if (_modo == 'AUTO') {
      activeColor = const Color(0xFF10B981); // Emerald
      statusIcon = Icons.autorenew_rounded;
      modeDescription =
          "El ventilador se activará automáticamente según los umbrales de temperatura y humedad definidos abajo.";
    } else if (_modo == 'ON') {
      activeColor = const Color(0xFF3B82F6); // Blue
      statusIcon = Icons.bolt_rounded;
      modeDescription =
          "El ventilador está encendido permanentemente. Los límites ambientales están desactivados.";
    } else {
      activeColor = const Color(0xFF64748B); // Slate/Grey
      statusIcon = Icons.power_settings_new_rounded;
      modeDescription =
          "El ventilador está apagado permanentemente. Los límites ambientales están desactivados.";
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: "Control de Actuadores",
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 16),

          // Card de Estado General con bordes dinámicos según selección
          Card(
            elevation: 0,
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: activeColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: activeColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Estado: ",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: activeColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _modo == 'AUTO'
                                    ? "AUTOMÁTICO"
                                    : (_modo == 'ON' ? "ENCENDIDO" : "APAGADO"),
                                style: TextStyle(
                                  color: activeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          modeDescription,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN DE MODO DEL VENTILADOR
          Card(
            elevation: 0,
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.air_rounded, color: Color(0xFF34D399)),
                      SizedBox(width: 10),
                      Text(
                        "Modo del Ventilador",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  const Text(
                    "Selecciona el modo de operación para el ventilador principal del sistema:",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'ON',
                        label: Text('ON'),
                        icon: Icon(Icons.power_rounded, size: 18),
                      ),
                      ButtonSegment<String>(
                        value: 'OFF',
                        label: Text('OFF'),
                        icon: Icon(Icons.power_off_rounded, size: 18),
                      ),
                      ButtonSegment<String>(
                        value: 'AUTO',
                        label: Text('AUTO'),
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                      ),
                    ],
                    selected: {_modo},
                    onSelectionChanged: (Set<String> newSelection) {
                      if (newSelection.isNotEmpty) {
                        _cambiarModoVentilador(newSelection.first);
                      }
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          if (_modo == 'AUTO') {
                            return const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.2);
                          }
                          if (_modo == 'ON') {
                            return const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.2);
                          }
                          return const Color(0xFF64748B).withValues(alpha: 0.2);
                        }
                        return Colors.transparent;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          if (_modo == 'AUTO') {
                            return const Color(0xFF10B981);
                          }
                          if (_modo == 'ON') {
                            return const Color(0xFF3B82F6);
                          }
                          return const Color(0xFFE2E8F0);
                        }
                        return Colors.white70;
                      }),
                      side: WidgetStateProperty.all(
                        BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN DE LÍMITES AMBIENTALES
          Card(
            elevation: 0,
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.thermostat_auto_rounded,
                        color: Color(0xFF34D399),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Límites Ambientales",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white10),

                  // Indicador de estado para sliders deshabilitados si no está en AUTO
                  if (_modo != 'AUTO') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF475569).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Sliders deshabilitados. Activa el modo AUTOMÁTICO para gestionar los umbrales.",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Slider 1: Control de Temperatura
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Umbral de Temperatura",
                        style: TextStyle(
                          color: _modo == 'AUTO'
                              ? Colors.white
                              : Colors.white38,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "${(_localTemp ?? _temp).toStringAsFixed(1)}°C",
                        style: TextStyle(
                          color: _modo == 'AUTO'
                              ? Colors.orangeAccent
                              : Colors.orangeAccent.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: (_localTemp ?? _temp).clamp(15.0, 40.0),
                    min: 15.0,
                    max: 40.0,
                    divisions: 50, // Permite incrementos de 0.5°C
                    activeColor: Colors.orangeAccent,
                    inactiveColor: Colors.white10,
                    onChanged: _modo == 'AUTO'
                        ? (double value) {
                            setState(() {
                              _isDraggingTemp = true;
                              _localTemp = value;
                            });
                          }
                        : null,
                    onChangeEnd: _modo == 'AUTO'
                        ? (double value) async {
                            setState(() {
                              _isDraggingTemp = false;
                            });
                            await _cambiarUmbralTemperatura(value);
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Slider 2: Control de Humedad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Umbral de Humedad",
                        style: TextStyle(
                          color: _modo == 'AUTO'
                              ? Colors.white
                              : Colors.white38,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "${(_localHum ?? _hum).toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: _modo == 'AUTO'
                              ? Colors.lightBlueAccent
                              : Colors.lightBlueAccent.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: (_localHum ?? _hum).clamp(20.0, 90.0),
                    min: 20.0,
                    max: 90.0,
                    divisions: 70, // Permite incrementos de 1%
                    activeColor: Colors.lightBlueAccent,
                    inactiveColor: Colors.white10,
                    onChanged: _modo == 'AUTO'
                        ? (double value) {
                            setState(() {
                              _isDraggingHum = true;
                              _localHum = value;
                            });
                          }
                        : null,
                    onChangeEnd: _modo == 'AUTO'
                        ? (double value) async {
                            setState(() {
                              _isDraggingHum = false;
                            });
                            await _cambiarUmbralHumedad(value);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
