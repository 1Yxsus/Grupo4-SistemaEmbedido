# Informe Técnico: Sistema de Monitoreo Inteligente y Diagnóstico de Madurez IA

Este documento presenta una descripción técnica detallada del proyecto **sitema_embebido**, una aplicación multiplataforma desarrollada en **Flutter** e integrada con **Firebase Realtime Database** para el monitoreo de variables climáticas y la visualización de clasificaciones de madurez generadas por un modelo de Inteligencia Artificial.

---

## 1. Resumen Ejecutivo
El sistema está diseñado para actuar como la interfaz de usuario (Dashboard) de un ecosistema de hardware embebido e IA. Permite visualizar de forma reactiva y en tiempo real:
1. **Monitoreo Climático**: Temperatura, humedad y el estado de un actuador (ventilador).
2. **Historial Climático**: Registro de anomalías con alertas cuando se exceden los límites.
3. **Diagnóstico de Madurez de Cultivos (IA)**: Clasificación de madurez de lotes agrícolas con su respectivo nivel de confianza.

---

## 2. Arquitectura de Software y Tecnologías
La aplicación sigue una arquitectura cliente-servidor basada en eventos en tiempo real (Event-Driven Architecture) provista por Firebase.

```mermaid
graph TD
    subgraph IoT & AI Agents
        Sensors[Sensores de Clima] -->|Escribe| RTDB
        Actuators[Actuador/Ventilador] <--|Lee/Escribe| RTDB
        IA_Model[Modelo Clasificador IA] -->|Escribe historial| RTDB
    end

    subgraph Firebase Cloud
        RTDB[(Firebase Realtime Database)]
    end

    subgraph Client Application
        Flutter_App[Aplicación Flutter] <--|Stream de Datos| RTDB
        Widget_Tree[Árbol de Widgets / UI] <--|StreamBuilder| Flutter_App
    end
```

