/// Modelo de datos para registrar movimientos financieros.
///
/// Cada movimiento registra una transacción en la sucursal:
/// recargas, cobros de acceso, y cualquier otra operación monetaria.
enum TipoMovimiento {
  recarga,
  cobroAcceso,
  compra,
}

class MovimientoFinanciero {
  final int id;
  final int idTarjeta;
  final TipoMovimiento tipoMovimiento;
  final double monto;
  final DateTime fecha;
  final String? sucursal;
  final String? descripcion;

  const MovimientoFinanciero({
    required this.id,
    required this.idTarjeta,
    required this.tipoMovimiento,
    required this.monto,
    required this.fecha,
    this.sucursal,
    this.descripcion,
  });

  /// Factory constructor desde un Map (preparado para BD).
  /// TODO: Conectar con la base de datos distribuida para integración global.
  factory MovimientoFinanciero.fromMap(Map<String, dynamic> map) {
    return MovimientoFinanciero(
      id: map['id'] as int,
      idTarjeta: map['id_tarjeta'] as int,
      tipoMovimiento: _parseTipo(map['tipo_movimiento'] as String),
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
      sucursal: map['sucursal'] as String?,
      descripcion: map['descripcion'] as String?,
    );
  }

  /// Convierte el objeto a un Map para inserción en BD.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_tarjeta': idTarjeta,
      'tipo_movimiento': tipoMovimiento.name,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'sucursal': sucursal,
      'descripcion': descripcion,
    };
  }

  static TipoMovimiento _parseTipo(String tipo) {
    switch (tipo) {
      case 'recarga':
        return TipoMovimiento.recarga;
      case 'cobroAcceso':
        return TipoMovimiento.cobroAcceso;
      case 'compra':
        return TipoMovimiento.compra;
      default:
        return TipoMovimiento.cobroAcceso;
    }
  }

  /// Indica si el movimiento genera ingreso (para reportes globales).
  bool get esIngreso =>
      tipoMovimiento == TipoMovimiento.cobroAcceso ||
      tipoMovimiento == TipoMovimiento.compra;

  @override
  String toString() =>
      'Movimiento(id: $id, tarjeta: $idTarjeta, tipo: ${tipoMovimiento.name}, monto: \$${monto.toStringAsFixed(2)})';
}
