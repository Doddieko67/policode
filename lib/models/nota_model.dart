import 'package:equatable/equatable.dart';

class Nota extends Equatable {
  final String id;
  final String userId;
  final String articuloId;
  final DateTime fechaGuardado;
  final DateTime? fechaModificacion;
  final String? comentarioUsuario;
  final List<String> etiquetas;
  final bool esFavorita;
  final bool esArchivada;
  final int? prioridad; // 1 = alta, 2 = media, 3 = baja
  final String? recordatorio; // Texto de recordatorio específico

  const Nota({
    required this.id,
    required this.userId,
    required this.articuloId,
    required this.fechaGuardado,
    this.fechaModificacion,
    this.comentarioUsuario,
    this.etiquetas = const [],
    this.esFavorita = false,
    this.esArchivada = false,
    this.prioridad,
    this.recordatorio,
  });

  // Factory constructor para crear nueva nota
  factory Nota.nueva({
    required String userId,
    required String articuloId,
    String? comentarioUsuario,
    List<String>? etiquetas,
    bool esFavorita = false,
    int? prioridad,
    String? recordatorio,
  }) {
    return Nota(
      id: _generarId(),
      userId: userId,
      articuloId: articuloId,
      fechaGuardado: DateTime.now(),
      comentarioUsuario: comentarioUsuario,
      etiquetas: etiquetas ?? [],
      esFavorita: esFavorita,
      prioridad: prioridad,
      recordatorio: recordatorio,
    );
  }

  // Factory constructor para crear desde JSON (Firestore)
  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      articuloId: json['articulo_id'] as String,
      fechaGuardado: DateTime.parse(json['fecha_guardado']),
      fechaModificacion: json['fecha_modificacion'] != null
          ? DateTime.parse(json['fecha_modificacion'])
          : null,
      comentarioUsuario: json['comentario_usuario'] as String?,
      etiquetas: List<String>.from(json['etiquetas'] ?? []),
      esFavorita: json['es_favorita'] ?? false,
      esArchivada: json['es_archivada'] ?? false,
      prioridad: json['prioridad'] as int?,
      recordatorio: json['recordatorio'] as String?,
    );
  }

  // Método para convertir a JSON (Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'articulo_id': articuloId,
      'fecha_guardado': fechaGuardado.toIso8601String(),
      'fecha_modificacion': fechaModificacion?.toIso8601String(),
      'comentario_usuario': comentarioUsuario,
      'etiquetas': etiquetas,
      'es_favorita': esFavorita,
      'es_archivada': esArchivada,
      'prioridad': prioridad,
      'recordatorio': recordatorio,
    };
  }

  // CopyWith para crear copias modificadas
  Nota copyWith({
    String? id,
    String? userId,
    String? articuloId,
    DateTime? fechaGuardado,
    DateTime? fechaModificacion,
    String? comentarioUsuario,
    List<String>? etiquetas,
    bool? esFavorita,
    bool? esArchivada,
    int? prioridad,
    String? recordatorio,
  }) {
    return Nota(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      articuloId: articuloId ?? this.articuloId,
      fechaGuardado: fechaGuardado ?? this.fechaGuardado,
      fechaModificacion: fechaModificacion ?? DateTime.now(),
      comentarioUsuario: comentarioUsuario ?? this.comentarioUsuario,
      etiquetas: etiquetas ?? this.etiquetas,
      esFavorita: esFavorita ?? this.esFavorita,
      esArchivada: esArchivada ?? this.esArchivada,
      prioridad: prioridad ?? this.prioridad,
      recordatorio: recordatorio ?? this.recordatorio,
    );
  }

  // Getters útiles

  /// Verificar si la nota tiene contenido personalizado
  bool get tieneContenidoPersonalizado {
    return comentarioUsuario != null && comentarioUsuario!.trim().isNotEmpty ||
        recordatorio != null && recordatorio!.trim().isNotEmpty ||
        etiquetas.isNotEmpty;
  }

  /// Verificar si es una nota reciente (último mes)
  bool get esReciente {
    final diferencia = DateTime.now().difference(fechaGuardado);
    return diferencia.inDays <= 30;
  }

  /// Verificar si fue modificada
  bool get fueModificada {
    return fechaModificacion != null;
  }

  /// Tiempo desde que se guardó
  Duration get tiempoDesdeGuardado {
    return DateTime.now().difference(fechaGuardado);
  }

  /// Tiempo desde la última modificación
  Duration? get tiempoDesdeModificacion {
    return fechaModificacion != null
        ? DateTime.now().difference(fechaModificacion!)
        : null;
  }

  /// Texto completo para búsquedas
  String get textoCompleto {
    return [
      comentarioUsuario ?? '',
      recordatorio ?? '',
      etiquetas.join(' '),
    ].where((t) => t.isNotEmpty).join(' ').toLowerCase();
  }

  // Métodos de utilidad

  /// Actualizar comentario
  Nota actualizarComentario(String? nuevoComentario) {
    return copyWith(
      comentarioUsuario: nuevoComentario,
      fechaModificacion: DateTime.now(),
    );
  }

  /// Actualizar recordatorio
  Nota actualizarRecordatorio(String? nuevoRecordatorio) {
    return copyWith(
      recordatorio: nuevoRecordatorio,
      fechaModificacion: DateTime.now(),
    );
  }

  /// Agregar etiqueta
  Nota agregarEtiqueta(String etiqueta) {
    if (etiquetas.contains(etiqueta)) return this;

    final nuevasEtiquetas = List<String>.from(etiquetas)..add(etiqueta);
    return copyWith(
      etiquetas: nuevasEtiquetas,
      fechaModificacion: DateTime.now(),
    );
  }

  /// Remover etiqueta
  Nota removerEtiqueta(String etiqueta) {
    final nuevasEtiquetas = List<String>.from(etiquetas)..remove(etiqueta);
    return copyWith(
      etiquetas: nuevasEtiquetas,
      fechaModificacion: DateTime.now(),
    );
  }

  /// Alternar favorita
  Nota alternarFavorita() {
    return copyWith(esFavorita: !esFavorita, fechaModificacion: DateTime.now());
  }

  /// Alternar archivada
  Nota alternarArchivada() {
    return copyWith(
      esArchivada: !esArchivada,
      fechaModificacion: DateTime.now(),
    );
  }

  /// Actualizar prioridad
  Nota actualizarPrioridad(int? nuevaPrioridad) {
    return copyWith(
      prioridad: nuevaPrioridad,
      fechaModificacion: DateTime.now(),
    );
  }

  /// Verificar si coincide con una búsqueda
  bool coincideCon(String consulta) {
    if (consulta.trim().isEmpty) return true;

    final consultaLimpia = consulta.toLowerCase();
    return textoCompleto.contains(consultaLimpia);
  }

  // Método estático para generar ID único
  static String _generarId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    articuloId,
    fechaGuardado,
    fechaModificacion,
    comentarioUsuario,
    etiquetas,
    esFavorita,
    esArchivada,
    prioridad,
    recordatorio,
  ];

  @override
  String toString() {
    return 'Nota(id: $id, articuloId: $articuloId, esFavorita: $esFavorita)';
  }
}

