import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

/// Repositorio para operaciones sobre tarjetas y movimientos financieros.
///
/// Las operaciones de recarga y pago son transacciones ACID completas:
/// si cualquier paso falla, el saldo y el movimiento se revierten juntos.
class TarjetasRepository {
  final AppDatabase _db;
  final String sucursalId;
  final _uuid = const Uuid();

  TarjetasRepository(this._db, {required this.sucursalId});

  // ── Streams ────────────────────────────────────────────────────────
  /// Stream de la tarjeta por su UUID.
  Stream<Tarjeta?> watchTarjeta(String idTarjeta) {
    return (_db.select(_db.tarjetas)
          ..where((t) => t.idTarjeta.equals(idTarjeta)))
        .watchSingleOrNull();
  }

  // ── Lecturas ───────────────────────────────────────────────────────
  /// Devuelve la tarjeta por UUID completo o ID corto (prefijo), o null si no existe.
  /// No restringe por sucursal para permitir que cualquier cliente registrado
  /// localmente pueda recargar o cobrar acceso de inmediato en esta sucursal.
  Future<Tarjeta?> buscarTarjetaPorId(String idTarjeta) async {
    final cleanId = idTarjeta.trim();
    if (cleanId.isEmpty) return null;

    // 1. Búsqueda exacta por UUID
    var tarjeta = await (_db.select(_db.tarjetas)
          ..where((t) => t.idTarjeta.equals(cleanId) & t.deletedAt.isNull()))
        .getSingleOrNull();

    // 2. Si no se encuentra y tiene al menos 4 caracteres, buscar por prefijo (ID corto)
    if (tarjeta == null && cleanId.length >= 4) {
      final matches = await (_db.select(_db.tarjetas)
            ..where((t) => t.idTarjeta.like('$cleanId%') & t.deletedAt.isNull())
            ..limit(1))
          .get();
      if (matches.isNotEmpty) {
        tarjeta = matches.first;
      }
    }

    return tarjeta;
  }

  /// Devuelve todas las tarjetas activas de la sucursal.
  Future<List<Tarjeta>> obtenerTarjetas() async {
    return (_db.select(_db.tarjetas)
          ..where(
            (t) =>
                t.sucursalId.equals(sucursalId) & t.deletedAt.isNull(),
          ))
        .get();
  }

  // ── Operaciones financieras ────────────────────────────────────────

  /// RECARGA: Aumenta el saldo de la tarjeta.
  ///
  /// Dentro de una sola transacción:
  ///   1. Verifica que la tarjeta exista en esta sucursal.
  ///   2. Valida que el monto sea > 0.
  ///   3. Aumenta el saldo.
  ///   4. Crea el movimiento (tipo = 'recarga').
  ///   5. Agrega entrada en sync_queue.
  ///
  /// Lanza [Exception] si la tarjeta no existe o el monto es inválido.
  Future<void> recargarTarjeta(String idTarjeta, double monto) async {
    if (monto <= 0) throw Exception('El monto debe ser mayor que cero.');

    await _db.transaction(() async {
      final tarjeta = await buscarTarjetaPorId(idTarjeta);
      if (tarjeta == null) {
        throw Exception('Tarjeta "$idTarjeta" no encontrada.');
      }

      final resolvedId = tarjeta.idTarjeta;
      final now = DateTime.now();
      final nuevoSaldo = tarjeta.saldo + monto;

      // 3. Actualizar saldo localmente en la base de datos de inmediato.
      await (_db.update(_db.tarjetas)
            ..where((t) => t.idTarjeta.equals(resolvedId)))
          .write(TarjetasCompanion(
        saldo: Value(nuevoSaldo),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ));

      // 4. Crear movimiento financiero en esta sucursal.
      final movId = _uuid.v4();
      await _db.into(_db.movimientos).insert(
            MovimientosCompanion.insert(
              id: movId,
              idTarjeta: resolvedId,
              sucursalId: sucursalId,
              tipo: 'recarga',
              monto: monto,
              fecha: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 5. Sync queue (registro para cuando exista Supabase, no bloquea la operación local).
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'movimiento',
              entityId: movId,
              operation: 'insert',
              payload: jsonEncode({
                'id': movId,
                'id_tarjeta': resolvedId,
                'sucursal_id': sucursalId,
                'tipo': 'recarga',
                'monto': monto,
                'fecha': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  /// PAGO (cobro de acceso): Descuenta el saldo de la tarjeta de forma inmediata y local.
  ///
  /// Dentro de una sola transacción ACID local:
  ///   1. Verifica que la tarjeta exista localmente.
  ///   2. Valida que el monto sea > 0.
  ///   3. Verifica saldo suficiente.
  ///   4. Descuenta el saldo inmediatamente.
  ///   5. Crea el movimiento (tipo = 'pago').
  ///   6. Registra en sync_queue en segundo plano.
  ///
  /// Lanza [Exception] si la tarjeta no existe, monto inválido o saldo insuficiente.
  Future<void> cobrarAcceso(String idTarjeta, double costo) async {
    if (costo <= 0) throw Exception('El costo debe ser mayor que cero.');

    await _db.transaction(() async {
      final tarjeta = await buscarTarjetaPorId(idTarjeta);
      if (tarjeta == null) {
        throw Exception('Tarjeta "$idTarjeta" no encontrada.');
      }
      if (tarjeta.saldo < costo) {
        throw Exception(
          'Saldo insuficiente (\$${tarjeta.saldo.toStringAsFixed(2)}) '
          'para el cobro de \$${costo.toStringAsFixed(2)}.',
        );
      }

      final resolvedId = tarjeta.idTarjeta;
      final now = DateTime.now();
      final nuevoSaldo = tarjeta.saldo - costo;

      // 4. Actualizar saldo inmediatamente en local.
      await (_db.update(_db.tarjetas)
            ..where((t) => t.idTarjeta.equals(resolvedId)))
          .write(TarjetasCompanion(
        saldo: Value(nuevoSaldo),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ));

      // 5. Crear movimiento local.
      final movId = _uuid.v4();
      await _db.into(_db.movimientos).insert(
            MovimientosCompanion.insert(
              id: movId,
              idTarjeta: resolvedId,
              sucursalId: sucursalId,
              tipo: 'pago',
              monto: costo,
              fecha: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 6. Sync queue.
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'movimiento',
              entityId: movId,
              operation: 'insert',
              payload: jsonEncode({
                'id': movId,
                'id_tarjeta': resolvedId,
                'sucursal_id': sucursalId,
                'tipo': 'pago',
                'monto': costo,
                'fecha': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }
}
