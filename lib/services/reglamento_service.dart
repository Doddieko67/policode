import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/models/articulo_model.dart';
import 'package:policode/utils/migrate_regulations.dart';

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

/// Servicio para manejar el reglamento desde Firebase
class ReglamentoService {
  static final ReglamentoService _instance = ReglamentoService._internal();
  factory ReglamentoService() => _instance;
  ReglamentoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RegulationMigrator _migrator = RegulationMigrator();
  
  List<Articulo>? _articulos;
  bool _isLoaded = false;
  String? _lastError;

  /// Verificar si el reglamento está cargado
  bool get isLoaded => _isLoaded;

  /// Obtener todos los artículos (carga desde Firebase si es necesario)
  Future<List<Articulo>> get articulos async {
    if (!_isLoaded) {
      await _cargarReglamento();
    }
    return _articulos ?? [];
  }

  /// Obtener error de la última operación
  String? get lastError => _lastError;

  /// Cargar reglamento desde Firebase
  Future<ReglamentoResult> cargarReglamento() async {
    try {
      print('📚 Cargando reglamentos desde Firebase...');
      
      // Verificar si necesitamos migrar primero
      if (!await _migrator.areRegulationsMigrated()) {
        print('🔄 Primera vez - migrando reglamentos desde assets...');
        await _migrator.migrateRegulationsToFirebase();
      }
      
      await _cargarReglamento();
      
      if (_articulos != null) {
        return ReglamentoResult.success(_articulos!);
      } else {
        return ReglamentoResult.error(_lastError ?? 'Error desconocido');
      }
    } catch (e) {
      final error = 'Error cargando reglamento: $e';
      _lastError = error;
      print('❌ $error');
      return ReglamentoResult.error(error);
    }
  }

