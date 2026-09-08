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

      // 3. Registrar en sync_queue para futura sincronización.
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
                'tarjeta_id': tarjetaId,
                'saldo_inicial': saldoInicial,
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
}
