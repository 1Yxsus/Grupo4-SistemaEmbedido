import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final DatabaseReference _actualRef =
      FirebaseDatabase.instance.ref('monitoreo_actual');

  final DatabaseReference _climaRef =
      FirebaseDatabase.instance.ref('historial_clima');

  final DatabaseReference _iaRef =
      FirebaseDatabase.instance.ref('historial_ia');

  @override
  void initState() {
    super.initState();
    debugPrint("[MonitorScreen] Inicializado.");
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          centerTitle: true,
          elevation: 4,
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          title: const Text(
            'Sistema de Monitoreo Inteligente',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.cloud),
                text: "Clima",
              ),
              Tab(
                icon: Icon(Icons.psychology),
                text: "Diagnóstico IA",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ClimaTab(
              actualRef: _actualRef,
              climaRef: _climaRef,
            ),
            IATab(
              iaRef: _iaRef,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// VISTA: MONITOREO CLIMÁTICO E HISTORIAL
// ==========================================================
class ClimaTab extends StatefulWidget {
  final DatabaseReference actualRef;
  final DatabaseReference climaRef;

  const ClimaTab({
    super.key,
    required this.actualRef,
    required this.climaRef,
  });

  @override
  State<ClimaTab> createState() => _ClimaTabState();
}

class _ClimaTabState extends State<ClimaTab> with AutomaticKeepAliveClientMixin {
  late Stream<DatabaseEvent> _actualStream;
  late Stream<DatabaseEvent> _climaStream;
  StreamSubscription<DatabaseEvent>? _actualSubscription;
  StreamSubscription<DatabaseEvent>? _climaSubscription;

  int _currentPage = 0;
  static const int _rowsPerPage = 5;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    _actualStream = widget.actualRef.onValue.asBroadcastStream();
    _climaStream = widget.climaRef.onValue.asBroadcastStream();

    _actualSubscription = _actualStream.listen((event) {
      debugPrint("[ClimaTab - Stream Actual] Datos recibidos.");
    }, onError: (e) {
      debugPrint("[ClimaTab - Stream Actual Error] $e");
    });

    _climaSubscription = _climaStream.listen((event) {
      debugPrint("[ClimaTab - Stream Clima] Datos recibidos.");
    }, onError: (e) {
      debugPrint("[ClimaTab - Stream Clima Error] $e");
    });

    debugPrint("[ClimaTab] Inicializado.");
  }

  @override
  void dispose() {
    _actualSubscription?.cancel();
    _climaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionTitle(
            "Monitoreo Climático",
            Icons.cloud,
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: _actualStream,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.hasError) {
                return _buildErrorCard(snapshot.error!);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "No hay datos en tiempo real.",
                    ),
                  ),
                );
              }

              try {
                final data = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );

                double temp = (data['temperatura'] as num).toDouble();
                double hum = (data['humedad'] as num).toDouble();
                bool vent = data['ventilador_encendido'] ?? false;

                return Row(
                  children: [
                    _buildMetricCard(
                      Icons.thermostat,
                      "Temperatura",
                      "${temp.toStringAsFixed(1)}°C",
                      Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      Icons.water_drop,
                      "Humedad",
                      "${hum.toStringAsFixed(0)}%",
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      Icons.air,
                      "Ventilador",
                      vent ? "ON" : "OFF",
                      vent ? Colors.green : Colors.red,
                    ),
                  ],
                );
              } catch (e) {
                return _buildErrorCard("Error de formato: $e");
              }
            },
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Historial Climático",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  StreamBuilder(
                    stream: _climaStream,
                    builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                      if (snapshot.hasError) {
                        return _buildErrorCard(snapshot.error!);
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "No existen registros climáticos.",
                          ),
                        );
                      }

                      try {
                        final rawData = Map<dynamic, dynamic>.from(
                          snapshot.data!.snapshot.value as Map,
                        );

                        final listaClima = rawData.values
                            .map((item) => Map<dynamic, dynamic>.from(item as Map))
                            .toList();
                        
                        // Ordenamiento cronológico robusto
                        listaClima.sort((a, b) {
                          final dateA = _parseDateTime(a['fecha_hora']?.toString());
                          final dateB = _parseDateTime(b['fecha_hora']?.toString());
                          if (dateA == null && dateB == null) return 0;
                          if (dateA == null) return 1;
                          if (dateB == null) return -1;
                          return dateB.compareTo(dateA); // Más nuevo a más antiguo
                        });

                        final totalItems = listaClima.length;
                        final totalPages = (totalItems / _rowsPerPage).ceil();

                        // Adjust current page if out of bounds
                        if (_currentPage >= totalPages && totalPages > 0) {
                          _currentPage = totalPages - 1;
                        } else if (totalPages == 0) {
                          _currentPage = 0;
                        }

                        final startIndex = _currentPage * _rowsPerPage;
                        final endIndex = (startIndex + _rowsPerPage) > totalItems
                            ? totalItems
                            : (startIndex + _rowsPerPage);
                        final pageItems = listaClima.sublist(startIndex, endIndex);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DataTable(
                              horizontalMargin: 12,
                              columnSpacing: 16,
                              headingRowColor: WidgetStateProperty.all(
                                Colors.green.shade50,
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text("Hora"),
                                ),
                                DataColumn(
                                  label: Text("Temp"),
                                ),
                                DataColumn(
                                  label: Text("Hum"),
                                ),
                                DataColumn(
                                  label: Text("Estado"),
                                ),
                              ],
                              rows: pageItems.map((item) {
                                final mapa = Map<String, dynamic>.from(item);

                                bool excedido = mapa['limite_excedido'] ?? false;
                                String fecha = mapa['fecha_hora']?.toString() ?? "";

                                return DataRow(
                                  color: WidgetStateProperty.all(
                                    excedido ? Colors.red.shade50 : Colors.transparent,
                                  ),
                                  cells: [
                                    DataCell(
                                      Text(
                                        fecha.length > 18
                                            ? fecha.substring(11, 19)
                                            : fecha,
                                      ),
                                    ),
                                    DataCell(
                                      Text("${mapa['temperatura']}°C"),
                                    ),
                                    DataCell(
                                      Text("${mapa['humedad']}%"),
                                    ),
                                    DataCell(
                                      Text(
                                        excedido ? "CRÍTICO" : "NORMAL",
                                        style: TextStyle(
                                          color: excedido ? Colors.red : Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            if (totalPages > 1) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: _currentPage > 0
                                        ? () => setState(() => _currentPage--)
                                        : null,
                                    icon: const Icon(Icons.arrow_back, size: 18),
                                    label: const Text("Anterior"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                      disabledForegroundColor: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    "Pág. ${_currentPage + 1} de $totalPages",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextButton.icon(
                                    onPressed: _currentPage < totalPages - 1
                                        ? () => setState(() => _currentPage++)
                                        : null,
                                    icon: const Icon(Icons.arrow_forward, size: 18),
                                    label: const Text("Siguiente"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                      disabledForegroundColor: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      } catch (e) {
                        return _buildErrorCard("Error al procesar el historial: $e");
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

// ==========================================================
// VISTA: DIAGNÓSTICO DE MADUREZ IA
// ==========================================================
class IATab extends StatefulWidget {
  final DatabaseReference iaRef;

  const IATab({
    super.key,
    required this.iaRef,
  });

  @override
  State<IATab> createState() => _IATabState();
}

class _IATabState extends State<IATab> with AutomaticKeepAliveClientMixin {
  late Stream<DatabaseEvent> _iaStream;
  StreamSubscription<DatabaseEvent>? _iaSubscription;

  int _currentPage = 0;
  static const int _rowsPerPage = 5;

  String _traducirEstado(String estado) {
    switch (estado.toLowerCase()) {
      case "ripe":
        return "MADURO";
      case "unripe":
        return "VERDE";
      case "overripe":
        return "SOBREMADURO";
      case "rotten":
        return "PODRIDO";
      default:
        return estado.toUpperCase();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _iaStream = widget.iaRef.onValue.asBroadcastStream();

    _iaSubscription = _iaStream.listen((event) {
      debugPrint("[IATab - Stream IA] Datos recibidos.");
    }, onError: (e) {
      debugPrint("[IATab - Stream IA Error] $e");
    });
  }

  @override
  void dispose() {
    _iaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionTitle(
            "Diagnóstico de Madurez IA",
            Icons.psychology,
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: _iaStream,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.hasError) {
                return _buildErrorCard(snapshot.error!);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "Esperando análisis de IA...",
                    ),
                  ),
                );
              }

              try {
                final rawData = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );

                final listaIA = rawData.values
                    .map((item) => Map<dynamic, dynamic>.from(item as Map))
                    .toList();
                
                // Ordenamiento cronológico robusto
                listaIA.sort((a, b) {
                  final dateA = _parseDateTime(a['fecha_hora']?.toString());
                  final dateB = _parseDateTime(b['fecha_hora']?.toString());
                  if (dateA == null && dateB == null) return 0;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA); // Más nuevo a más antiguo
                });

                final totalItems = listaIA.length;
                final totalPages = (totalItems / _rowsPerPage).ceil();

                // Adjust current page if out of bounds
                if (_currentPage >= totalPages && totalPages > 0) {
                  _currentPage = totalPages - 1;
                } else if (totalPages == 0) {
                  _currentPage = 0;
                }

                final startIndex = _currentPage * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage) > totalItems
                    ? totalItems
                    : (startIndex + _rowsPerPage);
                final pageItems = listaIA.sublist(startIndex, endIndex);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...pageItems.map((item) {
                      final mapa = Map<String, dynamic>.from(item);

                      String estado = mapa['estado_maduracion']?.toString() ?? "unknown";
                      String confianza = mapa['confianza']?.toString() ?? "0%";
                      String fechaRaw = mapa['fecha_hora']?.toString() ?? "";
                      String? imageUrl = mapa['imagen_url']?.toString();

                      Color colorEstado = Colors.grey;
                      switch (estado.toLowerCase()) {
                        case "ripe":
                          colorEstado = Colors.green;
                          break;
                        case "unripe":
                          colorEstado = Colors.orange;
                          break;
                        case "overripe":
                        case "rotten":
                          colorEstado = Colors.red;
                          break;
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colorEstado.withValues(alpha: 0.15),
                                    child: Icon(
                                      Icons.psychology,
                                      color: colorEstado,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Lote ${mapa['lote']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    backgroundColor: colorEstado.withValues(alpha: 0.15),
                                    label: Text(
                                      _traducirEstado(estado),
                                      style: TextStyle(
                                        color: colorEstado,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Mostrar imagen directamente si existe
                              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.network(
                                    imageUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 180,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint("[IATab - Image Load Error] $error");
                                      return Container(
                                        height: 180,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 40,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  const Icon(
                                    Icons.analytics,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Confianza: $confianza",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    fechaRaw,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text("Anterior"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              disabledForegroundColor: Colors.grey,
                            ),
                          ),
                          Text(
                            "Pág. ${_currentPage + 1} de $totalPages",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _currentPage < totalPages - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text("Siguiente"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              disabledForegroundColor: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              } catch (e) {
                return _buildErrorCard("Error al procesar datos de IA: $e");
              }
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// COMPONENTES COMUNES Y FUNCIONES AUXILIARES
// ==========================================================

/// Parseador de fechas robusto para formatos:
/// - "DD/MM/YY HH:mm" (ej: 11/06/26 07:31)
/// - ISO (ej: YYYY-MM-DD HH:mm:ss)
DateTime? _parseDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;
  try {
    if (dateStr.contains('-')) {
      return DateTime.parse(dateStr);
    }
    
    final parts = dateStr.split(' ');
    if (parts.length < 2) return null;
    
    final dateParts = parts[0].split('/');
    final timeParts = parts[1].split(':');
    if (dateParts.length != 3 || timeParts.length < 2) return null;
    
    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);
    if (year < 100) year += 2000;
    
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    int second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
    
    return DateTime(year, month, day, hour, minute, second);
  } catch (e) {
    debugPrint("[_parseDateTime] Error al parsear fecha '$dateStr': $e");
    return null;
  }
}

Widget _buildSectionTitle(String title, IconData icon) {
  return Row(
    children: [
      Icon(
        icon,
        color: Colors.green.shade700,
        size: 30,
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

Widget _buildMetricCard(IconData icon, String title, String value, Color color) {
  return Expanded(
    child: Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildErrorCard(Object error) {
  return Card(
    color: Colors.red.shade50,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.red.shade200, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Error de Conectividad o Datos",
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}