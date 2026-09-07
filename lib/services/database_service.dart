import '../models/models.dart';

/// Servicio de base de datos simulada para Fit.Net.
///
/// Esta clase actúa como una capa de abstracción entre la UI y la fuente de datos.
/// Actualmente contiene datos simulados en memoria. Los comentarios TODO indican
/// exactamente dónde se deben integrar las conexiones a bases de datos reales.
///
/// Arquitectura de BD propuesta:
/// ┌─────────────────────────────────────────────────────────┐
/// │  BASE DE DATOS GLOBAL (MySQL/PostgreSQL - Servidor Central)  │
/// │  ─ Tabla: usuarios                                            │
/// │  ─ Tabla: sucursales                                          │
/// │  ─ Vista: ingresos_consolidados                               │
/// └──────────────────┬──────────────────┬───────────────────┘
///                    │                  │
///        ┌───────────┴───┐      ┌───────┴───────────┐
///        │ BD Sucursal    │      │ BD Sucursal       │
///        │ "Centro"       │      │ "Norte"           │
///        │ ─ clientes     │      │ ─ clientes        │
///        │ ─ tarjetas     │      │ ─ tarjetas        │
///        │ ─ movimientos  │      │ ─ movimientos     │
///        └────────────────┘      └───────────────────┘

class DatabaseService {
  // ═══════════════════════════════════════════════════════════════
  // SINGLETON - Instancia única del servicio de base de datos
  // ═══════════════════════════════════════════════════════════════
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal() {
    _initSimulatedData();
  }

  // ═══════════════════════════════════════════════════════════════
  // DATOS SIMULADOS EN MEMORIA
  // TODO: Reemplazar con conexiones reales a MySQL / PostgreSQL
  // usando paquetes como `mysql_client` o `postgres`.
  //
  // Para distribución local, cada sucursal tendría su propia BD.
  // Para integración global, un servidor central consolida datos.
  // ═══════════════════════════════════════════════════════════════

  final List<Usuario> _usuarios = [];
  final Map<String, List<ClienteTarjeta>> _clientesPorSucursal = {};
  final Map<String, List<MovimientoFinanciero>> _movimientosPorSucursal = {};

  int _nextClienteId = 1001;
  int _nextMovimientoId = 1;

  void _initSimulatedData() {
    // ── Usuarios de prueba ──
    _usuarios.addAll([
      const Usuario(
        id: 1,
        username: 'admin',
        password: 'admin123',
        rol: RolUsuario.adminGlobal,
      ),
      const Usuario(
        id: 2,
        username: 'cajero_centro',
        password: 'centro123',
        rol: RolUsuario.cajero,
        sucursalAsignada: 'Sucursal Centro',
      ),
      const Usuario(
        id: 3,
        username: 'cajero_norte',
        password: 'norte123',
        rol: RolUsuario.cajero,
        sucursalAsignada: 'Sucursal Norte',
      ),
    ]);

    // ── Clientes simulados por sucursal ──
    _clientesPorSucursal['Sucursal Centro'] = [
      ClienteTarjeta(idTarjeta: 1001, nombre: 'María García', saldo: 500.0),
      ClienteTarjeta(idTarjeta: 1002, nombre: 'Carlos López', saldo: 320.0),
      ClienteTarjeta(idTarjeta: 1003, nombre: 'Ana Martínez', saldo: 150.0),
    ];
    _clientesPorSucursal['Sucursal Norte'] = [
      ClienteTarjeta(idTarjeta: 2001, nombre: 'Roberto Díaz', saldo: 400.0),
      ClienteTarjeta(idTarjeta: 2002, nombre: 'Laura Sánchez', saldo: 275.0),
    ];

    _nextClienteId = 3001;

    // ── Movimientos simulados del día ──
    final hoy = DateTime.now();
    _movimientosPorSucursal['Sucursal Centro'] = [
      MovimientoFinanciero(
        id: 1, idTarjeta: 1001,
        tipoMovimiento: TipoMovimiento.cobroAcceso,
        monto: 80.0, fecha: hoy, sucursal: 'Sucursal Centro',
      ),
      MovimientoFinanciero(
        id: 2, idTarjeta: 1002,
        tipoMovimiento: TipoMovimiento.cobroAcceso,
        monto: 80.0, fecha: hoy, sucursal: 'Sucursal Centro',
      ),
      MovimientoFinanciero(
        id: 3, idTarjeta: 1003,
        tipoMovimiento: TipoMovimiento.recarga,
        monto: 200.0, fecha: hoy, sucursal: 'Sucursal Centro',
      ),
    ];
    _movimientosPorSucursal['Sucursal Norte'] = [
      MovimientoFinanciero(
        id: 4, idTarjeta: 2001,
        tipoMovimiento: TipoMovimiento.cobroAcceso,
        monto: 80.0, fecha: hoy, sucursal: 'Sucursal Norte',
      ),
      MovimientoFinanciero(
        id: 5, idTarjeta: 2002,
        tipoMovimiento: TipoMovimiento.cobroAcceso,
        monto: 80.0, fecha: hoy, sucursal: 'Sucursal Norte',
      ),
    ];
    _nextMovimientoId = 6;
  }

  // ═══════════════════════════════════════════════════════════════
  // AUTENTICACIÓN
  // TODO: Conectar con tabla `usuarios` en la BD global.
  // Usar hashing (bcrypt) para passwords en producción.
  // ═══════════════════════════════════════════════════════════════

