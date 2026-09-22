import 'package:drift/drift.dart';

// ═══════════════════════════════════════════════════════════════════════
// TABLA: cortes_caja
// Registro histórico de turnos y cortes de caja en cada sucursal.
//
// Ideología Fit.Net:
// 1. Un cajero entra a su turno con fondo base de $2,000.00 MXN.
// 2. Durante el turno se registran ventas y transacciones.
// 3. Al corte se cuenta el efectivo, se calcula la diferencia.
// 4. Se retira el total de ventas generadas ("se quita la venta").
// 5. El siguiente turno entra con el mismo fondo base ($2,000.00 MXN).
// ═══════════════════════════════════════════════════════════════════════
class CortesCaja extends Table {
  /// UUID del corte / turno (PK).
  TextColumn get id => text()();

  /// Sucursal a la que pertenece el turno.
  TextColumn get sucursalId => text()();

  /// Nombre de usuario del cajero responsable.
  TextColumn get cajeroUsername => text()();

  /// Fecha y hora en que se abrió el turno.
  DateTimeColumn get fechaApertura => dateTime()();

  /// Fecha y hora en que se realizó el corte (null si el turno está abierto).
  DateTimeColumn get fechaCierre => dateTime().nullable()();

  /// Fondo de caja al abrir el turno (por defecto $2,000.00).
  RealColumn get fondoInicial =>
      real().withDefault(const Constant(2000.0))();

  /// Suma total de ventas generadas durante el turno.
  RealColumn get totalVentas =>
      real().withDefault(const Constant(0.0))();

  /// Total de efectivo esperado en caja = fondoInicial + ventas en efectivo.
  RealColumn get totalEsperado =>
      real().withDefault(const Constant(2000.0))();

  /// Efectivo físico contado por el cajero al hacer el arqueo.
  RealColumn get efectivoContado => real().nullable()();

  /// Diferencia: efectivoContado - totalEsperado (0 = exacto, + sobrante, - faltante).
  RealColumn get diferencia =>
      real().withDefault(const Constant(0.0))();

  /// Monto de venta que se retira de caja ("se quita la venta").
  RealColumn get montoRetirado =>
      real().withDefault(const Constant(0.0))();

  /// Fondo que queda en caja para el siguiente turno ($2,000.00).
  RealColumn get fondoSiguienteTurno =>
      real().withDefault(const Constant(2000.0))();

  /// Cantidad de transacciones/movimientos realizados en el turno.
  IntColumn get totalMovimientos =>
      integer().withDefault(const Constant(0))();

  /// Total recaudado por cobro de suscripciones.
  RealColumn get totalSuscripciones =>
      real().withDefault(const Constant(0.0))();

  /// Total recaudado por recargas de tarjeta.
  RealColumn get totalRecargas =>
      real().withDefault(const Constant(0.0))();

  /// Desglose en formato JSON de las denominaciones de billetes y monedas contadas.
  TextColumn get desgloseJson => text().nullable()();

  /// Observaciones o notas del cajero.
  TextColumn get observaciones => text().nullable()();

  /// Estado del turno: 'abierto' o 'cerrado'.
  TextColumn get estado =>
      text().withDefault(const Constant('abierto'))();

  // ── Campos de auditoría ───────────────────────────────────────────
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
