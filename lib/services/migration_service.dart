import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/models/articulo_model.dart';

class MigrationService {
  static final MigrationService _instance = MigrationService._internal();
  factory MigrationService() => _instance;
  MigrationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Migrar artículos del reglamento desde el JSON local a Firebase
  Future<bool> migrateReglamentoToFirebase() async {
    try {
      print('🚀 Iniciando migración del reglamento...');

      // 1. Cargar el JSON desde assets
      final String jsonString = await rootBundle.loadString('assets/data/reglamento.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      print('📄 Cargados ${jsonData.length} artículos del JSON');

      // 2. Verificar si ya existen datos en Firebase
      final existingDocs = await _db.collection('reglamento').limit(1).get();
      
      if (existingDocs.docs.isNotEmpty) {
        print('⚠️  Ya existen datos en Firebase. ¿Deseas sobrescribir?');
        // En una app real, podrías mostrar un diálogo de confirmación
        return false;
      }

      // 3. Convertir y subir cada artículo
      final batch = _db.batch();
      int uploadedCount = 0;

      for (final item in jsonData) {
        try {
          // Convertir del formato JSON al modelo Articulo
          final articulo = _convertJsonToArticulo(item);
          
          // Crear referencia del documento
          final docRef = _db.collection('reglamento').doc(articulo.id);
          
          // Crear datos extendidos para Firestore
          final firestoreData = articulo.toJson();
          firestoreData.addAll({
            'resumen': item['resumen'] ?? articulo.resumen,
            'fuente': item['fuente'] ?? '',
            'fecha_creacion': FieldValue.serverTimestamp(),
            'es_publico': true,
            'version': '1.0',
          });
          
          // Agregar al batch
          batch.set(docRef, firestoreData);
          uploadedCount++;

          // Commit en lotes de 500 (límite de Firestore)
          if (uploadedCount % 500 == 0) {
            await batch.commit();
            print('📦 Subidos $uploadedCount artículos...');
          }
        } catch (e) {
          print('❌ Error procesando artículo ${item['id']}: $e');
        }
      }

      // Commit final si quedan elementos
      if (uploadedCount % 500 != 0) {
        await batch.commit();
      }

      print('✅ Migración completada: $uploadedCount artículos subidos');
      
      // 4. Crear índices y metadata
      await _createMetadata(uploadedCount);

      return true;
    } catch (e) {
      print('❌ Error en la migración: $e');
      return false;
    }
  }

  /// Convertir el formato JSON a modelo Articulo
  Articulo _convertJsonToArticulo(Map<String, dynamic> jsonItem) {
    return Articulo(
      id: jsonItem['id'] ?? '',
      numero: jsonItem['numero'] ?? '',
      titulo: jsonItem['titulo'] ?? '',
      contenido: jsonItem['contenido'] ?? '',
      categoria: jsonItem['categoria'] ?? 'Sin categoría',
      palabrasClave: List<String>.from(jsonItem['palabrasClave'] ?? []),
      prioridad: jsonItem['prioridad'] ?? 1,
      fechaActualizacion: DateTime.now(),
    );
  }

  /// Crear metadata de la migración
  Future<void> _createMetadata(int totalArticulos) async {
    await _db.collection('metadata').doc('reglamento').set({
      'total_articulos': totalArticulos,
      'fecha_migracion': FieldValue.serverTimestamp(),
      'version_reglamento': '2020',
      'fuente_original': 'assets/data/reglamento.json',
      'estado': 'migrado',
    });
  }

  /// Verificar el estado de la migración
  Future<Map<String, dynamic>?> getMigrationStatus() async {
    try {
      final doc = await _db.collection('metadata').doc('reglamento').get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error obteniendo estado de migración: $e');
      return null;
    }
  }

  /// Eliminar todos los datos del reglamento (usar con cuidado)
  Future<bool> clearReglamentoData() async {
    try {
      print('🗑️  Eliminando datos del reglamento...');
      
      // Obtener todos los documentos
      final snapshot = await _db.collection('reglamento').get();
      
      // Eliminar en lotes
      final batch = _db.batch();
      int deletedCount = 0;
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        deletedCount++;
        
        if (deletedCount % 500 == 0) {
          await batch.commit();
          print('🗑️  Eliminados $deletedCount documentos...');
        }
      }
      
      // Commit final
      if (deletedCount % 500 != 0) {
        await batch.commit();
      }
      
      // Eliminar metadata
      await _db.collection('metadata').doc('reglamento').delete();
      
      print('✅ Eliminados $deletedCount documentos del reglamento');
      return true;
    } catch (e) {
      print('❌ Error eliminando datos: $e');
      return false;
    }
  }

