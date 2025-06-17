import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:policode/models/articulo_model.dart';

/// Resultado de operaciones del reglamento
class ReglamentoResult {
  final bool success;
  final List<Articulo> articulos;
  final String? error;

  const ReglamentoResult({
    required this.success,
    this.articulos = const [],
    this.error,
  });

  factory ReglamentoResult.success(List<Articulo> articulos) =>
      ReglamentoResult(success: true, articulos: articulos);

  factory ReglamentoResult.error(String error) =>
      ReglamentoResult(success: false, error: error);
}

/// Servicio para manejar el reglamento
class ReglamentoService {
  static final ReglamentoService _instance = ReglamentoService._internal();
  factory ReglamentoService() => _instance;
  ReglamentoService._internal();

  List<Articulo>? _articulos;
  bool _isLoaded = false;
  String? _lastError;

  /// Verificar si el reglamento está cargado
  bool get isLoaded => _isLoaded;

  /// Obtener todos los artículos (carga si es necesario)
  Future<List<Articulo>> get articulos async {
    if (!_isLoaded) {
      await _cargarReglamento();
    }
    return _articulos ?? [];
  }

  /// Obtener error de la última operación
  String? get lastError => _lastError;

  /// Cargar reglamento desde assets
  Future<ReglamentoResult> cargarReglamento() async {
    try {
      await _cargarReglamento();
      return ReglamentoResult.success(_articulos ?? []);
    } catch (e) {
      return ReglamentoResult.error(e.toString());
    }
  }

  /// Buscar artículos por consulta
  Future<List<Articulo>> buscarArticulos(
    String consulta, {
    double umbralMinimo = 0.5,
  }) async {
    final articulos = await this.articulos;
    if (consulta.trim().isEmpty) return [];

    return articulos.buscarPorConsulta(consulta, umbralMinimo: umbralMinimo);
  }

