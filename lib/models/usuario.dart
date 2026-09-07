/// Modelo de datos para representar un usuario del sistema Fit.Net.
///
/// Cada usuario tiene un rol que determina su nivel de acceso:
/// - [RolUsuario.adminGlobal]: Acceso al dashboard administrativo global.
/// - [RolUsuario.cajero]: Acceso al dashboard de operación por sucursal.

enum RolUsuario {
  adminGlobal,
  cajero,
}

class Usuario {
  final int id;
  final String username;
  final String password;
  final RolUsuario rol;
  final String? sucursalAsignada; // Solo para cajeros

  const Usuario({
    required this.id,
    required this.username,
    required this.password,
    required this.rol,
    this.sucursalAsignada,
  });

  /// Factory constructor para crear un Usuario desde un Map (preparado para BD).
  /// TODO: Conectar con la base de datos real (MySQL / PostgreSQL).
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int,
      username: map['username'] as String,
      password: map['password'] as String,
      rol: map['rol'] == 'ADMIN_GLOBAL'
          ? RolUsuario.adminGlobal
          : RolUsuario.cajero,
      sucursalAsignada: map['sucursal_asignada'] as String?,
    );
  }

  /// Convierte el objeto a un Map para inserción en BD.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'rol': rol == RolUsuario.adminGlobal ? 'ADMIN_GLOBAL' : 'CAJERO',
      'sucursal_asignada': sucursalAsignada,
    };
  }

  @override
  String toString() =>
      'Usuario(id: $id, username: $username, rol: ${rol.name})';
}
