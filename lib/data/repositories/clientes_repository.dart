import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

/// Estructura combinada de Cliente y su Tarjeta para consultas reactivas instantáneas.
class ClienteConTarjeta {
  final Cliente cliente;
  final Tarjeta? tarjeta;

  const ClienteConTarjeta({
    required this.cliente,
    this.tarjeta,
  });
}

/// Repositorio para la gestión de clientes.
///
/// Filtra siempre por [sucursalId] para garantizar separación de datos.
/// Todos los writes crean una entrada en [SyncQueue] con status 'pending'.
class ClientesRepository {
  final AppDatabase _db;
  final String sucursalId;
  final _uuid = const Uuid();

  ClientesRepository(this._db, {required this.sucursalId});

  // ── Streams ────────────────────────────────────────────────────────
  /// Stream de todos los clientes activos (sin soft-delete) de la sucursal.
  Stream<List<Cliente>> watchClientes() {
    return (_db.select(_db.clientes)
          ..where((t) => t.sucursalId.equals(sucursalId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  /// Stream reactivo que une Clientes y Tarjetas.
  /// Cualquier cambio en saldo (recarga o cobro) en la tabla [tarjetas]
  /// emite de inmediato la nueva información en milisegundos.
  Stream<List<ClienteConTarjeta>> watchClientesConTarjeta() {
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

    return query.watch().map((rows) {
      return rows.map((row) {
        return ClienteConTarjeta(
          cliente: row.readTable(_db.clientes),
          tarjeta: row.readTableOrNull(_db.tarjetas),
        );
      }).toList();
    });
  }

  // ── Lecturas ───────────────────────────────────────────────────────
  /// Devuelve la lista actual de clientes (sin stream).
  Future<List<Cliente>> obtenerClientes() async {
    return (_db.select(
          _db.clientes,
        )..where((t) => t.sucursalId.equals(sucursalId) & t.deletedAt.isNull()))
        .get();
  }

  /// Busca un cliente por el ID de su tarjeta (texto UUID).
  Future<Cliente?> buscarClientePorIdTarjeta(String idTarjeta) async {
    final tarjeta = await (_db.select(
      _db.tarjetas,
    )..where((t) => t.idTarjeta.equals(idTarjeta))).getSingleOrNull();
    if (tarjeta == null) return null;
    return (_db.select(
      _db.clientes,
    )..where((t) => t.id.equals(tarjeta.clienteId))).getSingleOrNull();
  }

  // ── Escrituras ─────────────────────────────────────────────────────
  /// Registra un nuevo cliente y crea su tarjeta con [saldoInicial].
  /// Devuelve el UUID de la tarjeta creada.
  /// Toda la operación ocurre en una única transacción Drift.
  Future<String> registrarCliente({
    required String nombre,
    String? telefono,
    required double saldoInicial,
  }) async {
    final now = DateTime.now();
    final clienteId = _uuid.v4();
    final tarjetaId = _uuid.v4();

    await _db.transaction(() async {
      // 1. Insertar cliente.
      await _db
          .into(_db.clientes)
          .insert(
            ClientesCompanion.insert(
              id: clienteId,
              nombre: nombre,
              telefono: Value(telefono),
              sucursalId: sucursalId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Insertar tarjeta con saldo inicial.
      await _db
          .into(_db.tarjetas)
          .insert(
            TarjetasCompanion.insert(
              idTarjeta: tarjetaId,
              clienteId: clienteId,
              saldo: Value(saldoInicial),
              sucursalId: sucursalId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 3. Registrar cliente en sync_queue.
      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'cliente',
              entityId: clienteId,
              operation: 'insert',
              payload: jsonEncode({
                'id': clienteId,
                'nombre': nombre,
                'telefono': telefono,
                'sucursal_id': sucursalId,
              }),
              createdAt: now,
            ),
          );

      // 4. Registrar tarjeta en sync_queue.
      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'tarjeta',
              entityId: tarjetaId,
              operation: 'insert',
              payload: jsonEncode({
                'id_tarjeta': tarjetaId,
                'cliente_id': clienteId,
                'saldo': saldoInicial,
                'sucursal_id': sucursalId,
              }),
              createdAt: now,
            ),
          );
    });

    return tarjetaId;
  }

  /// Cuenta clientes activos en la sucursal.
  Future<int> contarClientes() async {
    final list = await obtenerClientes();
    return list.length;
  }

  // ── Edición de clientes ───────────────────────────────────────────

  /// Actualiza los datos de un cliente (nombre y/o teléfono).
  /// Solo modifica los campos proporcionados.
  Future<void> editarCliente(
    String clienteId, {
    String? nombre,
    String? telefono,
  }) async {
    final now = DateTime.now();

    await _db.transaction(() async {
      // 1. Verificar que el cliente existe y pertenece a esta sucursal.
      final cliente = await (_db.select(_db.clientes)
            ..where((t) =>
                t.id.equals(clienteId) &
                t.sucursalId.equals(sucursalId) &
                t.deletedAt.isNull()))
          .getSingleOrNull();

      if (cliente == null) {
        throw Exception('Cliente no encontrado en esta sucursal.');
      }

      // 2. Construir los campos a actualizar.
      final updates = ClientesCompanion(
        nombre: nombre != null ? Value(nombre) : const Value.absent(),
        telefono: telefono != null ? Value(telefono) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      );

      await (_db.update(_db.clientes)
            ..where((t) => t.id.equals(clienteId)))
          .write(updates);

      // 3. Registrar en sync_queue.
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'cliente',
              entityId: clienteId,
              operation: 'update',
              payload: jsonEncode({
                'id': clienteId,
                'nombre': ?nombre,
                'telefono': ?telefono,
                'sucursal_id': sucursalId,
                'updated_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  // ── Eliminación de clientes (soft-delete) ─────────────────────────

  /// Marca un cliente como eliminado (soft-delete).
  /// El cliente desaparece de las listas pero sus datos persisten
  /// para integridad referencial con movimientos y tarjetas.
  ///
  /// A los 20 días sin movimientos, [limpiarClientesInactivos] lo
  /// eliminará físicamente.
  Future<void> eliminarCliente(String clienteId) async {
    final now = DateTime.now();

    await _db.transaction(() async {
      // 1. Verificar que el cliente existe.
      final cliente = await (_db.select(_db.clientes)
            ..where((t) =>
                t.id.equals(clienteId) &
                t.sucursalId.equals(sucursalId) &
                t.deletedAt.isNull()))
          .getSingleOrNull();

      if (cliente == null) {
        throw Exception('Cliente no encontrado.');
      }

      // 2. Soft-delete del cliente.
      await (_db.update(_db.clientes)
            ..where((t) => t.id.equals(clienteId)))
          .write(ClientesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ));

      // 3. Soft-delete de la tarjeta asociada.
      await (_db.update(_db.tarjetas)
            ..where((t) => t.clienteId.equals(clienteId)))
          .write(TarjetasCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ));

      // 4. Registrar en sync_queue.
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'cliente',
              entityId: clienteId,
              operation: 'delete',
              payload: jsonEncode({
                'id': clienteId,
                'sucursal_id': sucursalId,
                'deleted_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  // ── Limpieza de clientes inactivos (hard-delete) ──────────────────

  /// Elimina físicamente los clientes que fueron soft-deleted hace más
  /// de [diasInactivos] días y no han tenido ningún movimiento desde
  /// entonces.
  ///
  /// Esto evita que la BD se sature con datos basura.
  /// Se recomienda llamar este método al iniciar la app o periódicamente.
  Future<int> limpiarClientesInactivos({int diasInactivos = 20}) async {
    final limite = DateTime.now().subtract(Duration(days: diasInactivos));
    int eliminados = 0;

    // Obtener clientes soft-deleted hace más de N días.
    final clientesBorrados = await (_db.select(_db.clientes)
          ..where((t) =>
              t.sucursalId.equals(sucursalId) &
              t.deletedAt.isNotNull() &
              t.deletedAt.isSmallerOrEqualValue(limite)))
        .get();

    for (final cliente in clientesBorrados) {
      // Verificar si tiene movimientos recientes (post soft-delete).
      final tarjetas = await (_db.select(_db.tarjetas)
            ..where((t) => t.clienteId.equals(cliente.id)))
          .get();

      bool tieneMovimientosRecientes = false;
      for (final tarjeta in tarjetas) {
        final movimientos = await (_db.select(_db.movimientos)
              ..where((m) =>
                  m.idTarjeta.equals(tarjeta.idTarjeta) &
                  m.fecha.isBiggerOrEqualValue(cliente.deletedAt!))
              ..limit(1))
            .get();
        if (movimientos.isNotEmpty) {
          tieneMovimientosRecientes = true;
          break;
        }
      }

      if (!tieneMovimientosRecientes) {
        // Hard-delete: eliminar movimientos, tarjetas, suscripciones y cliente.
        await _db.transaction(() async {
          for (final tarjeta in tarjetas) {
            await (_db.delete(_db.movimientos)
                  ..where((m) => m.idTarjeta.equals(tarjeta.idTarjeta)))
                .go();
          }
          await (_db.delete(_db.suscripciones)
                ..where((s) => s.clienteId.equals(cliente.id)))
              .go();
          await (_db.delete(_db.tarjetas)
                ..where((t) => t.clienteId.equals(cliente.id)))
              .go();
          await (_db.delete(_db.clientes)
                ..where((c) => c.id.equals(cliente.id)))
              .go();
        });
        eliminados++;
      }
    }

    return eliminados;
  }
}