  /// Obtener artículo por ID
  Future<Articulo?> obtenerArticuloPorId(String id) async {
    final articulos = await this.articulos;
    try {
      return articulos.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtener artículos por categoría
  Future<List<Articulo>> obtenerArticulosPorCategoria(String categoria) async {
    final articulos = await this.articulos;
    return articulos.filtrarPorCategoria(categoria);
  }

  /// Obtener todas las categorías disponibles
  Future<List<String>> obtenerCategorias() async {
    final articulos = await this.articulos;
    return articulos.categorias;
  }

  /// Obtener artículos relacionados (por palabras clave similares)
  Future<List<Articulo>> obtenerArticulosRelacionados(
    String articuloId, {
    int limite = 5,
  }) async {
    final articulos = await this.articulos;
    final articulo = await obtenerArticuloPorId(articuloId);

    if (articulo == null) return [];

    // Buscar artículos que compartan palabras clave
    final relacionados = <MapEntry<Articulo, int>>[];

    for (final art in articulos) {
      if (art.id == articuloId) continue;

      int coincidencias = 0;
      for (final palabra in articulo.palabrasClave) {
        if (art.palabrasClave.contains(palabra) ||
            art.categoria == articulo.categoria) {
          coincidencias++;
        }
      }

      if (coincidencias > 0) {
        relacionados.add(MapEntry(art, coincidencias));
      }
    }

    // Ordenar por número de coincidencias y tomar los primeros
    relacionados.sort((a, b) => b.value.compareTo(a.value));
    return relacionados.take(limite).map((e) => e.key).toList();
  }

  /// Buscar sugerencias de consulta basadas en palabras clave
  Future<List<String>> obtenerSugerencias(
    String consulta, {
    int limite = 5,
  }) async {
    final articulos = await this.articulos;
    if (consulta.trim().isEmpty) return [];

    final consultaLimpia = consulta.toLowerCase().trim();
    final sugerencias = <String>{};

    for (final articulo in articulos) {
      // Agregar palabras clave que contengan parte de la consulta
      for (final palabra in articulo.palabrasClave) {
        if (palabra.toLowerCase().contains(consultaLimpia) ||
            consultaLimpia.contains(palabra.toLowerCase())) {
          sugerencias.add(palabra);
        }
      }

      // Agregar categorías que coincidan
      if (articulo.categoria != null &&
          articulo.categoria!.toLowerCase().contains(consultaLimpia)) {
        sugerencias.add(articulo.categoria!);
      }
    }

    return sugerencias.take(limite).toList();
  }

  /// Generar contexto para Gemini con artículos relevantes
  Future<String> generarContextoParaGemini(
    String consulta, {
    int maxArticulos = 5,
  }) async {
    final articulosRelevantes = await buscarArticulos(
      consulta,
      umbralMinimo: 0.3,
    );

    if (articulosRelevantes.isEmpty) {
      return 'No se encontraron artículos específicamente relacionados con "$consulta".';
    }

    final context = StringBuffer();
    context.writeln('REGLAMENTO POLICODE - ARTÍCULOS RELEVANTES:\n');

    final articulosParaContexto = articulosRelevantes.take(maxArticulos);

    for (final articulo in articulosParaContexto) {
      context.writeln('${articulo.numero}: ${articulo.titulo}');
      context.writeln('Contenido: ${articulo.contenido}');

      if (articulo.categoria != null) {
        context.writeln('Categoría: ${articulo.categoria}');
      }

      if (articulo.palabrasClave.isNotEmpty) {
        context.writeln('Palabras clave: ${articulo.palabrasClave.join(', ')}');
      }

      context.writeln('---\n');
    }

    return context.toString();
  }

  /// Recargar reglamento (útil para actualizaciones)
  Future<ReglamentoResult> recargarReglamento() async {
    _isLoaded = false;
    _articulos = null;
    _lastError = null;
    return await cargarReglamento();
  }

  // Métodos privados

  /// Cargar reglamento desde assets
  Future<void> _cargarReglamento() async {
    try {
      _lastError = null;

      // Cargar el archivo JSON desde assets
      final String jsonString = await rootBundle.loadString(
        'assets/data/reglamento.json',
      );
      final List<dynamic> jsonList = jsonDecode(jsonString);

      // Convertir JSON a lista de artículos
      _articulos = jsonList
          .map((json) => Articulo.fromJson(json as Map<String, dynamic>))
          .toList();

      // Ordenar por número de artículo o prioridad
      _articulos!.sort((a, b) {
        // Primero por prioridad si existe
        if (a.prioridad != null && b.prioridad != null) {
          return a.prioridad!.compareTo(b.prioridad!);
        }

        // Luego por número de artículo
        return a.numero.compareTo(b.numero);
      });

      _isLoaded = true;
      print('✅ Reglamento cargado: ${_articulos!.length} artículos');
    } catch (e) {
      _lastError = 'Error cargando reglamento: $e';
      _isLoaded = false;
      print('❌ $_lastError');
      rethrow;
    }
  }
}

/// Utilidades para trabajar con el reglamento
class ReglamentoUtils {
  /// Validar estructura del JSON del reglamento
  static bool validarEstructuraJson(Map<String, dynamic> json) {
    final camposRequeridos = ['id', 'numero', 'titulo', 'contenido'];

    for (final campo in camposRequeridos) {
      if (!json.containsKey(campo) || json[campo] == null) {
        return false;
      }
    }

    return true;
  }

  /// Generar estadísticas del reglamento
  static Map<String, dynamic> generarEstadisticas(List<Articulo> articulos) {
    final categorias = <String, int>{};
    int totalPalabras = 0;
    int articulosConPalabrasClave = 0;

    for (final articulo in articulos) {
      // Contar categorías
      if (articulo.categoria != null) {
        categorias[articulo.categoria!] =
            (categorias[articulo.categoria!] ?? 0) + 1;
      }

      // Contar palabras
      totalPalabras += articulo.contenido.split(' ').length;

      // Artículos con palabras clave
      if (articulo.palabrasClave.isNotEmpty) {
        articulosConPalabrasClave++;
      }
    }

    return {
      'total_articulos': articulos.length,
      'categorias': categorias,
      'total_palabras': totalPalabras,
      'promedio_palabras_por_articulo': articulos.isNotEmpty
          ? totalPalabras / articulos.length
          : 0,
      'articulos_con_palabras_clave': articulosConPalabrasClave,
      'porcentaje_con_palabras_clave': articulos.isNotEmpty
          ? (articulosConPalabrasClave / articulos.length) * 100
          : 0,
    };
  }

  /// Generar reporte de cobertura de búsqueda
  static Map<String, dynamic> generarReporteCobertura(
    List<Articulo> articulos,
    List<String> consultasPrueba,
  ) {
    final resultados = <String, List<Articulo>>{};

    for (final consulta in consultasPrueba) {
      resultados[consulta] = articulos.buscarPorConsulta(consulta);
    }

    final consultasConResultados = resultados.values
        .where((resultados) => resultados.isNotEmpty)
        .length;

    return {
      'consultas_totales': consultasPrueba.length,
      'consultas_con_resultados': consultasConResultados,
      'porcentaje_cobertura': consultasPrueba.isNotEmpty
          ? (consultasConResultados / consultasPrueba.length) * 100
          : 0,
      'resultados_detallados': resultados.map(
        (consulta, arts) => MapEntry(consulta, arts.length),
      ),
    };
  }
}

/// Extensión para facilitar el uso del servicio
extension ReglamentoServiceExtension on ReglamentoService {
  /// Buscar y generar contexto para Gemini en una sola operación
  Future<String> buscarYGenerarContexto(String consulta) async {
    return await generarContextoParaGemini(consulta);
  }

  /// Verificar si una consulta tiene resultados
  Future<bool> tieneResultados(String consulta) async {
    final resultados = await buscarArticulos(consulta);
    return resultados.isNotEmpty;
  }

  /// Obtener resumen rápido de un artículo
  Future<String?> obtenerResumenArticulo(String articuloId) async {
    final articulo = await obtenerArticuloPorId(articuloId);
    return articulo?.resumen;
  }
}
