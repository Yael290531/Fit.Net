import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../models/suscripcion.dart';

/// Estructura combinada: Cliente + Tarjeta + Suscripción activa.
/// Usada para la lista de clientes con info de suscripción.
class ClienteConTarjetaYSuscripcion {
  final Cliente cliente;
  final Tarjeta? tarjeta;
  final Suscripcione? suscripcionActiva;

  const ClienteConTarjetaYSuscripcion({
    required this.cliente,
    this.tarjeta,
    this.suscripcionActiva,
  });

  /// Días restantes de la suscripción activa (0 si no hay o expiró).
  int get diasRestantes {
    if (suscripcionActiva == null) return 0;
    return calcularDiasRestantes(suscripcionActiva!.fechaFin);
  }

  /// Indica si la suscripción está activa.
  bool get tieneSuscripcionActiva {
    if (suscripcionActiva == null) return false;
    return esSuscripcionActiva(suscripcionActiva!.fechaFin);
  }
}

/// Repositorio para la gestión de suscripciones.
///
/// Maneja la creación de suscripciones (descuento de saldo + registro
/// de movimiento + sync_queue) y consultas reactivas de suscripciones
/// activas.
class SuscripcionesRepository {
  final AppDatabase _db;
  final String sucursalId;
  final _uuid = const Uuid();

  SuscripcionesRepository(this._db, {required this.sucursalId});

  // ── Streams ────────────────────────────────────────────────────────