// Enums para organizar notas
enum TipoOrdenNota { fechaGuardado, fechaModificacion, prioridad, alfabetico }

enum FiltroCategoriaNotas {
  todas,
  favoritas,
  archivadas,
  recientes,
  conComentarios,
  conEtiquetas,
}

// Extensión para trabajar con listas de notas
extension NotaListExtension on List<Nota> {
  /// Filtrar notas activas (no archivadas)
  List<Nota> get activas => where((nota) => !nota.esArchivada).toList();

  /// Filtrar notas favoritas
  List<Nota> get favoritas => where((nota) => nota.esFavorita).toList();

  /// Filtrar notas archivadas
  List<Nota> get archivadas => where((nota) => nota.esArchivada).toList();

  /// Filtrar notas recientes
  List<Nota> get recientes => where((nota) => nota.esReciente).toList();

  /// Filtrar por etiqueta específica
  List<Nota> conEtiqueta(String etiqueta) {
    return where((nota) => nota.etiquetas.contains(etiqueta)).toList();
  }

  /// Buscar notas por texto
  List<Nota> buscarPorTexto(String consulta) {
    if (consulta.trim().isEmpty) return this;
    return where((nota) => nota.coincideCon(consulta)).toList();
  }

  /// Ordenar notas
  List<Nota> ordenarPor(TipoOrdenNota tipo, {bool ascendente = false}) {
    final notas = List<Nota>.from(this);

    switch (tipo) {
      case TipoOrdenNota.fechaGuardado:
        notas.sort(
          (a, b) => ascendente
              ? a.fechaGuardado.compareTo(b.fechaGuardado)
              : b.fechaGuardado.compareTo(a.fechaGuardado),
        );
        break;
      case TipoOrdenNota.fechaModificacion:
        notas.sort((a, b) {
          final fechaA = a.fechaModificacion ?? a.fechaGuardado;
          final fechaB = b.fechaModificacion ?? b.fechaGuardado;
          return ascendente
              ? fechaA.compareTo(fechaB)
              : fechaB.compareTo(fechaA);
        });
        break;
      case TipoOrdenNota.prioridad:
        notas.sort((a, b) {
          final prioridadA = a.prioridad ?? 3;
          final prioridadB = b.prioridad ?? 3;
          return ascendente
              ? prioridadA.compareTo(prioridadB)
              : prioridadB.compareTo(prioridadA);
        });
        break;
      case TipoOrdenNota.alfabetico:
        notas.sort((a, b) {
          final textoA = a.comentarioUsuario ?? '';
          final textoB = b.comentarioUsuario ?? '';
          return ascendente
              ? textoA.compareTo(textoB)
              : textoB.compareTo(textoA);
        });
        break;
    }

    return notas;
  }

  /// Obtener todas las etiquetas únicas
  List<String> get todasLasEtiquetas {
    final etiquetas = <String>{};
    for (final nota in this) {
      etiquetas.addAll(nota.etiquetas);
    }
    return etiquetas.toList()..sort();
  }

  /// Estadísticas rápidas
  Map<String, int> get estadisticas {
    return {
      'total': length,
      'favoritas': favoritas.length,
      'archivadas': archivadas.length,
      'recientes': recientes.length,
      'con_comentarios': where((n) => n.comentarioUsuario != null).length,
      'con_etiquetas': where((n) => n.etiquetas.isNotEmpty).length,
    };
  }
}
