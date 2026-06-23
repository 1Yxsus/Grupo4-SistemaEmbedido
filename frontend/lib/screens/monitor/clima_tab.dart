import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/section_title.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/error_card.dart';
import '../../utils/date_helper.dart';

/// Pestaña de Monitoreo Climático que muestra datos en tiempo real e historial
/// de mediciones almacenados en Firebase Realtime Database.
class ClimaTab extends StatefulWidget {
  final DatabaseReference actualRef;
  final DatabaseReference configRef;
  final DatabaseReference sensoresRef;

  const ClimaTab({
    super.key,
    required this.actualRef,
    required this.configRef,
    required this.sensoresRef,
  });

  @override
  State<ClimaTab> createState() => _ClimaTabState();
}

class _ClimaTabState extends State<ClimaTab>
    with AutomaticKeepAliveClientMixin {
  late Stream<DatabaseEvent> _actualStream;
  StreamSubscription<DatabaseEvent>? _actualSubscription;
  StreamSubscription<DatabaseEvent>? _sensoresSubscription;
  StreamSubscription<DatabaseEvent>? _configSubscription;

  Map<String, dynamic> _sensors = {};
  Map<dynamic, dynamic> _config = {};
  String _selectedSensorId = 'LOTE_PROMEDIO';

  int _currentPage = 0;
  static const int _rowsPerPage = 5;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _actualStream = widget.actualRef.onValue.asBroadcastStream();

    _actualSubscription = _actualStream.listen(
      (event) {
        debugPrint("[ClimaTab - Stream Actual] Datos recibidos.");
      },
      onError: (e) {
        debugPrint("[ClimaTab - Stream Actual Error] $e");
      },
    );

    _sensoresSubscription = widget.sensoresRef.onValue.listen(
      (event) {
        if (event.snapshot.value != null) {
          try {
            final parsedSensors = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            parsedSensors.removeWhere((key, value) => key == 'placeholder');
            setState(() {
              _sensors = parsedSensors;
            });
          } catch (e) {
            debugPrint("[ClimaTab - Sensores Error] $e");
          }
        } else {
          setState(() {
            _sensors = {};
          });
        }
      },
      onError: (e) {
        debugPrint("[ClimaTab - Sensores Stream Error] $e");
      },
    );

    _configSubscription = widget.configRef.onValue.listen(
      (event) {
        if (event.snapshot.value != null) {
          try {
            setState(() {
              _config = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
            });
          } catch (e) {
            debugPrint("[ClimaTab - Config Error] $e");
          }
        } else {
          setState(() {
            _config = {};
          });
        }
      },
      onError: (e) {
        debugPrint("[ClimaTab - Config Stream Error] $e");
      },
    );

    debugPrint("[ClimaTab] Inicializado.");
  }

  @override
  void dispose() {
    _actualSubscription?.cancel();
    _sensoresSubscription?.cancel();
    _configSubscription?.cancel();
    super.dispose();
  }

  Widget _buildSourceOption({
    required BuildContext context,
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E293B)
              : const Color(0xFF1E293B).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? iconColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: iconColor, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarSelectorOrigen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Origen de Mediciones",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Selecciona la fuente de datos climatológicos para visualizar en el panel principal.",
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildSourceOption(
                            context: context,
                            id: 'LOTE_PROMEDIO',
                            title: 'Promedio General del Lote',
                            subtitle:
                                'Combina lecturas de todos los sensores activos',
                            icon: Icons.bar_chart_rounded,
                            iconColor: const Color(0xFF10B981),
                            isSelected: _selectedSensorId == 'LOTE_PROMEDIO',
                            onTap: () {
                              setState(() {
                                _selectedSensorId = 'LOTE_PROMEDIO';
                              });
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 10),
                          ..._sensors.entries.map((entry) {
                            final sKey = entry.key.toString();
                            final sVal = Map<dynamic, dynamic>.from(
                              entry.value as Map,
                            );
                            final sLabel = sVal['etiqueta']?.toString() ?? sKey;
                            final espId = sVal['esp_id']?.toString() ?? sKey;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: _buildSourceOption(
                                context: context,
                                id: sKey,
                                title: sLabel,
                                subtitle: 'Dispositivo ESP: $espId',
                                icon: Icons.sensors_rounded,
                                iconColor: const Color(0xFF06B6D4),
                                isSelected: _selectedSensorId == sKey,
                                onTap: () {
                                  setState(() {
                                    _selectedSensorId = sKey;
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: "Monitoreo Climático",
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(height: 16),

          // Selector de Origen de Mediciones Premium (Trigger de Bottom Sheet)
          GestureDetector(
            onTap: () => _mostrarSelectorOrigen(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          (_selectedSensorId == 'LOTE_PROMEDIO'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF06B6D4))
                              .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedSensorId == 'LOTE_PROMEDIO'
                          ? Icons.bar_chart_rounded
                          : Icons.sensors_rounded,
                      color: _selectedSensorId == 'LOTE_PROMEDIO'
                          ? const Color(0xFF10B981)
                          : const Color(0xFF06B6D4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORIGEN DE MEDICIONES',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedSensorId == 'LOTE_PROMEDIO'
                              ? 'Promedio General del Lote'
                              : (_sensors[_selectedSensorId]?['etiqueta']
                                        ?.toString() ??
                                    _selectedSensorId),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.unfold_more_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder(
            stream: _actualStream,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.hasError) {
                return ErrorCard(error: snapshot.error!);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No hay datos en tiempo real.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                );
              }

              try {
                double temp = 0.0;
                double hum = 0.0;
                String card3Title = "Ventilador";
                String card3Value = "OFF";
                Color card3Color = Colors.redAccent;
                IconData card3Icon = Icons.air_rounded;

                if (_selectedSensorId == 'LOTE_PROMEDIO') {
                  final data = Map<dynamic, dynamic>.from(
                    snapshot.data!.snapshot.value as Map,
                  );
                  temp =
                      ((data['temperatura_promedio'] ?? data['temperatura'])
                              as num)
                          .toDouble();
                  hum = ((data['humedad_promedio'] ?? data['humedad']) as num)
                      .toDouble();
                  bool vent =
                      data['ventilador_estado'] ??
                      data['ventilador_encendido'] ??
                      false;
                  card3Value = vent ? "ON" : "OFF";
                  card3Color = vent
                      ? const Color(0xFF10B981)
                      : Colors.redAccent;
                } else {
                  final sensor = _sensors[_selectedSensorId];
                  if (sensor != null) {
                    final sensorMap = Map<dynamic, dynamic>.from(sensor as Map);
                    temp = (sensorMap['temperatura'] as num).toDouble();
                    hum = (sensorMap['humedad'] as num).toDouble();
                    card3Title = "ID Nodo";
                    card3Value =
                        sensorMap['esp_id']?.toString() ?? _selectedSensorId;
                    card3Color = Colors.tealAccent;
                    card3Icon = Icons.sensors_rounded;
                  } else {
                    return Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            "Sensor no disponible o cargando...",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    );
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MetricCard(
                          icon: Icons.thermostat_rounded,
                          title: "Temperatura",
                          value: "${temp.toStringAsFixed(1)}°C",
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 10),
                        MetricCard(
                          icon: Icons.water_drop_rounded,
                          title: "Humedad",
                          value: "${hum.toStringAsFixed(0)}%",
                          color: Colors.lightBlueAccent,
                        ),
                        const SizedBox(width: 10),
                        MetricCard(
                          icon: card3Icon,
                          title: card3Title,
                          value: card3Value,
                          color: card3Color,
                        ),
                      ],
                    ),
                    if (_selectedSensorId != 'LOTE_PROMEDIO') ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          "* Mostrando mediciones en tiempo real del sensor seleccionado. El historial inferior corresponde al lote completo.",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              } catch (e) {
                return ErrorCard(error: "Error de formato: $e");
              }
            },
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        color: Color(0xFF34D399),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Historial Climático",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  StreamBuilder(
                    stream: Stream.value(
                      null,
                    ), // stream dummy para mantener estructura del codigo anterior sin StreamBuilder directo
                    builder: (context, snapshot) {
                      try {
                        List<Map<String, dynamic>> listaClima = [];
                        double umbralTemp =
                            (_config['umbral_temperatura'] as num?)
                                ?.toDouble() ??
                            27.0;
                        double umbralHum =
                            (_config['umbral_humedad'] as num?)?.toDouble() ??
                            70.0;

                        if (_selectedSensorId == 'LOTE_PROMEDIO') {
                          _sensors.forEach((sensorKey, sensorData) {
                            if (sensorData is Map) {
                              final sVal = Map<dynamic, dynamic>.from(
                                sensorData,
                              );
                              final history = sVal['historial_sensor'];
                              if (history is Map) {
                                final historyMap = Map<dynamic, dynamic>.from(
                                  history,
                                );
                                historyMap.forEach((key, val) {
                                  if (key == 'placeholder') return;
                                  if (val is Map) {
                                    final valMap = Map<dynamic, dynamic>.from(
                                      val,
                                    );
                                    final temp =
                                        (valMap['temperatura'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                    final hum =
                                        (valMap['humedad'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                    final fecha =
                                        valMap['fecha']?.toString() ??
                                        valMap['fecha_hora']?.toString() ??
                                        '';
                                    final excedido =
                                        temp > umbralTemp || hum > umbralHum;
                                    listaClima.add({
                                      'fecha_hora': fecha,
                                      'temperatura': temp,
                                      'humedad': hum,
                                      'limite_excedido': excedido,
                                      'sensor':
                                          sVal['etiqueta']?.toString() ??
                                          sensorKey,
                                    });
                                  }
                                });
                              }
                            }
                          });
                        } else {
                          final sensorData = _sensors[_selectedSensorId];
                          if (sensorData is Map) {
                            final sVal = Map<dynamic, dynamic>.from(sensorData);
                            final history = sVal['historial_sensor'];
                            if (history is Map) {
                              final historyMap = Map<dynamic, dynamic>.from(
                                history,
                              );
                              historyMap.forEach((key, val) {
                                if (key == 'placeholder') return;
                                if (val is Map) {
                                  final valMap = Map<dynamic, dynamic>.from(
                                    val,
                                  );
                                  final temp =
                                      (valMap['temperatura'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final hum =
                                      (valMap['humedad'] as num?)?.toDouble() ??
                                      0.0;
                                  final fecha =
                                      valMap['fecha']?.toString() ??
                                      valMap['fecha_hora']?.toString() ??
                                      '';
                                  final excedido =
                                      temp > umbralTemp || hum > umbralHum;
                                  listaClima.add({
                                    'fecha_hora': fecha,
                                    'temperatura': temp,
                                    'humedad': hum,
                                    'limite_excedido': excedido,
                                    'sensor':
                                        sVal['etiqueta']?.toString() ??
                                        _selectedSensorId,
                                  });
                                }
                              });
                            }
                          }
                        }

                        if (listaClima.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                "No existen registros climáticos.",
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          );
                        }

                        // Ordenar por fecha descendente
                        listaClima.sort((a, b) {
                          final dateA = parseDateTime(
                            a['fecha_hora']?.toString(),
                          );
                          final dateB = parseDateTime(
                            b['fecha_hora']?.toString(),
                          );
                          if (dateA == null && dateB == null) return 0;
                          if (dateA == null) return 1;
                          if (dateB == null) return -1;
                          return dateB.compareTo(dateA);
                        });

                        final totalItems = listaClima.length;
                        final totalPages = (totalItems / _rowsPerPage).ceil();

                        int displayPage = _currentPage;
                        if (displayPage >= totalPages && totalPages > 0) {
                          displayPage = totalPages - 1;
                        } else if (totalPages == 0) {
                          displayPage = 0;
                        }

                        final startIndex = displayPage * _rowsPerPage;
                        final endIndex =
                            (startIndex + _rowsPerPage) > totalItems
                            ? totalItems
                            : (startIndex + _rowsPerPage);
                        final pageItems = listaClima.sublist(
                          startIndex,
                          endIndex,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DataTable(
                              horizontalMargin: 8,
                              columnSpacing: 12,
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF0F172A),
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    "Hora",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Temp",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Hum",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Estado",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: pageItems.map((item) {
                                final mapa = Map<String, dynamic>.from(item);

                                bool excedido =
                                    mapa['limite_excedido'] ?? false;
                                String fecha =
                                    mapa['fecha_hora']?.toString() ?? "";

                                return DataRow(
                                  color:
                                      WidgetStateProperty.resolveWith<Color?>((
                                        states,
                                      ) {
                                        if (excedido) {
                                          return Colors.redAccent.withValues(
                                            alpha: 0.08,
                                          );
                                        }
                                        return null;
                                      }),
                                  cells: [
                                    DataCell(
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            fecha.length > 18
                                                ? fecha.substring(11, 16)
                                                : (fecha.length >= 16
                                                      ? fecha.substring(11, 16)
                                                      : fecha),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_selectedSensorId ==
                                              'LOTE_PROMEDIO')
                                            Text(
                                              mapa['sensor']?.toString() ?? '',
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 9,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "${mapa['temperatura']}°C",
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "${mapa['humedad']}%",
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: excedido
                                              ? const Color(
                                                  0xFF7F1D1D,
                                                ).withValues(alpha: 0.5)
                                              : const Color(
                                                  0xFF064E3B,
                                                ).withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: excedido
                                                ? const Color(
                                                    0xFFFCA5A5,
                                                  ).withValues(alpha: 0.2)
                                                : const Color(
                                                    0xFF34D399,
                                                  ).withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Text(
                                          excedido ? "CRÍTICO" : "NORMAL",
                                          style: TextStyle(
                                            color: excedido
                                                ? const Color(0xFFFCA5A5)
                                                : const Color(0xFF34D399),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            if (totalPages > 1) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: displayPage > 0
                                        ? () => setState(
                                            () =>
                                                _currentPage = displayPage - 1,
                                          )
                                        : null,
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 16,
                                    ),
                                    color: const Color(0xFF34D399),
                                    disabledColor: Colors.white24,
                                  ),
                                  Text(
                                    "Pág. ${displayPage + 1} de $totalPages",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: displayPage < totalPages - 1
                                        ? () => setState(
                                            () =>
                                                _currentPage = displayPage + 1,
                                          )
                                        : null,
                                    icon: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                    ),
                                    color: const Color(0xFF34D399),
                                    disabledColor: Colors.white24,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      } catch (e) {
                        return ErrorCard(
                          error: "Error al procesar el historial: $e",
                        );
                      }
                    },
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