  /// Stream de la suscripción activa de un cliente (o null si no tiene).
  Stream<Suscripcione?> watchSuscripcionActiva(String clienteId) {
    final ahora = DateTime.now();
    return (_db.select(_db.suscripciones)
          ..where((s) =>
              s.clienteId.equals(clienteId) &
              s.fechaFin.isBiggerOrEqualValue(ahora))
          ..orderBy([
            (s) => OrderingTerm(
                  expression: s.fechaFin,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Stream reactivo que une Clientes + Tarjetas + Suscripción activa.
  /// Emite cada vez que cambia cualquiera de las 3 tablas.
  Stream<List<ClienteConTarjetaYSuscripcion>> watchClientesConTarjetaYSuscripcion() {
    final query = _db.select(_db.clientes).join([
      leftOuterJoin(
        _db.tarjetas,
        _db.tarjetas.clienteId.equalsExp(_db.clientes.id),
      ),
    ])
      ..where(
        _db.clientes.sucursalId.equals(sucursalId) &
            _db.clientes.deletedAt.isNull(),
      )
      ..orderBy([OrderingTerm(expression: _db.clientes.createdAt)]);

    return query.watch().asyncMap((rows) async {
      final results = <ClienteConTarjetaYSuscripcion>[];
      for (final row in rows) {
        final cliente = row.readTable(_db.clientes);
        final tarjeta = row.readTableOrNull(_db.tarjetas);

        // Buscar suscripción activa para este cliente.
        final suscripcion = await _obtenerSuscripcionActiva(cliente.id);

        results.add(ClienteConTarjetaYSuscripcion(
          cliente: cliente,
          tarjeta: tarjeta,
          suscripcionActiva: suscripcion,
        ));
      }
      return results;
    });
  }

  // ── Lecturas ───────────────────────────────────────────────────────

  /// Obtiene la suscripción activa de un cliente (o null).
  Future<Suscripcione?> _obtenerSuscripcionActiva(String clienteId) async {
    final ahora = DateTime.now();
    return (_db.select(_db.suscripciones)
          ..where((s) =>
              s.clienteId.equals(clienteId) &
              s.fechaFin.isBiggerOrEqualValue(ahora))
          ..orderBy([
            (s) => OrderingTerm(
                  expression: s.fechaFin,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Obtiene la suscripción activa de un cliente (API pública).
  Future<Suscripcione?> obtenerSuscripcionActiva(String clienteId) =>
      _obtenerSuscripcionActiva(clienteId);

  /// Cuenta las suscripciones activas en esta sucursal.
  Future<int> contarSuscripcionesActivas() async {
    final ahora = DateTime.now();
    final activas = await (_db.select(_db.suscripciones)
          ..where((s) =>
              s.sucursalId.equals(sucursalId) &
              s.fechaFin.isBiggerOrEqualValue(ahora)))
        .get();
    return activas.length;
  }

  /// Cuenta las suscripciones que expiran en los próximos N días.
  Future<int> contarPorExpirar({int dias = 3}) async {
    final ahora = DateTime.now();
    final limite = ahora.add(Duration(days: dias));
    final porExpirar = await (_db.select(_db.suscripciones)
          ..where((s) =>
              s.sucursalId.equals(sucursalId) &
              s.fechaFin.isBiggerOrEqualValue(ahora) &
              s.fechaFin.isSmallerThanValue(limite)))
        .get();
    return porExpirar.length;
  }

  // ── Escrituras ─────────────────────────────────────────────────────

  /// Registra una nueva suscripción para un cliente.
  ///
  /// Dentro de una sola transacción ACID:
  ///   1. Busca la tarjeta del cliente.
  ///   2. Verifica saldo suficiente para el tipo de plan.
  ///   3. Descuenta el monto del saldo de la tarjeta.
  ///   4. Crea el registro de suscripción con fecha de inicio y fin.
  ///   5. Crea movimiento financiero (tipo = 'pago').
  ///   6. Registra en sync_queue.
  ///
  /// Lanza [Exception] si no tiene tarjeta o saldo insuficiente.
  Future<String> registrarSuscripcion({
    required String clienteId,
    required TipoSuscripcion tipo,
    String? idTarjeta,
  }) async {
    final suscripcionId = _uuid.v4();

    await _db.transaction(() async {
      // 1. Obtener la tarjeta del cliente.
      Tarjeta? tarjeta;
      if (idTarjeta != null) {
        tarjeta = await (_db.select(_db.tarjetas)
              ..where((t) =>
                  t.idTarjeta.equals(idTarjeta) & t.deletedAt.isNull()))
            .getSingleOrNull();
      } else {
        tarjeta = await (_db.select(_db.tarjetas)
              ..where((t) =>
                  t.clienteId.equals(clienteId) & t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
      }

      if (tarjeta == null) {
        throw Exception('El cliente no tiene tarjeta registrada.');
      }

      final precio = tipo.precio;

      // 2. Verificar saldo suficiente.
      if (tarjeta.saldo < precio) {
        throw Exception(
          'Saldo insuficiente (\$${tarjeta.saldo.toStringAsFixed(2)}) '
          'para ${tipo.etiqueta} de \$${precio.toStringAsFixed(2)}. '
          'Recarga la tarjeta primero.',
        );
      }

      final now = DateTime.now();
      final fechaFin = calcularFechaFin(now, tipo);
      final nuevoSaldo = tarjeta.saldo - precio;

      // 3. Descontar saldo de la tarjeta.
      await (_db.update(_db.tarjetas)
            ..where((t) => t.idTarjeta.equals(tarjeta!.idTarjeta)))
          .write(TarjetasCompanion(
        saldo: Value(nuevoSaldo),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ));

      // 4. Crear registro de suscripción.
      await _db.into(_db.suscripciones).insert(
            SuscripcionesCompanion.insert(
              id: suscripcionId,
              clienteId: clienteId,
              sucursalId: sucursalId,
              tipoSuscripcion: tipo.dbValue,
              montoPagado: precio,
              fechaInicio: now,
              fechaFin: fechaFin,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 5. Crear movimiento financiero.
      final movId = _uuid.v4();
      await _db.into(_db.movimientos).insert(
            MovimientosCompanion.insert(
              id: movId,
              idTarjeta: tarjeta.idTarjeta,
              sucursalId: sucursalId,
              tipo: 'pago',
              monto: precio,
              fecha: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 6. Sync queue – suscripción.
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'suscripcion',
              entityId: suscripcionId,
              operation: 'insert',
              payload: jsonEncode({
                'id': suscripcionId,
                'cliente_id': clienteId,
                'sucursal_id': sucursalId,
                'tipo_suscripcion': tipo.dbValue,
                'monto_pagado': precio,
                'fecha_inicio': now.toIso8601String(),
                'fecha_fin': fechaFin.toIso8601String(),
              }),
              createdAt: now,
            ),
          );

      // 7. Sync queue – movimiento.
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'movimiento',
              entityId: movId,
              operation: 'insert',
              payload: jsonEncode({
                'id': movId,
                'id_tarjeta': tarjeta.idTarjeta,
                'sucursal_id': sucursalId,
                'tipo': 'pago',
                'monto': precio,
                'fecha': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });

    return suscripcionId;
  }
}