  /// Migrar artículos de ejemplo (contenido adicional)
  Future<bool> createSampleArticles() async {
    try {
      print('📰 Creando artículos de ejemplo...');
      
      final sampleArticles = [
        {
          'titulo': 'Guía del Estudiante Politécnico',
          'contenido': '''# Bienvenido al IPN

El Instituto Politécnico Nacional es una institución educativa de nivel superior que forma profesionales en diversas áreas del conocimiento.

## Servicios Estudiantiles

- Bibliotecas especializadas
- Laboratorios de investigación
- Centros deportivos
- Servicios médicos
- Becas y apoyos económicos

## Proceso de Inscripción

1. Registro en línea
2. Examen de admisión
3. Selección de carrera
4. Documentación requerida
5. Pago de cuotas

¡Prepárate para una experiencia educativa de excelencia!''',
          'categoria': 'Guías',
          'tags': ['estudiantes', 'inscripción', 'servicios'],
          'isFeatured': true,
        },
        {
          'titulo': 'Derechos y Obligaciones del Estudiante',
          'contenido': '''# Derechos y Obligaciones

## Derechos del Estudiante

- Recibir educación de calidad
- Acceso a instalaciones y servicios
- Participar en actividades académicas
- Expresar ideas y opiniones
- Recibir apoyo académico

## Obligaciones del Estudiante

- Cumplir con el reglamento
- Asistir puntualmente a clases
- Respetar a compañeros y profesores
- Cuidar las instalaciones
- Mantener buen rendimiento académico

## Procedimientos Disciplinarios

En caso de incumplimiento, se aplicarán las sanciones correspondientes según el reglamento vigente.''',
          'categoria': 'Reglamento',
          'tags': ['derechos', 'obligaciones', 'disciplina'],
          'isFeatured': true,
        },
        {
          'titulo': 'Sistema de Calificaciones IPN',
          'contenido': '''# Sistema de Evaluación

## Escala de Calificaciones

- **10**: Excelente
- **9**: Muy bueno  
- **8**: Bueno
- **7**: Regular
- **6**: Suficiente
- **5 o menos**: No acreditado

## Tipos de Evaluación

### Evaluación Continua
- Participación en clase
- Tareas y proyectos
- Exámenes parciales

### Evaluación Final
- Examen final
- Proyecto integrador
- Presentación oral

## Recuperación de Materias

Los estudiantes pueden recuperar materias no acreditadas mediante:
- Examen extraordinario
- Curso de regularización
- Recursamiento''',
          'categoria': 'Académico',
          'tags': ['calificaciones', 'evaluación', 'exámenes'],
          'isFeatured': false,
        },
      ];

      final batch = _db.batch();
      
      for (int i = 0; i < sampleArticles.length; i++) {
        final article = sampleArticles[i];
        final docRef = _db.collection('articles').doc();
        
        batch.set(docRef, {
          'id': docRef.id,
          'titulo': article['titulo'],
          'contenido': article['contenido'],
          'resumen': _generateSummary(article['contenido'] as String),
          'autorId': 'system',
          'autorNombre': 'Sistema PoliCode',
          'fechaCreacion': FieldValue.serverTimestamp(),
          'fechaActualizacion': FieldValue.serverTimestamp(),
          'tags': article['tags'],
          'categoria': article['categoria'],
          'imagenUrl': null,
          'views': 0,
          'likes': 0,
          'isPublished': true,
          'isFeatured': article['isFeatured'],
        });
      }

      await batch.commit();
      print('✅ Creados ${sampleArticles.length} artículos de ejemplo');
      return true;
    } catch (e) {
      print('❌ Error creando artículos de ejemplo: $e');
      return false;
    }
  }

  String _generateSummary(String content) {
    // Extraer primeras 150 caracteres o hasta el primer punto seguido
    final lines = content.split('\n');
    String summary = '';
    
    for (final line in lines) {
      if (line.trim().isNotEmpty && !line.startsWith('#')) {
        summary = line.trim();
        break;
      }
    }
    
    if (summary.length > 150) {
      summary = summary.substring(0, 150) + '...';
    }
    
    return summary.isNotEmpty ? summary : 'Contenido educativo del IPN';
  }
}