/// Modelo de datos para un cliente con tarjeta del gimnasio.
///
/// Representa la tarjeta de acceso de un cliente con su saldo disponible
/// para pagos en las sucursales de la cadena Fit.Net.
class ClienteTarjeta {
  final int idTarjeta;
  final String nombre;
  double saldo;
  final DateTime fechaRegistro;

  ClienteTarjeta({
    required this.idTarjeta,
    required this.nombre,
    required this.saldo,
    DateTime? fechaRegistro,
  }) : fechaRegistro = fechaRegistro ?? DateTime.now();

  /// Factory constructor desde un Map (preparado para BD).
  /// TODO: Conectar con la base de datos de la sucursal (distribución local).
  factory ClienteTarjeta.fromMap(Map<String, dynamic> map) {
    return ClienteTarjeta(
      idTarjeta: map['id_tarjeta'] as int,
      nombre: map['nombre'] as String,
      saldo: (map['saldo'] as num).toDouble(),
      fechaRegistro: map['fecha_registro'] != null
          ? DateTime.parse(map['fecha_registro'] as String)
          : null,
    );
  }

  /// Convierte el objeto a un Map para inserción en BD.
  Map<String, dynamic> toMap() {
    return {
      'id_tarjeta': idTarjeta,
      'nombre': nombre,
      'saldo': saldo,
      'fecha_registro': fechaRegistro.toIso8601String(),
    };
  }

  /// Descuenta saldo de la tarjeta. Retorna true si fue exitoso.
  bool cobrarAcceso(double monto) {
    if (saldo >= monto) {
      saldo -= monto;
      return true;
    }
    return false;
  }

  /// Agrega saldo a la tarjeta.
  void recargar(double monto) {
    saldo += monto;
  }

  @override
  String toString() =>
      'ClienteTarjeta(id: $idTarjeta, nombre: $nombre, saldo: \$${saldo.toStringAsFixed(2)})';
}
