import 'package:equatable/equatable.dart';

class Articulo extends Equatable {
  final String id;
  final String numero;
  final String titulo;
  final String contenido;
  final List<String> palabrasClave;
  final DateTime? fechaActualizacion;
  final String? categoria; // Para organizar artículos por temas
  final int? prioridad; // Para ordenar resultados de búsqueda

  const Articulo({
    required this.id,
    required this.numero,
    required this.titulo,
    required this.contenido,
    required this.palabrasClave,
    this.fechaActualizacion,
    this.categoria,
    this.prioridad,
  });

  // Factory constructor para crear desde JSON
  factory Articulo.fromJson(Map<String, dynamic> json) {
    return Articulo(
      id: json['id'] as String,
      numero: json['numero'] as String,
      titulo: json['titulo'] as String,
      contenido: json['contenido'] as String,
      palabrasClave: List<String>.from(json['palabrasClave'] ?? []),
      fechaActualizacion: json['fecha_actualizacion'] != null
          ? DateTime.parse(json['fecha_actualizacion'])
          : null,
      categoria: json['categoria'] as String?,
      prioridad: json['prioridad'] as int?,
    );
  }

  // Método para convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'titulo': titulo,
      'contenido': contenido,
      'palabrasClave': palabrasClave,
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'categoria': categoria,
      'prioridad': prioridad,
    };
  }

  // CopyWith para crear copias modificadas
  Articulo copyWith({
    String? id,
    String? numero,
    String? titulo,
    String? contenido,
    List<String>? palabrasClave,
    DateTime? fechaActualizacion,
    String? categoria,
    int? prioridad,
  }) {
    return Articulo(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      titulo: titulo ?? this.titulo,
      contenido: contenido ?? this.contenido,
      palabrasClave: palabrasClave ?? this.palabrasClave,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      categoria: categoria ?? this.categoria,
      prioridad: prioridad ?? this.prioridad,
    );
  }

  // Métodos útiles para el chatbot

  /// Obtiene todo el texto searcheable del artículo
  String get textoCompleto {
    return '$numero $titulo $contenido ${palabrasClave.join(' ')} ${categoria ?? ''}'
        .toLowerCase();
  }

  /// Calcula la relevancia del artículo para una consulta dada
  double calcularRelevancia(String consulta) {
    if (consulta.trim().isEmpty) return 0.0;

    final consultaLimpia = _limpiarTexto(consulta);
    final palabrasConsulta = consultaLimpia
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();

    if (palabrasConsulta.isEmpty) return 0.0;

    double puntuacion = 0.0;
    // final textoArticulo = _limpiarTexto(textoCompleto);

    for (final palabra in palabrasConsulta) {
      // Búsqueda exacta en palabras clave (mayor peso)
      if (palabrasClave.any((pc) => _limpiarTexto(pc).contains(palabra))) {
        puntuacion += 3.0;
      }

      // Búsqueda en título (peso medio-alto)
      if (_limpiarTexto(titulo).contains(palabra)) {
        puntuacion += 2.5;
      }

      // Búsqueda en número del artículo (peso medio-alto)
      if (_limpiarTexto(numero).contains(palabra)) {
        puntuacion += 2.5;
      }

      // Búsqueda en contenido (peso menor)
      if (_limpiarTexto(contenido).contains(palabra)) {
        puntuacion += 1.0;
      }

      // Búsqueda en categoría (peso medio)
      if (categoria != null && _limpiarTexto(categoria!).contains(palabra)) {
        puntuacion += 2.0;
      }
    }

    // Normalizar por número de palabras en la consulta
    return puntuacion / palabrasConsulta.length;
  }

  /// Verifica si el artículo coincide con una consulta (relevancia > 0)
  bool coincideCon(String consulta) {
    return calcularRelevancia(consulta) > 0;
  }

  /// Obtiene un resumen corto del artículo
  String get resumen {
    if (contenido.length <= 150) return contenido;

    // Buscar el primer punto después de 100 caracteres
    final index = contenido.indexOf('.', 100);
    if (index != -1 && index < 200) {
      return '${contenido.substring(0, index + 1)}...';
    }

    // Si no hay punto, cortar en 150 caracteres
    return '${contenido.substring(0, 150)}...';
  }

  /// Limpia texto para búsquedas (quita acentos, convierte a minúsculas, etc.)
  String _limpiarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Quitar puntuación
        .replaceAll(RegExp(r'\s+'), ' ') // Normalizar espacios
        .trim();
  }

  /// Obtiene fragmentos del contenido que contienen las palabras de búsqueda
  List<String> obtenerFragmentosRelevantes(
    String consulta, {
    int maxFragmentos = 3,
  }) {
    if (consulta.trim().isEmpty) return [resumen];

    final consultaLimpia = _limpiarTexto(consulta);
    final palabrasConsulta = consultaLimpia
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    final contenidoLimpio = _limpiarTexto(contenido);

    final fragmentos = <String>[];

    for (final palabra in palabrasConsulta) {
      final index = contenidoLimpio.indexOf(palabra);
      if (index != -1) {
        final inicio = (index - 50).clamp(0, contenido.length);
        final fin = (index + palabra.length + 50).clamp(0, contenido.length);
        final fragmento = contenido.substring(inicio, fin);
        fragmentos.add(inicio > 0 ? '...$fragmento...' : '$fragmento...');

        if (fragmentos.length >= maxFragmentos) break;
      }
    }

    return fragmentos.isNotEmpty ? fragmentos : [resumen];
  }

  @override
  List<Object?> get props => [
    id,
    numero,
    titulo,
    contenido,
    palabrasClave,
    fechaActualizacion,
    categoria,
    prioridad,
  ];

  @override
  String toString() {
    return 'Articulo(id: $id, numero: $numero, titulo: $titulo)';
  }
}

// Extensión para trabajar con listas de artículos
extension ArticuloListExtension on List<Articulo> {
  /// Busca artículos por consulta y los ordena por relevancia
  List<Articulo> buscarPorConsulta(
    String consulta, {
    double umbralMinimo = 0.5,
  }) {
    if (consulta.trim().isEmpty) return [];

    final resultados = <MapEntry<Articulo, double>>[];

    for (final articulo in this) {
      final relevancia = articulo.calcularRelevancia(consulta);
      if (relevancia >= umbralMinimo) {
        resultados.add(MapEntry(articulo, relevancia));
      }
    }

    // Ordenar por relevancia descendente
    resultados.sort((a, b) => b.value.compareTo(a.value));

    return resultados.map((e) => e.key).toList();
  }

  /// Filtra artículos por categoría
  List<Articulo> filtrarPorCategoria(String categoria) {
    return where((articulo) => articulo.categoria == categoria).toList();
  }

  /// Obtiene todas las categorías únicas
  List<String> get categorias {
    return map(
      (a) => a.categoria,
    ).where((c) => c != null).cast<String>().toSet().toList()..sort();
  }
}
