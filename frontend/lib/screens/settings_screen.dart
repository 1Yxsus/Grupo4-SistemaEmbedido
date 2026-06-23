import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('usuarios');

  Map<dynamic, dynamic>? _myProfile;
  bool _isLoadingProfile = true;
  String _myRole = 'Almacenero';

  final TextEditingController _searchController = TextEditingController();
  String _userSearchQuery = "";
  int _userCurrentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    final user = _authService.usuarioActual;
    if (user != null) {
      try {
        final snapshot = await _usersRef.child(user.uid).get();
        if (snapshot.exists) {
          setState(() {
            _myProfile = Map<dynamic, dynamic>.from(snapshot.value as Map);
            _myRole = _myProfile?['rol']?.toString() ?? 'Almacenero';
            _isLoadingProfile = false;
          });
        } else {
          setState(() {
            _isLoadingProfile = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _mostrarEditarNombreDialog() {
    final controller = TextEditingController(
      text: _myProfile?['nombre']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Editar Nombre',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Nombre Completo',
              labelStyle: TextStyle(color: Colors.white60),
            ),
            validator: (val) => val == null || val.trim().isEmpty
                ? 'Ingrese un nombre válido'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final user = _authService.usuarioActual;
                if (user != null) {
                  final nuevoNombre = controller.text.trim();
                  await _usersRef.child(user.uid).update({
                    'nombre': nuevoNombre,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nombre de usuario actualizado.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                  _loadMyProfile();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('GUARDAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarRolUsuario(
    String uid,
    String nombre,
    String rolActual,
  ) async {
    String selectedRol = rolActual;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Gestionar Rol de Usuario',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona el nuevo rol para "$nombre":',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRol,
                dropdownColor: const Color(0xFF1E293B),
                decoration: InputDecoration(
                  labelText: 'Rol del Sistema',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Almacenero',
                    child: Text(
                      'Almacenero',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Administrador',
                    child: Text(
                      'Administrador',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Owner',
                    child: Text(
                      'Owner (Propietario)',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedRol = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              child: const Text(
                'GUARDAR',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _usersRef.child(uid).update({'rol': selectedRol});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol de $nombre cambiado a $selectedRol.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final int ms = timestamp is int
          ? timestamp
          : int.parse(timestamp.toString());
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.usuarioActual;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Configuración y Perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF090D16),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mi perfil card
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 36,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _myProfile?['nombre']?.toString() ??
                                                'Usuario',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            color: Color(0xFF34D399),
                                            size: 20,
                                          ),
                                          tooltip: 'Editar nombre',
                                          onPressed: _mostrarEditarNombreDialog,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user?.email ?? 'Sin correo',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: Colors.white10),
                          _buildProfileRow(
                            "Rol del Sistema:",
                            _myRole,
                            isRole: true,
                          ),
                          const SizedBox(height: 12),
                          _buildProfileRow(
                            "Fecha Registro:",
                            _formatTimestamp(_myProfile?['fecha_registro']),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Si es Administrador u Owner, mostrar lista de todos los usuarios
                  if (_myRole == 'Administrador' || _myRole == 'Owner') ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        "Usuarios Registrados",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Campo de búsqueda general
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o correo...',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF10B981),
                          ),
                          suffixIcon: _userSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: Colors.white60,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _userSearchQuery = "";
                                      _userCurrentPage = 1;
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B981),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _userSearchQuery = value.trim();
                            _userCurrentPage = 1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<DatabaseEvent>(
                      stream: _usersRef.onValue,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            "Error cargando usuarios: ${snapshot.error}",
                            style: const TextStyle(color: Colors.redAccent),
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
                          return const Text(
                            "No hay otros usuarios registrados.",
                            style: TextStyle(color: Colors.white60),
                          );
                        }

                        try {
                          final allUsers = Map<dynamic, dynamic>.from(
                            snapshot.data!.snapshot.value as Map,
                          );
                          final userList = allUsers.entries.map((e) {
                            final val = Map<dynamic, dynamic>.from(
                              e.value as Map,
                            );
                            return {
                              'uid': e.key,
                              'nombre': val['nombre']?.toString() ?? 'N/A',
                              'correo': val['correo']?.toString() ?? 'N/A',
                              'rol': val['rol']?.toString() ?? 'Almacenero',
                              'fecha_registro': val['fecha_registro'],
                            };
                          }).toList();

                          // Ordenar usuarios por nombre
                          userList.sort(
                            (a, b) => a['nombre'].toString().compareTo(
                              b['nombre'].toString(),
                            ),
                          );

                          // Filtrar usuarios por búsqueda general (nombre y correo)
                          final filteredList = userList.where((u) {
                            final nombre = u['nombre'].toString().toLowerCase();
                            final correo = u['correo'].toString().toLowerCase();
                            final query = _userSearchQuery.toLowerCase();
                            return nombre.contains(query) ||
                                correo.contains(query);
                          }).toList();

                          if (filteredList.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32.0),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people_outline_rounded,
                                      size: 48,
                                      color: Colors.white24,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "No se encontraron usuarios",
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Control de paginación (máximo 4 usuarios por página)
                          const int pageSize = 4;
                          final totalUsers = filteredList.length;
                          final totalPages = (totalUsers / pageSize).ceil();

                          // Asegurar que la página de visualización esté en límites
                          int displayPage = _userCurrentPage;
                          if (displayPage > totalPages) {
                            displayPage = totalPages > 0 ? totalPages : 1;
                          }
                          if (displayPage < 1) {
                            displayPage = 1;
                          }

                          final startIndex = (displayPage - 1) * pageSize;
                          final slicedList = filteredList
                              .skip(startIndex)
                              .take(pageSize)
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: slicedList.length,
                                itemBuilder: (context, index) {
                                  final u = slicedList[index];
                                  final isMe = u['uid'] == user?.uid;

                                  return Card(
                                    color: const Color(0xFF1E293B),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isMe
                                            ? const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.3)
                                            : Colors.white.withValues(
                                                alpha: 0.03,
                                              ),
                                        width: isMe ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: ListTile(
                                      trailing: (isMe || _myRole != 'Owner')
                                          ? null
                                          : IconButton(
                                              icon: const Icon(
                                                Icons.manage_accounts_rounded,
                                                color: Color(0xFF34D399),
                                              ),
                                              tooltip: 'Cambiar rol',
                                              onPressed: () =>
                                                  _cambiarRolUsuario(
                                                    u['uid'].toString(),
                                                    u['nombre'].toString(),
                                                    u['rol'].toString(),
                                                  ),
                                            ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            (u['rol'] == 'Owner'
                                                    ? Colors.deepOrangeAccent
                                                    : (u['rol'] ==
                                                              'Administrador'
                                                          ? Colors.purpleAccent
                                                          : Colors.tealAccent))
                                                .withValues(alpha: 0.15),
                                        child: Icon(
                                          u['rol'] == 'Owner'
                                              ? Icons.star_rounded
                                              : (u['rol'] == 'Administrador'
                                                    ? Icons
                                                          .admin_panel_settings_rounded
                                                    : Icons.badge_rounded),
                                          color: u['rol'] == 'Owner'
                                              ? Colors.deepOrangeAccent
                                              : (u['rol'] == 'Administrador'
                                                    ? Colors.purpleAccent
                                                    : Colors.tealAccent),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              u['nombre'].toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (isMe)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'TÚ',
                                                style: TextStyle(
                                                  color: Color(0xFF10B981),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            u['correo'].toString(),
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                u['rol']
                                                    .toString()
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: u['rol'] == 'Owner'
                                                      ? Colors.deepOrangeAccent
                                                      : (u['rol'] ==
                                                                'Administrador'
                                                            ? Colors
                                                                  .purpleAccent
                                                            : Colors
                                                                  .tealAccent),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                _formatTimestamp(
                                                  u['fecha_registro'],
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white30,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (totalPages > 1) ...[
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Botón de página anterior (Ant.)
                                      ElevatedButton.icon(
                                        onPressed: displayPage > 1
                                            ? () {
                                                setState(() {
                                                  _userCurrentPage =
                                                      displayPage - 1;
                                                });
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1E293B,
                                          ),
                                          disabledBackgroundColor: const Color(
                                            0xFF1E293B,
                                          ).withValues(alpha: 0.5),
                                          foregroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                          disabledForegroundColor:
                                              Colors.white30,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.arrow_back_ios_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          "Ant.",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      // Indicador de paginación
                                      Text(
                                        "Pág. $displayPage de $totalPages",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      // Botón de página siguiente (Sig.)
                                      ElevatedButton.icon(
                                        onPressed: displayPage < totalPages
                                            ? () {
                                                setState(() {
                                                  _userCurrentPage =
                                                      displayPage + 1;
                                                });
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1E293B,
                                          ),
                                          disabledBackgroundColor: const Color(
                                            0xFF1E293B,
                                          ).withValues(alpha: 0.5),
                                          foregroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                          disabledForegroundColor:
                                              Colors.white30,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                        icon: const Text(
                                          "Sig.",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        label: const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        } catch (e) {
                          return Text(
                            "Error formateando lista: $e",
                            style: const TextStyle(color: Colors.redAccent),
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Botón Cerrar Sesión
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E293B),
                          title: const Text(
                            'Cerrar Sesión',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            '¿Estás seguro de que deseas salir del sistema?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'CANCELAR',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              child: const Text('CERRAR SESIÓN'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _authService.cerrarSesion();
                        if (context.mounted) {
                          Navigator.pop(context); // Cerrar SettingsScreen
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1,
                        ),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'CERRAR SESIÓN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileRow(String label, String value, {bool isRole = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: isRole
                ? (value == 'Owner'
                      ? Colors.deepOrangeAccent
                      : (value == 'Administrador'
                            ? Colors.purpleAccent
                            : const Color(0xFF10B981)))
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
