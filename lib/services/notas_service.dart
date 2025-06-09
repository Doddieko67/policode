import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/models/nota_model.dart';
import 'firebase_config.dart';

/// Resultado de operaciones con notas
class NotaResult {
  final bool success;
  final Nota? nota;
  final List<Nota> notas;
  final String? error;

  const NotaResult({
    required this.success,
    this.nota,
    this.notas = const [],
    this.error,
  });

  factory NotaResult.success(Nota nota) =>
      NotaResult(success: true, nota: nota);

  factory NotaResult.successList(List<Nota> notas) =>
      NotaResult(success: true, notas: notas);

  factory NotaResult.error(String error) =>
      NotaResult(success: false, error: error);
}

/// Servicio para manejar notas en Firestore
class NotasService {
  static final NotasService _instance = NotasService._internal();
  factory NotasService() => _instance;
  NotasService._internal();

  // final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  /// Obtener stream de notas del usuario
  Stream<List<Nota>> getNotasStream(String userId) {
    return FirestoreCollections.notasDelUsuario(
      userId,
    ).orderBy('fecha_guardado', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return Nota.fromJson(data);
            } catch (e) {
              print('Error parseando nota ${doc.id}: $e');
              return null;
            }
          })
          .where((nota) => nota != null)
          .cast<Nota>()
          .toList();
    });
  }

  /// Obtener todas las notas del usuario
  Future<NotaResult> getNotas(String userId) async {
    try {
      final snapshot = await FirestoreCollections.notasDelUsuario(
        userId,
      ).orderBy('fecha_guardado', descending: true).get();

      final notas = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return Nota.fromJson(data);
            } catch (e) {
              print('Error parseando nota ${doc.id}: $e');
              return null;
            }
          })
          .where((nota) => nota != null)
          .cast<Nota>()
          .toList();

      return NotaResult.successList(notas);
    } catch (e) {
      return NotaResult.error('Error obteniendo notas: $e');
    }
  }

  /// Obtener notas filtradas
  Future<NotaResult> getNotasFiltradas({
    required String userId,
    FiltroCategoriaNotas? filtro,
    String? etiqueta,
    String? busqueda,
    TipoOrdenNota? orden,
    bool ascendente = false,
  }) async {
    try {
      final todasLasNotas = await getNotas(userId);
      if (!todasLasNotas.success) return todasLasNotas;

      var notasFiltradas = todasLasNotas.notas;

      // Aplicar filtros
      if (filtro != null) {
        switch (filtro) {
          case FiltroCategoriaNotas.favoritas:
            notasFiltradas = notasFiltradas.favoritas;
            break;
          case FiltroCategoriaNotas.archivadas:
            notasFiltradas = notasFiltradas.archivadas;
            break;
          case FiltroCategoriaNotas.recientes:
            notasFiltradas = notasFiltradas.recientes;
            break;
          case FiltroCategoriaNotas.conComentarios:
            notasFiltradas = notasFiltradas
                .where(
                  (n) =>
                      n.comentarioUsuario != null &&
                      n.comentarioUsuario!.isNotEmpty,
                )
                .toList();
            break;
          case FiltroCategoriaNotas.conEtiquetas:
            notasFiltradas = notasFiltradas
                .where((n) => n.etiquetas.isNotEmpty)
                .toList();
            break;
          case FiltroCategoriaNotas.todas:
            notasFiltradas = notasFiltradas.activas;
            break;
        }
      }

      // Filtrar por etiqueta específica
      if (etiqueta != null && etiqueta.isNotEmpty) {
        notasFiltradas = notasFiltradas.conEtiqueta(etiqueta);
      }

      // Filtrar por búsqueda
      if (busqueda != null && busqueda.isNotEmpty) {
        notasFiltradas = notasFiltradas.buscarPorTexto(busqueda);
      }

      // Ordenar
      if (orden != null) {
        notasFiltradas = notasFiltradas.ordenarPor(
          orden,
          ascendente: ascendente,
        );
      }

      return NotaResult.successList(notasFiltradas);
    } catch (e) {
      return NotaResult.error('Error filtrando notas: $e');
    }
  }

  /// Crear nueva nota
  Future<NotaResult> crearNota({
    required String userId,
    required String articuloId,
    String? comentarioUsuario,
    List<String>? etiquetas,
    bool esFavorita = false,
    int? prioridad,
    String? recordatorio,
  }) async {
    try {
      // Verificar si ya existe una nota para este artículo
      final notaExistente = await getNotaPorArticulo(userId, articuloId);
      if (notaExistente.success && notaExistente.nota != null) {
        return NotaResult.error(
          'Ya tienes una nota guardada para este artículo',
        );
      }

      final nota = Nota.nueva(
        userId: userId,
        articuloId: articuloId,
        comentarioUsuario: comentarioUsuario,
        etiquetas: etiquetas,
        esFavorita: esFavorita,
        prioridad: prioridad,
        recordatorio: recordatorio,
      );

      await FirestoreCollections.notasDelUsuario(
        userId,
      ).doc(nota.id).set(nota.toJson());

      return NotaResult.success(nota);
    } catch (e) {
      return NotaResult.error('Error creando nota: $e');
    }
  }

  /// Obtener nota por ID
  Future<NotaResult> getNota(String userId, String notaId) async {
    try {
      final doc = await FirestoreCollections.notasDelUsuario(
        userId,
      ).doc(notaId).get();

      if (!doc.exists || doc.data() == null) {
        return NotaResult.error('Nota no encontrada');
      }

      final nota = Nota.fromJson(doc.data() as Map<String, dynamic>);
      return NotaResult.success(nota);
    } catch (e) {
      return NotaResult.error('Error obteniendo nota: $e');
    }
  }

  /// Obtener nota por ID del artículo
  Future<NotaResult> getNotaPorArticulo(
    String userId,
    String articuloId,
  ) async {
    try {
      final snapshot = await FirestoreCollections.notasDelUsuario(
        userId,
      ).where('articulo_id', isEqualTo: articuloId).limit(1).get();

      if (snapshot.docs.isEmpty) {
        return NotaResult.error('No existe nota para este artículo');
      }

      final nota = Nota.fromJson(
        snapshot.docs.first.data() as Map<String, dynamic>,
      );
      return NotaResult.success(nota);
    } catch (e) {
      return NotaResult.error('Error obteniendo nota: $e');
    }
  }

  /// Actualizar nota
  Future<NotaResult> actualizarNota(String userId, Nota nota) async {
    try {
      final notaActualizada = nota.copyWith(fechaModificacion: DateTime.now());

      await FirestoreCollections.notasDelUsuario(
        userId,
      ).doc(nota.id).update(notaActualizada.toJson());

      return NotaResult.success(notaActualizada);
    } catch (e) {
      return NotaResult.error('Error actualizando nota: $e');
    }
  }

  /// Eliminar nota
  Future<NotaResult> eliminarNota(String userId, String notaId) async {
    try {
      await FirestoreCollections.notasDelUsuario(userId).doc(notaId).delete();

      return const NotaResult(success: true);
    } catch (e) {
      return NotaResult.error('Error eliminando nota: $e');
    }
  }

  /// Alternar favorita
  Future<NotaResult> alternarFavorita(String userId, String notaId) async {
    try {
      final notaResult = await getNota(userId, notaId);
      if (!notaResult.success || notaResult.nota == null) {
        return notaResult;
      }

      final notaActualizada = notaResult.nota!.alternarFavorita();
      return await actualizarNota(userId, notaActualizada);
    } catch (e) {
      return NotaResult.error('Error cambiando favorita: $e');
    }
  }

  /// Alternar archivada
  Future<NotaResult> alternarArchivada(String userId, String notaId) async {
    try {
      final notaResult = await getNota(userId, notaId);
      if (!notaResult.success || notaResult.nota == null) {
        return notaResult;
      }

      final notaActualizada = notaResult.nota!.alternarArchivada();
      return await actualizarNota(userId, notaActualizada);
    } catch (e) {
      return NotaResult.error('Error cambiando archivo: $e');
    }
  }

  /// Actualizar comentario
  Future<NotaResult> actualizarComentario(
    String userId,
    String notaId,
    String? comentario,
  ) async {
    try {
      final notaResult = await getNota(userId, notaId);
      if (!notaResult.success || notaResult.nota == null) {
        return notaResult;
      }

      final notaActualizada = notaResult.nota!.actualizarComentario(comentario);
      return await actualizarNota(userId, notaActualizada);
    } catch (e) {
      return NotaResult.error('Error actualizando comentario: $e');
    }
  }

  /// Agregar etiqueta
  Future<NotaResult> agregarEtiqueta(
    String userId,
    String notaId,
    String etiqueta,
  ) async {
    try {
      final notaResult = await getNota(userId, notaId);
      if (!notaResult.success || notaResult.nota == null) {
        return notaResult;
      }

      final notaActualizada = notaResult.nota!.agregarEtiqueta(etiqueta);
      return await actualizarNota(userId, notaActualizada);
    } catch (e) {
      return NotaResult.error('Error agregando etiqueta: $e');
    }
  }

  /// Remover etiqueta
  Future<NotaResult> removerEtiqueta(
    String userId,
    String notaId,
    String etiqueta,
  ) async {
    try {
      final notaResult = await getNota(userId, notaId);
      if (!notaResult.success || notaResult.nota == null) {
        return notaResult;
      }

      final notaActualizada = notaResult.nota!.removerEtiqueta(etiqueta);
      return await actualizarNota(userId, notaActualizada);
    } catch (e) {
      return NotaResult.error('Error removiendo etiqueta: $e');
    }
  }

  /// Obtener todas las etiquetas del usuario
  Future<List<String>> getEtiquetasDelUsuario(String userId) async {
    try {
      final notasResult = await getNotas(userId);
      if (!notasResult.success) return [];

      return notasResult.notas.todasLasEtiquetas;
    } catch (e) {
      print('Error obteniendo etiquetas: $e');
      return [];
    }
  }

  /// Obtener estadísticas de las notas del usuario
  Future<Map<String, int>> getEstadisticas(String userId) async {
    try {
      final notasResult = await getNotas(userId);
      if (!notasResult.success) return {};

      return notasResult.notas.estadisticas;
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {};
    }
  }

  /// Verificar si un artículo está guardado
  Future<bool> estaGuardado(String userId, String articuloId) async {
    try {
      final result = await getNotaPorArticulo(userId, articuloId);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// Importar notas desde backup (para migración o restauración)
  Future<NotaResult> importarNotas(
    String userId,
    List<Map<String, dynamic>> notasJson,
  ) async {
    try {
      final batch = FirestoreUtils.batch;
      final notasImportadas = <Nota>[];

      for (final json in notasJson) {
        try {
          final nota = Nota.fromJson(json);
          // Asegurar que pertenece al usuario correcto
          final notaCorregida = nota.copyWith(userId: userId);

          batch.set(
            FirestoreCollections.notasDelUsuario(userId).doc(notaCorregida.id),
            notaCorregida.toJson(),
          );

          notasImportadas.add(notaCorregida);
        } catch (e) {
          print('Error importando nota: $e');
        }
      }

      await batch.commit();
      return NotaResult.successList(notasImportadas);
    } catch (e) {
      return NotaResult.error('Error importando notas: $e');
    }
  }

  /// Exportar notas para backup
  Future<List<Map<String, dynamic>>> exportarNotas(String userId) async {
    try {
      final notasResult = await getNotas(userId);
      if (!notasResult.success) return [];

      return notasResult.notas.map((nota) => nota.toJson()).toList();
    } catch (e) {
      print('Error exportando notas: $e');
      return [];
    }
  }

  /// Limpiar notas archivadas antiguas
  Future<int> limpiarArchivadas(
    String userId, {
    int diasAntiguedad = 90,
  }) async {
    try {
      final fechaLimite = DateTime.now().subtract(
        Duration(days: diasAntiguedad),
      );

      final snapshot = await FirestoreCollections.notasDelUsuario(userId)
          .where('es_archivada', isEqualTo: true)
          .where(
            'fecha_modificacion',
            isLessThan: Timestamp.fromDate(fechaLimite),
          )
          .get();

      if (snapshot.docs.isEmpty) return 0;

      final batch = FirestoreUtils.batch;
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      print('Error limpiando archivadas: $e');
      return 0;
    }
  }
}

/// Extensiones para facilitar el uso del servicio
extension NotasServiceExtension on NotasService {
  /// Guardar artículo rápidamente
  Future<NotaResult> guardarArticulo(
    String userId,
    String articuloId, {
    String? comentario,
  }) {
    return crearNota(
      userId: userId,
      articuloId: articuloId,
      comentarioUsuario: comentario,
    );
  }

  /// Alternar guardado de artículo
  Future<NotaResult> alternarGuardado(String userId, String articuloId) async {
    final existe = await estaGuardado(userId, articuloId);

    if (existe) {
      final nota = await getNotaPorArticulo(userId, articuloId);
      if (nota.success && nota.nota != null) {
        return await eliminarNota(userId, nota.nota!.id);
      }
    } else {
      return await guardarArticulo(userId, articuloId);
    }

    return NotaResult.error('Error alternando guardado');
  }

  /// Obtener conteo rápido de notas
  Future<Map<String, int>> getConteoRapido(String userId) async {
    final stats = await getEstadisticas(userId);
    return {
      'total': stats['total'] ?? 0,
      'favoritas': stats['favoritas'] ?? 0,
      'archivadas': stats['archivadas'] ?? 0,
    };
  }

  // En lib/services/notas_service.dart, dentro de la clase NotasService

  /// Obtener las N notas más recientes del usuario.
  /// Ideal para vistas previas como en la pantalla de inicio.
  Future<List<Nota>> getNotasRecientes(String userId, {int limit = 3}) async {
    try {
      final snapshot = await FirestoreCollections.notasDelUsuario(userId)
          // Filtramos para no mostrar notas que el usuario ya ha archivado.
          .where('es_archivada', isEqualTo: false)
          // Ordenamos por la fecha en que se guardó, las más nuevas primero.
          .orderBy('fecha_guardado', descending: true)
          // Limitamos el número de resultados a los que necesitamos.
          .limit(limit)
          .get();

      // El resto es el mismo proceso de parseo que ya usas en otros métodos.
      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return Nota.fromJson(data);
            } catch (e) {
              print('Error parseando nota reciente ${doc.id}: $e');
              return null;
            }
          })
          .where((nota) => nota != null)
          .cast<Nota>()
          .toList();
    } catch (e) {
      print('Error obteniendo notas recientes: $e');
      // En caso de error, devolvemos una lista vacía para no romper la UI.
      return [];
    }
  }
}
