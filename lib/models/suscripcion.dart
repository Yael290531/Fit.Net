/// Modelo para tipos de suscripción del gimnasio Fit.Net.
///
/// Define los planes disponibles con su precio y duración:
/// - Mensual: $500 MXN, 30 días
/// - Semanal: $150 MXN, 7 días
/// - Diaria:  $80 MXN, 1 día
enum TipoSuscripcion {
  mensual,
  semanal,
  diaria,
}

/// Extensión con helpers para precio, duración y etiquetas.
extension TipoSuscripcionExt on TipoSuscripcion {
  /// Precio en MXN del plan.
  double get precio {
    switch (this) {
      case TipoSuscripcion.mensual:
        return 500.0;
      case TipoSuscripcion.semanal:
        return 150.0;
      case TipoSuscripcion.diaria:
        return 80.0;
    }
  }

  /// Duración del plan en días.
  int get dias {
    switch (this) {
      case TipoSuscripcion.mensual:
        return 30;
      case TipoSuscripcion.semanal:
        return 7;
      case TipoSuscripcion.diaria:
        return 1;
    }
  }

  /// Etiqueta para la UI.
  String get etiqueta {
    switch (this) {
      case TipoSuscripcion.mensual:
        return 'Mensualidad';
      case TipoSuscripcion.semanal:
        return 'Semana';
      case TipoSuscripcion.diaria:
        return 'Día';
    }
  }

  /// Nombre almacenado en BD.
  String get dbValue => name;
}

/// Parsea un string de BD al enum.
TipoSuscripcion parseTipoSuscripcion(String value) {
  switch (value) {
    case 'mensual':
      return TipoSuscripcion.mensual;
    case 'semanal':
      return TipoSuscripcion.semanal;
    case 'diaria':
      return TipoSuscripcion.diaria;
    default:
      return TipoSuscripcion.diaria;
  }
}

/// Calcula la fecha de fin a partir de la fecha de inicio y el tipo.
DateTime calcularFechaFin(DateTime inicio, TipoSuscripcion tipo) {
  return inicio.add(Duration(days: tipo.dias));
}

/// Calcula los días restantes de una suscripción.
/// Retorna 0 si ya expiró.
int calcularDiasRestantes(DateTime fechaFin) {
  final ahora = DateTime.now();
  final diferencia = fechaFin.difference(ahora).inDays;
  return diferencia > 0 ? diferencia : 0;
}

/// Verifica si una suscripción sigue activa.
bool esSuscripcionActiva(DateTime fechaFin) {
  return DateTime.now().isBefore(fechaFin);
}
