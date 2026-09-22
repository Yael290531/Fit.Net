import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_net/core/database/app_database.dart';
import 'package:fit_net/data/repositories/cortes_repository.dart';
import 'package:fit_net/services/corte_pdf_service.dart';

void main() {
  late AppDatabase db;
  late CortesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CortesRepository(db, sucursalId: 'Sucursal Centro');
  });

  tearDown(() async {
    await db.close();
  });

  test('Flujo completo de Corte de Caja: fondo \$2,000, ventas, arqueo, retiro y PDF',
      () async {
    final now = DateTime.now();

    // 1. Iniciar Turno con fondo base de $2,000.00 MXN
    final turnoInicial = await repo.iniciarTurno(
      cajeroUsername: 'cajero_centro',
      fondoInicial: 2000.0,
    );

    // Ajustar fecha de apertura a 30 minutos en el pasado para la prueba
    final apertura = now.subtract(const Duration(minutes: 30));
    await (db.update(db.cortesCaja)..where((t) => t.id.equals(turnoInicial.id)))
        .write(CortesCajaCompanion(fechaApertura: Value(apertura)));

    final turno = (await (db.select(db.cortesCaja)
          ..where((t) => t.id.equals(turnoInicial.id)))
        .getSingle());

    expect(turno.cajeroUsername, equals('cajero_centro'));
    expect(turno.fondoInicial, equals(2000.0));
    expect(turno.estado, equals('abierto'));
    expect(turno.totalVentas, equals(0.0));

    // 2. Simular cliente, tarjeta y movimientos durante el turno
    await db.into(db.clientes).insert(
      ClientesCompanion.insert(
        id: 'cli-test',
        nombre: 'Juan Pérez',
        sucursalId: 'Sucursal Centro',
        createdAt: apertura,
        updatedAt: apertura,
      ),
    );

    await db.into(db.tarjetas).insert(
      TarjetasCompanion.insert(
        idTarjeta: 'card-test-1',
        clienteId: 'cli-test',
        sucursalId: 'Sucursal Centro',
        saldo: const Value(500.0),
        createdAt: apertura,
        updatedAt: apertura,
      ),
    );

    // Movimiento 1: Recarga en efectivo de $500 ocurrida hace 20 minutos
    await db.into(db.movimientos).insert(
      MovimientosCompanion.insert(
        id: 'mov-recarga-1',
        idTarjeta: 'card-test-1',
        sucursalId: 'Sucursal Centro',
        tipo: 'recarga',
        monto: 500.0,
        fecha: now.subtract(const Duration(minutes: 20)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Movimiento 2: Cobro de suscripción de $150 ocurrida hace 10 minutos
    await db.into(db.movimientos).insert(
      MovimientosCompanion.insert(
        id: 'mov-pago-1',
        idTarjeta: 'card-test-1',
        sucursalId: 'Sucursal Centro',
        tipo: 'pago',
        monto: 150.0,
        fecha: now.subtract(const Duration(minutes: 10)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 3. Consultar Resumen de Turno en Vivo
    final resumen = await repo.obtenerResumenTurno(turno);
    expect(resumen.fondoInicial, equals(2000.0));
    expect(resumen.totalRecargas, equals(500.0)); // Efectivo físico en gaveta
    expect(resumen.totalSuscripciones, equals(150.0)); // Cobrado vía saldo tarjeta
    expect(resumen.totalVentas, equals(500.0)); // Ventas en efectivo de gaveta
    expect(resumen.totalEsperado, equals(2500.0)); // $2,000 fondo + $500 recarga
    expect(resumen.totalTransacciones, equals(2));

    // 4. Realizar Corte: Arqueo con $2,500 contados en gaveta (exacto)
    final corteCerrado = await repo.realizarCorte(
      turnoId: turno.id,
      efectivoContado: 2500.0,
      fondoSiguienteTurno: 2000.0,
      desgloseJson: '{"\$500": 5}',
      observaciones: 'Turno sin incidencias. Caja cuadrada.',
    );

    expect(corteCerrado.estado, equals('cerrado'));
    expect(corteCerrado.totalVentas, equals(500.0));
    expect(corteCerrado.totalEsperado, equals(2500.0));
    expect(corteCerrado.efectivoContado, equals(2500.0));
    expect(corteCerrado.diferencia, equals(0.0));

    // "Se quita la venta": el monto retirado de gaveta es $500.00
    expect(corteCerrado.montoRetirado, equals(500.0));

    // "El siguiente turno entra con el mismo fondo": $2,000.00
    expect(corteCerrado.fondoSiguienteTurno, equals(2000.0));

    // 5. Generar PDF oficial
    final pdfBytes = await CortePdfService.generarReporteCorte(
      corte: corteCerrado,
      resumen: resumen,
    );

    expect(pdfBytes, isNotEmpty);
    // Verificar encabezado mágico PDF
    final headerStr = String.fromCharCodes(pdfBytes.take(5));
    expect(headerStr, equals('%PDF-'));
  });

  test('watchResumenTurno emite actualizaciones reactivas al registrar movimientos al momento',
      () async {
    final turno = await repo.iniciarTurno(
      cajeroUsername: 'cajero_stream',
      fondoInicial: 2000.0,
    );

    // Escuchar el stream
    final stream = repo.watchResumenTurno(turno);
    final primerResumen = await stream.first;
    expect(primerResumen.totalRecargas, equals(0.0));
    expect(primerResumen.totalEsperado, equals(2000.0));

    // Insertar un nuevo cliente, tarjeta y movimiento al momento
    final now = DateTime.now();
    await db.into(db.clientes).insert(
      ClientesCompanion.insert(
        id: 'cli-live-1',
        nombre: 'Cliente En Vivo',
        sucursalId: 'Sucursal Centro',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.into(db.tarjetas).insert(
      TarjetasCompanion.insert(
        idTarjeta: 'card-live-1',
        clienteId: 'cli-live-1',
        sucursalId: 'Sucursal Centro',
        saldo: const Value(300.0),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.into(db.movimientos).insert(
      MovimientosCompanion.insert(
        id: 'mov-live-1',
        idTarjeta: 'card-live-1',
        sucursalId: 'Sucursal Centro',
        tipo: 'recarga',
        monto: 300.0,
        fecha: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // El stream debe reflejar el movimiento al momento
    final segundoResumen = await stream.firstWhere((r) => r.totalRecargas == 300.0);
    expect(segundoResumen.totalRecargas, equals(300.0));
    expect(segundoResumen.totalEsperado, equals(2300.0));
  });

  test('Validar prevención de apertura múltiple simultánea en la misma sucursal',
      () async {
    // Abrir primer turno
    await repo.iniciarTurno(
      cajeroUsername: 'cajero_1',
      fondoInicial: 2000.0,
    );

    // Intentar abrir con otro cajero sin cerrar el primero debe lanzar excepción
    expect(
      () => repo.iniciarTurno(
        cajeroUsername: 'cajero_2',
        fondoInicial: 2000.0,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