  /// Cargar reglamento interno desde Firebase
  Future<void> _cargarReglamento() async {
    try {
      _lastError = null;
      
      final querySnapshot = await _firestore
          .collection('regulations')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .orderBy('articleNumber')
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('⚠️ No se encontraron reglamentos en Firebase');
        _articulos = [];
        _isLoaded = true;
        return;
      }

      final List<Articulo> articulos = [];
      
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final articulo = _convertFirestoreToArticulo(doc.id, data);
          articulos.add(articulo);
        } catch (e) {
          print('⚠️ Error procesando artículo ${doc.id}: $e');
          continue;
        }
      }

      _articulos = articulos;
      _isLoaded = true;
      
      print('✅ Cargados ${articulos.length} artículos desde Firebase');
    } catch (e) {
      _lastError = 'Error cargando desde Firebase: $e';
      _isLoaded = false;
      print('❌ $_lastError');
      rethrow;
    }
  }

  /// Convertir documento de Firestore a modelo Articulo
  Articulo _convertFirestoreToArticulo(String docId, Map<String, dynamic> data) {
    return Articulo(
      id: data['originalId'] ?? docId,
      numero: data['articleNumber'] ?? '',
      titulo: data['title'] ?? '',
      contenido: data['content'] ?? '',
      categoria: data['category'] ?? 'General',
      palabrasClave: List<String>.from(data['tags'] ?? []),
      // resumen: data['summary'] ?? '',
      prioridad: data['priority'] ?? 1,
      // fuente: data['source'] ?? '', // Campo no existe en el modelo
    );
  }

  /// Buscar artículos por término
  Future<List<Articulo>> buscarArticulos(String termino) async {
    if (!_isLoaded) {
      await _cargarReglamento();
    }

    if (_articulos == null || _articulos!.isEmpty) {
      return [];
    }

    final terminoLower = termino.toLowerCase();
    
    return _articulos!.where((articulo) {
      return articulo.titulo.toLowerCase().contains(terminoLower) ||
             articulo.contenido.toLowerCase().contains(terminoLower) ||
             articulo.numero.toLowerCase().contains(terminoLower) ||
             (articulo.categoria?.toLowerCase().contains(terminoLower) ?? false) ||
             articulo.palabrasClave.any((palabra) => 
                 palabra.toLowerCase().contains(terminoLower));
    }).toList();
  }

  /// Buscar artículos por categoría
  Future<List<Articulo>> buscarPorCategoria(String categoria) async {
    if (!_isLoaded) {
      await _cargarReglamento();
    }

    if (_articulos == null) return [];

    return _articulos!.where((articulo) => 
        (articulo.categoria?.toLowerCase().contains(categoria.toLowerCase()) ?? false)
    ).toList();
  }

  /// Obtener artículo por ID
  Future<Articulo?> obtenerArticuloPorId(String id) async {
    if (!_isLoaded) {
      await _cargarReglamento();
    }

    if (_articulos == null) return null;

    try {
      return _articulos!.firstWhere((articulo) => articulo.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtener categorías únicas
  Future<List<String>> obtenerCategorias() async {
    if (!_isLoaded) {
      await _cargarReglamento();
    }

    if (_articulos == null) return [];

    final Set<String> categorias = {};
    for (final articulo in _articulos!) {
      if (articulo.categoria != null) {
        categorias.add(articulo.categoria!);
      }
    }

    return categorias.toList()..sort();
  }

  /// Obtener artículos por categoría (alias para compatibilidad)
  Future<List<Articulo>> obtenerArticulosPorCategoria(String categoria) async {
    return await buscarPorCategoria(categoria);
  }

  /// Buscar artículos por consulta (con umbral, alias para compatibilidad)
  Future<List<Articulo>> buscarArticulosConUmbral(String consulta, {double umbralMinimo = 0.5}) async {
    // Por ahora ignoramos el umbral y usamos búsqueda simple
    return await buscarArticulos(consulta);
  }

  /// Obtener artículos relacionados (simulado por ahora)
  Future<List<Articulo>> obtenerArticulosRelacionados(String articuloId, {int limite = 5}) async {
    final articulo = await obtenerArticuloPorId(articuloId);
    if (articulo == null) return [];

    // Buscar artículos relacionados por palabras clave usando búsqueda interna
    final relacionados = <Articulo>[];
    if (!_isLoaded) {
      await _cargarReglamento();
    }
    
    if (_articulos == null) return [];
    
    for (final palabra in articulo.palabrasClave) {
      final palabraLower = palabra.toLowerCase();
      final encontrados = _articulos!.where((art) => 
        art.id != articuloId &&
        (art.titulo.toLowerCase().contains(palabraLower) ||
         art.contenido.toLowerCase().contains(palabraLower) ||
         art.palabrasClave.any((p) => p.toLowerCase().contains(palabraLower)))
      ).toList();
      relacionados.addAll(encontrados);
    }

    // Remover duplicados y limitar
    final Set<String> idsVistos = {};
    final List<Articulo> unicos = [];
    for (final art in relacionados) {
      if (!idsVistos.contains(art.id) && unicos.length < limite) {
        idsVistos.add(art.id);
        unicos.add(art);
      }
    }

    return unicos;
  }

  /// Recargar desde Firebase (actualizar caché)
  Future<void> recargar() async {
    _isLoaded = false;
    _articulos = null;
    _lastError = null;
    await _cargarReglamento();
  }

  /// Stream de artículos (para actualizaciones en tiempo real)
  Stream<List<Articulo>> get articulosStream {
    return _firestore
        .collection('regulations')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .orderBy('articleNumber')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return _convertFirestoreToArticulo(doc.id, doc.data());
      }).toList();
    });
  }

  /// Verificar estado de migración
  Future<bool> verificarMigracion() async {
    try {
      return await _migrator.areRegulationsMigrated();
    } catch (e) {
      print('Error verificando migración: $e');
      return false;
    }
  }

  /// Contar artículos disponibles
  Future<int> contarArticulos() async {
    try {
      return await _migrator.countRegulationsInFirebase();
    } catch (e) {
      print('Error contando artículos: $e');
      return 0;
    }
  }

  /// Limpiar caché
  void limpiarCache() {
    _isLoaded = false;
    _articulos = null;
    _lastError = null;
  }

  /// Generar contexto para Gemini (método de compatibilidad)
  Future<String> generarContextoParaGemini(String mensaje) async {
    final articulos = await this.articulos;
    if (articulos.isEmpty) return '';

    // Buscar artículos relevantes
    final relevantes = await buscarArticulos(mensaje);
    
    if (relevantes.isEmpty) return '';

    final contexto = StringBuffer();
    contexto.writeln('Artículos del Reglamento Estudiantil del IPN relevantes:');
    
    for (final articulo in relevantes.take(3)) {
      contexto.writeln('\n--- ${articulo.numero}: ${articulo.titulo} ---');
      contexto.writeln(articulo.contenido);
      if (articulo.categoria != null) {
        contexto.writeln('Categoría: ${articulo.categoria}');
      }
    }
    
    return contexto.toString();
  }

  /// Obtener sugerencias (método de compatibilidad)
  Future<List<String>> obtenerSugerencias(String consultaParcial) async {
    if (consultaParcial.length < 2) return [];
    
    final articulos = await this.articulos;
    final sugerencias = <String>[];
    
    // Buscar en títulos y palabras clave
    for (final articulo in articulos) {
      if (articulo.titulo.toLowerCase().contains(consultaParcial.toLowerCase())) {
        sugerencias.add(articulo.titulo);
      }
      
      for (final palabra in articulo.palabrasClave) {
        if (palabra.toLowerCase().contains(consultaParcial.toLowerCase()) &&
            !sugerencias.contains(palabra)) {
          sugerencias.add(palabra);
        }
      }
      
      if (sugerencias.length >= 5) break;
    }
    
    return sugerencias;
  }
}

/// Utilidades para el reglamento (clase estática para compatibilidad)
class ReglamentoUtils {
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
}