  /// Autentica un usuario por credenciales. Retorna null si no existe.
  Usuario? autenticar(String username, String password) {
    try {
      return _usuarios.firstWhere(
        (u) => u.username == username && u.password == password,
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // OPERACIONES DE CLIENTES (Distribución Local por Sucursal)
  // TODO: Conectar con tabla `clientes_tarjeta` en la BD de cada sucursal.
  // Cada sucursal mantiene su propia BD local para estas operaciones.
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene la lista de clientes de una sucursal.
  List<ClienteTarjeta> obtenerClientes(String sucursal) {
    return List.unmodifiable(_clientesPorSucursal[sucursal] ?? []);
  }

  /// Registra un nuevo cliente en la sucursal.
  ClienteTarjeta registrarCliente(String sucursal, String nombre, double saldoInicial) {
    final cliente = ClienteTarjeta(
      idTarjeta: _nextClienteId++,
      nombre: nombre,
      saldo: saldoInicial,
    );
    _clientesPorSucursal.putIfAbsent(sucursal, () => []);
    _clientesPorSucursal[sucursal]!.add(cliente);
    return cliente;
  }

  /// Busca un cliente por ID de tarjeta en una sucursal.
  ClienteTarjeta? buscarClientePorId(String sucursal, int idTarjeta) {
    final clientes = _clientesPorSucursal[sucursal];
    if (clientes == null) return null;
    try {
      return clientes.firstWhere((c) => c.idTarjeta == idTarjeta);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // OPERACIONES FINANCIERAS (Distribución Local)
  // TODO: Conectar con tabla `movimientos_financieros` en la BD local.
  // Cada transacción debe registrarse con ACID compliance.
  // ═══════════════════════════════════════════════════════════════

  /// Recarga saldo a una tarjeta.
  bool recargarTarjeta(String sucursal, int idTarjeta, double monto) {
    final cliente = buscarClientePorId(sucursal, idTarjeta);
    if (cliente == null || monto <= 0) return false;

    cliente.recargar(monto);

    final movimiento = MovimientoFinanciero(
      id: _nextMovimientoId++,
      idTarjeta: idTarjeta,
      tipoMovimiento: TipoMovimiento.recarga,
      monto: monto,
      fecha: DateTime.now(),
      sucursal: sucursal,
      descripcion: 'Recarga de tarjeta',
    );
    _movimientosPorSucursal.putIfAbsent(sucursal, () => []);
    _movimientosPorSucursal[sucursal]!.add(movimiento);
    return true;
  }

  /// Cobra acceso al gimnasio. Retorna true si el saldo es suficiente.
  bool cobrarAcceso(String sucursal, int idTarjeta, {double costoAcceso = 80.0}) {
    final cliente = buscarClientePorId(sucursal, idTarjeta);
    if (cliente == null) return false;

    if (!cliente.cobrarAcceso(costoAcceso)) return false;

    final movimiento = MovimientoFinanciero(
      id: _nextMovimientoId++,
      idTarjeta: idTarjeta,
      tipoMovimiento: TipoMovimiento.cobroAcceso,
      monto: costoAcceso,
      fecha: DateTime.now(),
      sucursal: sucursal,
      descripcion: 'Cobro de acceso al gimnasio',
    );
    _movimientosPorSucursal.putIfAbsent(sucursal, () => []);
    _movimientosPorSucursal[sucursal]!.add(movimiento);
    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // REPORTES GLOBALES (Integración de Bases de Datos)
  // TODO: Conectar con vista `ingresos_consolidados` en el servidor central.
  // Esta es la parte de INTEGRACIÓN: el servidor central consulta
  // las BDs de todas las sucursales para generar reportes unificados.
  //
  // Opciones de implementación:
  // 1. Replicación de datos a BD central (near real-time)
  // 2. Consultas federadas a múltiples BDs
  // 3. ETL periódico para data warehouse
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene los ingresos de hoy para una sucursal específica.
  double obtenerIngresosHoy(String sucursal) {
    final hoy = DateTime.now();
    final movimientos = _movimientosPorSucursal[sucursal] ?? [];
    return movimientos
        .where((m) =>
            m.esIngreso &&
            m.fecha.year == hoy.year &&
            m.fecha.month == hoy.month &&
            m.fecha.day == hoy.day)
        .fold(0.0, (sum, m) => sum + m.monto);
  }

  /// Obtiene los ingresos totales consolidados de TODAS las sucursales.
  /// Esta es la operación de INTEGRACIÓN GLOBAL.
  double obtenerIngresosTotalesHoy() {
    double total = 0;
    for (final sucursal in _movimientosPorSucursal.keys) {
      total += obtenerIngresosHoy(sucursal);
    }
    return total;
  }

  /// Obtiene un desglose de ingresos por sucursal.
  Map<String, double> obtenerDesglosePorSucursal() {
    final desglose = <String, double>{};
    for (final sucursal in _movimientosPorSucursal.keys) {
      desglose[sucursal] = obtenerIngresosHoy(sucursal);
    }
    return desglose;
  }

  /// Obtiene los movimientos del día de una sucursal.
  List<MovimientoFinanciero> obtenerMovimientosHoy(String sucursal) {
    final hoy = DateTime.now();
    final movimientos = _movimientosPorSucursal[sucursal] ?? [];
    return movimientos
        .where((m) =>
            m.fecha.year == hoy.year &&
            m.fecha.month == hoy.month &&
            m.fecha.day == hoy.day)
        .toList();
  }

  /// Obtiene la lista de todas las sucursales registradas.
  List<String> obtenerSucursales() {
    return _movimientosPorSucursal.keys.toList();
  }

  /// Cuenta total de clientes en una sucursal.
  int contarClientes(String sucursal) {
    return _clientesPorSucursal[sucursal]?.length ?? 0;
  }

  /// Cuenta total de movimientos hoy en una sucursal.
  int contarMovimientosHoy(String sucursal) {
    return obtenerMovimientosHoy(sucursal).length;
  }
}
