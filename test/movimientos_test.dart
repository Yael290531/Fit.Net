import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_net/core/database/app_database.dart';
import 'package:fit_net/data/repositories/movimientos_repository.dart';

void main() {
  late AppDatabase db;
  late MovimientosRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MovimientosRepository(db, sucursalId: 'Sucursal Centro');
  });

  tearDown(() async {
    await db.close();
  });

  test('watchMovimientosConDetalle emite movimientos con cliente y tarjeta', () async {
    final now = DateTime.now();

    // 1. Insertar cliente
    await db.into(db.clientes).insert(
      ClientesCompanion.insert(
        id: 'cli-1',
        nombre: 'Carlos Ruiz',
        sucursalId: 'Sucursal Centro',
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 2. Insertar tarjeta asociada
    await db.into(db.tarjetas).insert(
      TarjetasCompanion.insert(
        idTarjeta: 'card-1234-abcd',
        clienteId: 'cli-1',
        sucursalId: 'Sucursal Centro',
        saldo: const Value(250.0),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 3. Insertar movimiento
    await db.into(db.movimientos).insert(
      MovimientosCompanion.insert(
        id: 'mov-1',
        idTarjeta: 'card-1234-abcd',
        sucursalId: 'Sucursal Centro',
        tipo: 'recarga',
        monto: 250.0,
        fecha: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 4. Verificar consulta reactiva
    final result = await repo.watchMovimientosConDetalle().first;

    expect(result.length, equals(1));
    expect(result.first.movimiento.id, equals('mov-1'));
    expect(result.first.movimiento.monto, equals(250.0));
    expect(result.first.movimiento.tipo, equals('recarga'));
    expect(result.first.cliente?.nombre, equals('Carlos Ruiz'));
    expect(result.first.tarjeta?.idTarjeta, equals('card-1234-abcd'));
  });
}
