import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/monitor_screen.dart';
// 1. Importa el archivo generado automáticamente
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Pasa las opciones de configuración aquí
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Monitoreo Inteligente',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MonitorScreen(),
    );
  }
}