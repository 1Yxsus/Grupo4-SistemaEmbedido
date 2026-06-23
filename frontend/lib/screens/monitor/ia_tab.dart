import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/section_title.dart';
import '../../widgets/error_card.dart';
import '../../utils/date_helper.dart';

/// Pestaña de Diagnósticos de Madurez IA que muestra la lista de diagnósticos
/// guardados en Firebase con imágenes y barras de confianza del modelo.
class IATab extends StatefulWidget {
  final DatabaseReference iaRef;

  const IATab({super.key, required this.iaRef});

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

    _iaSubscription = _iaStream.listen(
      (event) {
        debugPrint("[IATab - Stream IA] Datos recibidos.");
      },
      onError: (e) {
        debugPrint("[IATab - Stream IA Error] $e");
      },
    );
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: "Diagnósticos de Madurez",
            icon: Icons.psychology_outlined,
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: _iaStream,
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
                        "Esperando análisis de IA...",
                        style: TextStyle(color: Colors.white70),
                      ),
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
                    .where((item) => !item.containsKey('placeholder'))
                    .toList();

                if (listaIA.isEmpty) {
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
                          "Esperando análisis de IA...",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  );
                }

                listaIA.sort((a, b) {
                  final dateA = parseDateTime(a['fecha_hora']?.toString());
                  final dateB = parseDateTime(b['fecha_hora']?.toString());
                  if (dateA == null && dateB == null) return 0;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA);
                });

                final totalItems = listaIA.length;
                final totalPages = (totalItems / _rowsPerPage).ceil();

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

                      String estado =
                          mapa['estado_maduracion']?.toString() ?? "unknown";
                      String confianza = mapa['confianza']?.toString() ?? "0%";
                      String fechaRaw = mapa['fecha_hora']?.toString() ?? "";
                      String? imageUrl = mapa['imagen_url']?.toString();

                      Color colorEstado = Colors.grey;
                      Color bgEstado = Colors.grey.shade800;
                      switch (estado.toLowerCase()) {
                        case "ripe":
                          colorEstado = const Color(0xFF34D399); // Mint
                          bgEstado = const Color(0xFF064E3B); // Dark green
                          break;
                        case "unripe":
                          colorEstado = const Color(
                            0xFFFBBF24,
                          ); // Yellow/Orange
                          bgEstado = const Color(0xFF78350F); // Dark orange
                          break;
                        case "overripe":
                        case "rotten":
                          colorEstado = const Color(0xFFFCA5A5); // Red
                          bgEstado = const Color(0xFF7F1D1D); // Dark red
                          break;
                      }

                      // Parse confidence value for progress bar
                      double valConf = 0.0;
                      try {
                        String cleanConf = confianza.replaceAll('%', '').trim();
                        double parsedVal = double.parse(cleanConf);
                        if (parsedVal > 1.0) {
                          valConf = parsedVal / 100.0;
                        } else {
                          valConf = parsedVal;
                        }
                      } catch (e) {
                        valConf = 0.0;
                      }

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: const Color(0xFF1E293B),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Imagen de cabecera con etiqueta flotante de estado
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              Stack(
                                children: [
                                  Image.network(
                                    imageUrl,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            height: 200,
                                            color: const Color(0xFF0F172A),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          );
                                        },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint(
                                        "[IATab - Image Load Error] $error",
                                      );
                                      return Container(
                                        height: 200,
                                        color: const Color(0xFF0F172A),
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white24,
                                            size: 40,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Etiqueta de estado flotante
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bgEstado.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colorEstado.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _traducirEstado(estado),
                                        style: TextStyle(
                                          color: colorEstado,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Container(
                                height: 100,
                                color: const Color(0xFF0F172A),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(left: 16.0),
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.white24,
                                        size: 32,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 16.0,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: bgEstado.withValues(
                                            alpha: 0.85,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: colorEstado.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          _traducirEstado(estado),
                                          style: TextStyle(
                                            color: colorEstado,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Área de contenido
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Barra de Confianza
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.analytics_outlined,
                                            size: 18,
                                            color: Color(0xFF10B981),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Confianza del Análisis",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        confianza,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF10B981),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: valConf,
                                      backgroundColor: const Color(0xFF0F172A),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        valConf > 0.8
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFFBBF24),
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(
                                    color: Colors.white10,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  // Fecha / Hora
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: Colors.white30,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        fechaRaw,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                            ),
                            color: const Color(0xFF34D399),
                            disabledColor: Colors.white24,
                          ),
                          Text(
                            "Pág. ${_currentPage + 1} de $totalPages",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          IconButton(
                            onPressed: _currentPage < totalPages - 1
                                ? () => setState(() => _currentPage++)
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
                return ErrorCard(error: "Error al procesar datos de IA: $e");
              }
            },
          ),
        ],
      ),
    );
  }
}
