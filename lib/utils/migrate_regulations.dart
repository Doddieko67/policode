import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utilidad para migrar reglamentos desde assets a Firebase
class RegulationMigrator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Migrar todos los reglamentos desde assets/data/reglamento.json a Firebase
  Future<void> migrateRegulationsToFirebase() async {
    try {
      print('🚀 Iniciando migración de reglamentos...');
      
      // 1. Cargar datos desde assets
      final String jsonString = await rootBundle.loadString('assets/data/reglamento.json');
      final List<dynamic> articulosJson = json.decode(jsonString);
      
      print('📚 Encontrados ${articulosJson.length} artículos para migrar');
      
      // 2. Preparar datos para Firebase
      final batch = _firestore.batch();
      int count = 0;
      
      for (final articuloData in articulosJson) {
        final Map<String, dynamic> data = articuloData as Map<String, dynamic>;
        
        // Adaptar estructura para Firebase
        final regulationData = {
          'title': data['titulo'] ?? '',
          'content': data['contenido'] ?? '',
          'category': data['categoria'] ?? 'General',
          'tags': List<String>.from(data['palabrasClave'] ?? []),
          'articleNumber': data['numero'] ?? '',
          'summary': data['resumen'] ?? '',
          'priority': data['prioridad'] ?? 1,
          'source': data['fuente'] ?? '',
          'originalId': data['id'] ?? '',
          
          // Metadatos de migración
          'uploadedBy': _auth.currentUser?.uid ?? 'system',
          'uploadedAt': Timestamp.now(),
          'isActive': true,
          'isMigrated': true,
          'version': '1.0',
        };
        
        // Usar el ID original como documento ID si está disponible
        final docId = data['id']?.toString() ?? _firestore.collection('regulations').doc().id;
        final docRef = _firestore.collection('regulations').doc(docId);
        
        batch.set(docRef, regulationData);
        count++;
        
        print('✅ Preparado: ${data['numero']} - ${data['titulo']}');
      }
      
      // 3. Ejecutar migración en lote
      print('💾 Guardando $count reglamentos en Firebase...');
      await batch.commit();
      
      // 4. Verificar migración
      final migratedCount = await _firestore
          .collection('regulations')
          .where('isMigrated', isEqualTo: true)
          .count()
          .get();
          
      print('✅ Migración completada: ${migratedCount.count} reglamentos migrados exitosamente');
      
      // 5. Crear índices necesarios (opcional - se hace automáticamente)
      await _createSearchIndexes();
      
    } catch (e) {
      print('❌ Error durante la migración: $e');
      rethrow;
    }
  }
  
  /// Verificar si ya existen reglamentos migrados
  Future<bool> areRegulationsMigrated() async {
    try {
      final snapshot = await _firestore
          .collection('regulations')
          .where('isMigrated', isEqualTo: true)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error verificando migración: $e');
      return false;
    }
  }
  
  /// Contar reglamentos en Firebase
  Future<int> countRegulationsInFirebase() async {
    try {
      final count = await _firestore
          .collection('regulations')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      
      return count.count ?? 0;
    } catch (e) {
      print('Error contando reglamentos: $e');
      return 0;
    }
  }
  
  /// Crear índices para búsqueda optimizada
  Future<void> _createSearchIndexes() async {
    // Los índices se crean automáticamente en Firestore cuando se hacen las primeras consultas
    // Pero podemos hacer consultas de prueba para activarlos
    try {
      print('🔍 Creando índices de búsqueda...');
      
      // Consulta por categoría
      await _firestore
          .collection('regulations')
          .where('isActive', isEqualTo: true)
          .orderBy('category')
          .limit(1)
          .get();
      
      // Consulta por prioridad
      await _firestore
          .collection('regulations')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .limit(1)
          .get();
          
      print('✅ Índices preparados');
    } catch (e) {
      print('⚠️ Los índices se crearán automáticamente con el uso: $e');
    }
  }
  
  /// Limpiar migración (solo para testing)
  Future<void> clearMigratedRegulations() async {
    print('🗑️ ADVERTENCIA: Eliminando reglamentos migrados...');
    
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('regulations')
        .where('isMigrated', isEqualTo: true)
        .get();
    
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    print('✅ Reglamentos migrados eliminados');
  }
}