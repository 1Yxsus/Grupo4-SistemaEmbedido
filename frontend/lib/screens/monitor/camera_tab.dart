import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/scanner_overlay_painter.dart';

enum CameraTabState {
  initializing,
  liveFeed,
  preview,
  uploading,
  processing,
  success,
  error,
}

/// Pestaña de Cámara que permite tomar fotos en tiempo real y enviarlas al
/// servidor de análisis de IA o alternar a detección y segmentación local en tiempo real usando YOLO.
class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  CameraTabState _state = CameraTabState.initializing;
  String _errorMessage = '';
  File? _capturedFile;

  // Variables para alternar modos
  bool _isRealTimeMode = false;
  bool _wasRealTimeMode =
      false; // Registra si la captura provino del modo YOLO local
  bool _cameraPermissionGranted = false;

  // Controlador nativo de YOLO
  final YOLOViewController _yoloViewController = YOLOViewController();

  // Resultados locales detectados por YOLO en tiempo real
  List<dynamic> _localResults = [];

  // Variables para almacenar el resultado de la predicción rápida en servidor
  String? _prediction;
  String? _confidence;
  double _confidenceValue = 0.0;
  String? _imageUrl;
  String? _imageBase64;

  String _traducirEstadoCamera(String? estado) {
    if (estado == null) return "DESCONOCIDO";
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

  Widget _buildResultImage() {
    if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
      try {
        String cleanBase64 = _imageBase64!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        final Uint8List bytes = base64Decode(cleanBase64.trim());
        return RotatedBox(
          quarterTurns: 1, // Rotar 90 grados en sentido horario
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              debugPrint("[CameraTab - Image memory load error] $error");
              return _buildNetworkOrLocalImage();
            },
          ),
        );
      } catch (e) {
        debugPrint("[CameraTab - Base64 decode error] $e");
        return _buildNetworkOrLocalImage();
      }
    } else {
      return _buildNetworkOrLocalImage();
    }
  }

  Widget _buildNetworkOrLocalImage() {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return RotatedBox(
        quarterTurns: 1, // Rotar 90 grados en sentido horario
        child: Image.network(
          _imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint("[CameraTab - Image network load error] $error");
            if (_capturedFile != null) {
              // La imagen local ya viene rotada correctamente por Image.file mediante EXIF
              return Image.file(
                _capturedFile!,
                fit: BoxFit.cover,
                width: double.infinity,
              );
            }
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white24,
                size: 50,
              ),
            );
          },
        ),
      );
    } else if (_capturedFile != null) {
      return Image.file(
        _capturedFile!,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    } else {
      return const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 50),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      if (mounted) {
        setState(() {
          _state = CameraTabState.initializing;
        });
      }

      // Solicitar permiso de cámara en runtime
      if (!_cameraPermissionGranted) {
        final status = await Permission.camera.request();
        if (status.isGranted) {
          _cameraPermissionGranted = true;
        } else {
          throw 'Permiso de cámara denegado. Por favor, habilite el permiso de cámara en la configuración de la aplicación.';
        }
      }

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw 'No se encontraron cámaras disponibles en el dispositivo.';
      }

      // Intentar elegir la cámara trasera
      CameraDescription? selectedCamera;
      for (var cam in _cameras!) {
        if (cam.lensDirection == CameraLensDirection.back) {
          selectedCamera = cam;
          break;
        }
      }
      // Fallback a la primera disponible si no hay trasera
      selectedCamera ??= _cameras!.first;

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false, // Evitamos pedir permiso de micrófono
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _state = CameraTabState.liveFeed;
        });
      }
    } catch (e) {
      debugPrint("Error al inicializar la cámara: $e");
      if (mounted) {
        setState(() {
          _state = CameraTabState.error;
          _errorMessage =
              'No se pudo acceder a la cámara nativa del celular. Verifique los permisos de cámara de la aplicación. Detalle: $e';
        });
      }
    }
  }

  // Cambiar entre el modo local en tiempo real y el modo de captura
  Future<void> _setRealTimeMode(bool enable) async {
    if (enable == _isRealTimeMode) return;

    if (enable) {
      // Solicitar permiso de cámara antes de activar YOLO
      if (!_cameraPermissionGranted) {
        final status = await Permission.camera.request();
        if (status.isGranted) {
          _cameraPermissionGranted = true;
        } else {
          if (mounted) {
            setState(() {
              _state = CameraTabState.error;
              _errorMessage =
                  'Permiso de cámara denegado. Por favor, habilite el permiso de cámara en la configuración de la aplicación.';
            });
          }
          return;
        }
      }
      // Liberar la cámara del sistema para que YOLO pueda tomar el control
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
      setState(() {
        _isRealTimeMode = true;
        _wasRealTimeMode = true; // Recordamos que estuvimos en modo local
        _state = CameraTabState.liveFeed;
        _localResults = []; // Limpiamos resultados previos
      });
      // Desactivar overlays nativos para dibujar los nuestros en Flutter
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _yoloViewController.setShowOverlays(false);
      });
    } else {
      setState(() {
        _isRealTimeMode = false;
        _wasRealTimeMode =
            false; // Apagamos el flag cuando el usuario vuelve manualmente al modo servidor
        _state = CameraTabState.initializing;
        _localResults = []; // Limpiamos los resultados
      });
      // Volver a inicializar la cámara para el modo captura
      await _initializeCamera();
    }
  }

  // Capturar una foto limpia (sin máscaras de YOLO) y pasar a la pantalla de confirmación
  Future<void> _captureRealTimePhoto() async {
    try {
      setState(() {
        _state = CameraTabState.processing; // Muestra "Procesando imagen..."
      });

      // 1. Desactivar el modo de tiempo real temporalmente para liberar la cámara nativa de YOLO
      setState(() {
        _isRealTimeMode = false;
        _localResults = []; // Limpiar los resultados de detección local
      });

      // Esperar 800 milisegundos para que el sistema operativo y CameraX liberen la cámara nativa
      await Future.delayed(const Duration(milliseconds: 800));

      // 2. Inicializar la cámara estándar de Flutter
      await _initializeCamera();

      if (_controller == null || !_controller!.value.isInitialized) {
        throw 'No se pudo inicializar la cámara estándar para capturar la foto.';
      }

      // 3. Tomar la foto real usando la cámara nativa del sistema (esto garantiza que no salga negra)
      final XFile rawImage = await _controller!.takePicture();

      // Copiar a un archivo temporal persistente propio para evitar que se borre tras el dispose de la cámara
      final tempDir = Directory.systemTemp;
      final permanentFile = File(
        '${tempDir.path}/captured_realtime_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(rawImage.path).copy(permanentFile.path);

      setState(() {
        _capturedFile = permanentFile;
        _state = CameraTabState.preview;
        _prediction = null;
        _confidence = null;
        _confidenceValue = 0.0;
        _imageUrl = null;
        _imageBase64 = null;
      });

      // 4. Liberar la cámara estándar para no dejarla abierta de fondo en la pantalla de preview
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
    } catch (e) {
      debugPrint("Error al capturar foto en tiempo real: $e");
      setState(() {
        _state = CameraTabState.error;
        _errorMessage = 'Fallo al tomar la foto local: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Tomar una foto en tiempo real (Modo Servidor estándar)
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile rawImage = await _controller!.takePicture();

      // Copiar a un archivo temporal de cache persistente propio
      final tempDir = Directory.systemTemp;
      final permanentFile = File(
        '${tempDir.path}/captured_standard_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(rawImage.path).copy(permanentFile.path);

      if (mounted) {
        setState(() {
          _capturedFile = permanentFile;
          _state = CameraTabState.preview;
          // Limpiar resultados anteriores
          _prediction = null;
          _confidence = null;
          _confidenceValue = 0.0;
          _imageUrl = null;
          _imageBase64 = null;
        });
      }
    } catch (e) {
      debugPrint("Error al capturar foto: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al capturar foto: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Subir la foto capturada al endpoint
  Future<void> _uploadPhoto() async {
    if (_capturedFile == null) {
      debugPrint("[Upload] ERROR: _capturedFile es nulo.");
      return;
    }
    try {
      debugPrint("[Upload] Iniciando proceso de subida...");
      if (mounted) {
        setState(() {
          _state = CameraTabState.uploading;
        });
      }

      debugPrint("[Upload] Archivo a enviar: ${_capturedFile!.path}");
      final bool fileExists = await _capturedFile!.exists();
      debugPrint("[Upload] ¿El archivo existe en el disco?: $fileExists");
      if (!fileExists) {
        throw "El archivo de imagen no se encuentra en la ruta especificada.";
      }

      final int fileLength = await _capturedFile!.length();
      debugPrint(
        "[Upload] Tamaño del archivo: ${(fileLength / 1024 / 1024).toStringAsFixed(2)} MB",
      );

      final Uri url = Uri.parse(
        'https://venuxmk-detecciondefrutas.hf.space/api/test',
      );
      debugPrint("[Upload] Destino del request: $url");
      final http.MultipartRequest request = http.MultipartRequest('POST', url);

      debugPrint("[Upload] Adjuntando campo 'file'...");
      request.files.add(
        await http.MultipartFile.fromPath('file', _capturedFile!.path),
      );

      debugPrint("[Upload] Adjuntando campo 'image'...");
      request.files.add(
        await http.MultipartFile.fromPath('image', _capturedFile!.path),
      );

      debugPrint("[Upload] Enviando petición al servidor...");
      final http.StreamedResponse response = await request.send();
      debugPrint(
        "[Upload] Petición enviada. Código de respuesta: ${response.statusCode}",
      );

      // Fase 2: Procesando en el servidor
      if (mounted) {
        setState(() {
          _state = CameraTabState.processing;
        });
      }

      debugPrint("[Upload] Leyendo respuesta del stream...");
      final String responseBody = await response.stream.bytesToString();
      debugPrint("[Upload] Respuesta completa recibida: $responseBody");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        if (data['status'] == 'success') {
          _prediction = data['prediccion']?.toString();
          _confidence = data['confianza']?.toString();

          final rawConfValue = data['confianza_valor'];
          if (rawConfValue is num) {
            _confidenceValue = rawConfValue.toDouble();
          } else {
            _confidenceValue = 0.0;
          }

          _imageUrl = data['imagen_url']?.toString();
          _imageBase64 = data['imagen_base64']?.toString();

          if (mounted) {
            setState(() {
              _state = CameraTabState.success;
            });
          }
        } else {
          throw data['message'] ??
              'Error de lógica en la respuesta del servidor';
        }
      } else {
        throw 'El servidor respondió con código HTTP: ${response.statusCode}';
      }
    } catch (e, stackTrace) {
      debugPrint("[Upload] ERROR CAPTURADO: $e");
      debugPrint("[Upload] STACK TRACE: $stackTrace");
      if (mounted) {
        setState(() {
          _state = CameraTabState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selector de Modo (Servidor/Captura vs Tiempo Real/Local)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setRealTimeMode(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isRealTimeMode
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Modo Servidor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_isRealTimeMode
                              ? Colors.white
                              : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setRealTimeMode(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isRealTimeMode
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Tiempo Real (Local)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isRealTimeMode
                              ? Colors.white
                              : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Advertencia de rendimiento para procesamiento YOLO local
        if (_isRealTimeMode)
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 12.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amberAccent,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se requiere un smartphone con buen rendimiento para procesar la detección de madurez local en tiempo real de forma fluida.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Contenido Principal
        Expanded(
          child: _isRealTimeMode
              ? _buildRealTimeYOLOView()
              : _buildStandardStateView(),
        ),
      ],
    );
  }

  Widget _buildRealTimeYOLOView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildTabSectionTitle(
            "Segmentación en Tiempo Real",
            Icons.psychology_outlined,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double width = constraints.maxWidth;
                        final double height = constraints.maxHeight;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            YOLOView(
                              controller: _yoloViewController,
                              modelPath:
                                  'assets/best.tflite', // Ruta del asset en Flutter
                              task: YOLOTask
                                  .segment, // Tarea de segmentación (coincide con el modelo exportado)
                              useGpu:
                                  true, // Activado para optimizar velocidad a 15-30 FPS en GPU y evitar consumo de RAM excesivo
                              confidenceThreshold:
                                  0.15, // Umbral mínimo de confianza reducido para pruebas
                              streamingConfig: YOLOStreamingConfig.custom(
                                includeMasks: true, // Habilitar segmentación
                                maxFPS:
                                    15, // Limitar actualización de UI a 15 FPS para reducir lag
                                inferenceFrequency:
                                    10, // Limitar inferencias a 10 por segundo para evitar sobrecalentamiento
                                skipFrames:
                                    2, // Saltar frames para aliviar el procesador gráfico del celular
                                analysisResolution: const Size(
                                  320,
                                  240,
                                ), // Forzar análisis a 320x240 para máxima fluidez y cero lag
                              ),
                              onResult: (results) {
                                if (results.isNotEmpty) {
                                  for (var r in results) {
                                    debugPrint(
                                      "[YOLO Local] Detectado: ${r.className} (${(r.confidence * 100).toStringAsFixed(1)}%)",
                                    );
                                  }
                                }
                                if (mounted) {
                                  setState(() {
                                    _localResults = results;
                                  });
                                }
                              },
                            ),
                            // Dibujar las cajas de detección encima usando _localResults
                            ..._localResults.map((result) {
                              final normBox = result.normalizedBox;
                              if (normBox == null) {
                                return const SizedBox.shrink();
                              }

                              // Convertir coordenadas normalizadas a píxeles
                              final double left = normBox.left * width;
                              final double top = normBox.top * height;
                              final double boxWidth = normBox.width * width;
                              final double boxHeight = normBox.height * height;

                              // Color representativo según clase / tipo de fruta
                              Color color = const Color(
                                0xFF10B981,
                              ); // Emerald por defecto
                              final nameLower = result.className.toLowerCase();
                              if (nameLower.contains('unripe') ||
                                  nameLower.contains('verde')) {
                                color = const Color(0xFFFBBF24); // Amarillo
                              } else if (nameLower.contains('rotten') ||
                                  nameLower.contains('podrido') ||
                                  nameLower.contains('overripe')) {
                                color = const Color(0xFFEF4444); // Rojo
                              } else if (nameLower.contains('banana') ||
                                  nameLower.contains('platano')) {
                                color = const Color(
                                  0xFFFDE047,
                                ); // Amarillo brillante
                              } else if (nameLower.contains('orange') ||
                                  nameLower.contains('naranja')) {
                                color = const Color(0xFFF97316); // Naranja
                              } else if (nameLower.contains('avocado') ||
                                  nameLower.contains('palta')) {
                                color = const Color(0xFF84CC16); // Verde palta
                              }

                              return Positioned(
                                left: left,
                                top: top,
                                width: boxWidth,
                                height: boxHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: color, width: 3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        top: -24,
                                        left: -3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(4),
                                                  topRight: Radius.circular(4),
                                                ),
                                          ),
                                          child: Text(
                                            "${result.className.toUpperCase()} ${(result.confidence * 100).toStringAsFixed(0)}%",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Botón obturador para capturar en tiempo real (sin máscaras de segmentación)
          GestureDetector(
            onTap: _captureRealTimePhoto,
            child: Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF34D399), // Mint green
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Toca el botón para tomar una foto del objeto y verificar con el servidor.",
            style: TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStandardStateView() {
    switch (_state) {
      case CameraTabState.initializing:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF10B981)),
              SizedBox(height: 16),
              Text(
                'Iniciando cámara...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case CameraTabState.liveFeed:
        if (_controller == null || !_controller!.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            // Líneas de cuadrícula estilo escáner industrial
                            CustomPaint(painter: ScannerOverlayPainter()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Botón obturador estilo premium
              GestureDetector(
                onTap: _takePicture,
                child: Container(
                  height: 76,
                  width: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981), // Emerald
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );

      case CameraTabState.preview:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildTabSectionTitle(
                "Confirmar Fotografía",
                Icons.check_circle_outline_rounded,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.file(
                          _capturedFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded),
                      label: const Text("DESCARTAR"),
                      onPressed: () {
                        if (_wasRealTimeMode) {
                          _setRealTimeMode(true);
                        } else {
                          setState(() {
                            _state = CameraTabState.liveFeed;
                            _prediction = null;
                            _confidence = null;
                            _confidenceValue = 0.0;
                            _imageUrl = null;
                            _imageBase64 = null;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: const Text("ENVIAR FOTO"),
                      onPressed: _uploadPhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );

      case CameraTabState.uploading:
        return _buildProgressState(
          title: 'Procesando imagen',
          detail: '',
          color: const Color(0xFF34D399),
          icon: Icons.cloud_upload_outlined,
        );

      case CameraTabState.processing:
        return _buildProgressState(
          title: 'Procesando imagen',
          detail: '',
          color: const Color(0xFF60A5FA),
          icon: Icons.psychology_outlined,
        );

      case CameraTabState.success:
        Color colorEstado = Colors.grey;
        Color bgEstado = Colors.grey.shade800;
        final String rawPrediction = _prediction ?? "unknown";
        switch (rawPrediction.toLowerCase()) {
          case "ripe":
            colorEstado = const Color(0xFF34D399); // Mint
            bgEstado = const Color(0xFF064E3B); // Dark green
            break;
          case "unripe":
            colorEstado = const Color(0xFFFBBF24); // Yellow/Orange
            bgEstado = const Color(0xFF78350F); // Dark orange
            break;
          case "overripe":
          case "rotten":
            colorEstado = const Color(0xFFFCA5A5); // Red
            bgEstado = const Color(0xFF7F1D1D); // Dark red
            break;
        }

        final double valConf = (_confidenceValue > 1.0)
            ? (_confidenceValue / 100.0)
            : _confidenceValue;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF064E3B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF34D399),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Predicción Rápida Exitosa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Vista de la imagen (remota, con fallback local)
              Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _buildResultImage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Detalles del Resultado
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Maduración General:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: bgEstado.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorEstado.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                _traducirEstadoCamera(_prediction),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colorEstado,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Grado de Confianza:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _confidence ?? "0.00%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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
                          minHeight: 8,
                        ),
                      ),
                      if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        const Text(
                          "URL de Imagen:",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _imageUrl!,
                          style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("TOMAR OTRA FOTO"),
                onPressed: () {
                  if (_wasRealTimeMode) {
                    _setRealTimeMode(true);
                  } else {
                    setState(() {
                      _state = CameraTabState.liveFeed;
                      _prediction = null;
                      _confidence = null;
                      _confidenceValue = 0.0;
                      _imageUrl = null;
                      _imageBase64 = null;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );

      case CameraTabState.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF7F1D1D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFFCA5A5),
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Fallo en el Proceso',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      if (_wasRealTimeMode) {
                        _setRealTimeMode(true);
                      } else {
                        setState(() {
                          _state = CameraTabState.liveFeed;
                          _prediction = null;
                          _confidence = null;
                          _confidenceValue = 0.0;
                          _imageUrl = null;
                          _imageBase64 = null;
                        });
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("VOLVER"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _uploadPhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("REINTENTAR"),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _buildProgressState({
    required String title,
    required String detail,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_capturedFile != null) ...[
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(_capturedFile!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 72,
                width: 72,
                child: CircularProgressIndicator(color: color, strokeWidth: 4),
              ),
              Icon(icon, color: color, size: 36),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF34D399), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