### Componentes de Tecnología:
* **Framework**: [Flutter](https://flutter.dev/) (SDK Dart `^3.9.0`), permitiendo compilación nativa para Android, iOS, Windows, macOS y Web.
* **Base de Datos**: [Firebase Realtime Database](https://firebase.google.com/docs/database) (NoSQL), que sincroniza datos de manera inmediata a través de WebSockets (Streams).
* **Diseño Visual**: Material Design 3 con un esquema de colores dinámico basado en tonos verdes y grises claros.

---

## 3. Estructura de Datos en Firebase RTDB
La base de datos en tiempo real está estructurada en tres nodos principales:

### A. `monitoreo_actual` (Datos de Sensores en Tiempo Real)
Representa el estado actual del entorno físico enviado por el sistema embebido.
* `temperatura` (num): Temperatura ambiente en grados Celsius (°C).
* `humedad` (num): Humedad relativa en porcentaje (%).
* `ventilador_encendido` (bool): Estado operativo del extractor o ventilador de refrigeración.

### B. `historial_clima` (Registro Histórico)
Almacena un historial de mediciones climáticas para auditorías de rendimiento. Cada entrada contiene:
* `fecha_hora` (String): Marca de tiempo del registro.
* `temperatura` (num): Temperatura registrada.
* `humedad` (num): Humedad registrada.
* `limite_excedido` (bool): Bandera booleana que indica si los valores cruzaron los umbrales seguros establecidos.

### C. `historial_ia` (Clasificación de Madurez)
Guarda los diagnósticos arrojados por el modelo de IA tras analizar las muestras físicas.
* `lote` (String / num): Identificador del lote inspeccionado.
* `estado_maduracion` (String): Resultado de la inferencia (valores esperados: `ripe` [maduro], `unripe` [inmaduro], `overripe`/`rotten` [sobremaduro/podrido]).
* `confianza` (String): Porcentaje de confianza del modelo (ej. `92%`).
* `fecha_hora` (String): Fecha y hora del análisis.

---

## 4. Estructura del Código Fuente
El código está organizado bajo las convenciones estándar de Flutter:

```
sitema_embebido/
│
├── android/ (Configuraciones nativas de Android)
├── ios/ (Configuraciones nativas de iOS)
├── windows/ (Configuraciones nativas de Windows)
├── web/ (Configuraciones nativas de Web)
│
├── lib/
│   ├── firebase_options.dart (Configuración autogenerada para enlazar con Firebase)
│   ├── main.dart             (Punto de entrada de la aplicación)
│   └── screens/
│       └── monitor_screen.dart (Lógica de negocio y UI principal)
│
├── test/
│   └── widget_test.dart (Archivo de pruebas unitarias/widgets)
│
├── pubspec.yaml  (Definición de dependencias y metadata del proyecto)
└── firebase.json (Configuración de plataformas de Firebase)
```

### Análisis de los Archivos Clave:

#### 1. [main.dart](file:///c:/Users/USUARIO11/StudioProjects/sitema_embebido/lib/main.dart)
Inicializa los servicios de Firebase de forma asíncrona mediante `WidgetsFlutterBinding.ensureInitialized()` y `Firebase.initializeApp()`. Define la raíz de la aplicación (`MyApp`) configurando un tema Material 3 global con semilla en color verde (`Colors.green`) y quitando el banner de depuración.

#### 2. [monitor_screen.dart](file:///c:/Users/USUARIO11/StudioProjects/sitema_embebido/lib/screens/monitor_screen.dart)
Es un `StatefulWidget` que centraliza la lógica interactiva.
* **Gestión de Streams**: Crea una suscripción persistente en `initState()` al stream del historial climático (`_climaStream`) como un `asBroadcastStream()` para optimizar recursos y evitar re-suscripciones innecesarias en el ciclo de vida del widget.
* **Componentes de UI**:
  - **Monitoreo Climático**: Usa un `StreamBuilder` conectado a `/monitoreo_actual` que se redibuja ante cualquier cambio físico. Muestra tarjetas métricas (`_buildMetricCard`) para Temperatura, Humedad y Ventilador.
  - **Historial Climático**: Usa un `ExpansionTile` que se despliega para mostrar una tabla de datos (`DataTable`). Si `limite_excedido` es verdadero, la fila se tiñe de color rojo claro (`Colors.red.shade50`) y muestra el estado como **CRÍTICO** con tipografía resaltada.
  - **Diagnóstico IA**: Emplea otro `StreamBuilder` apuntando a `/historial_ia`. Mapea la lista en reversa para mostrar los análisis más recientes primero. Dependiendo del valor de `estado_maduracion`, se asigna un color identificador:
    - `ripe` $\rightarrow$ Verde
    - `unripe` $\rightarrow$ Naranja
    - `overripe` / `rotten` $\rightarrow$ Rojo
    - Cualquier otro $\rightarrow$ Gris

---

## 5. Integración y Conectividad con Firebase
El proyecto está enlazado al proyecto de Firebase **`sistemasdigitales-5c91f`**.
Las credenciales y configuraciones de conexión por plataforma se definen en [firebase_options.dart](file:///c:/Users/USUARIO11/StudioProjects/sitema_embebido/lib/firebase_options.dart):
* **Database URL**: `https://sistemasdigitales-5c91f-default-rtdb.firebaseio.com`
* **API Key Android**: `AIzaSyDfFk0esxJDLc6egFaW-SsGZ1DY_2m1QAc`
* **App ID Android**: `1:218617606452:android:e6bbf168360d06040ab561`

---

## 6. Puntos de Mejora y Recomendaciones

> [!WARNING]
> **Pruebas Unitarias Desactualizadas**
> El archivo [widget_test.dart](file:///c:/Users/USUARIO11/StudioProjects/sitema_embebido/test/widget_test.dart) contiene la prueba por defecto del contador autogenerado por Flutter. Como el widget `MyHomePage` ya no existe y fue reemplazado por `MonitorScreen`, cualquier ejecución de pruebas fallará. Es prioritario refactorizar este archivo para comprobar la existencia del `AppBar` o los `StreamBuilders` simulados.

> [!TIP]
> **Optimización del Manejo de Errores**
> Actualmente, los `StreamBuilder` no manejan explícitamente el caso de `snapshot.hasError`. Si ocurre una desconexión o falta de permisos en Firebase, la aplicación podría quedarse en un estado de carga infinito o mostrar una pantalla vacía. Se recomienda añadir una verificación:
> ```dart
> if (snapshot.hasError) {
>   return Text('Error al cargar datos: ${snapshot.error}');
> }
> ```

> [!IMPORTANT]
> **Seguridad y Reglas de Firebase**
> Dado que la base de datos es de tiempo real, se debe asegurar que las reglas en la consola de Firebase restrinjan la escritura pública si solo dispositivos autorizados (los microcontroladores y el modelo de IA) deben actualizar los datos climáticos y de IA.
