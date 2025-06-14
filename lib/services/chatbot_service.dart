//Ese es chatbot_service.dart
import 'package:policode/models/chat_model.dart';
import 'package:policode/models/usuario_model.dart';
import 'flutter_gemini_service.dart'; // Importar el nuevo servicio
import 'reglamento_service.dart';
import 'forum_service.dart';
import 'article_service.dart';

/// Resultado de procesamiento del chatbot
class ChatbotResult {
  final bool success;
  final ChatMessage? mensaje;
  final String? error;
  final List<String>? articulosRelacionados;
  final List<String>? postsRelacionados;

  const ChatbotResult({
    required this.success,
    this.mensaje,
    this.error,
    this.articulosRelacionados,
    this.postsRelacionados,
  });

  factory ChatbotResult.success(
    ChatMessage mensaje, {
    List<String>? articulosRelacionados,
    List<String>? postsRelacionados,
  }) => ChatbotResult(
    success: true,
    mensaje: mensaje,
    articulosRelacionados: articulosRelacionados,
    postsRelacionados: postsRelacionados,
  );

  factory ChatbotResult.error(String error) =>
      ChatbotResult(success: false, error: error);
}

/// Servicio principal del chatbot que integra flutter_gemini con el reglamento
class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  // CAMBIO PRINCIPAL: Usar FlutterGeminiService en lugar de GeminiService
  final FlutterGeminiService _geminiService = FlutterGeminiService();
  final ReglamentoService _reglamentoService = ReglamentoService();
  final ForumService _forumService = ForumService();
  final ArticleService _articleService = ArticleService();

  /// Procesar mensaje del usuario y generar respuesta
  Future<ChatbotResult> procesarMensaje({
    required String mensajeUsuario,
    Usuario? usuario,
    List<ChatMessage>? historialReciente,
  }) async {
    try {
      // Validar entrada
      if (mensajeUsuario.trim().isEmpty) {
        return ChatbotResult.error('El mensaje no puede estar vacío');
      }

      // CAMBIO: Verificar configuración de flutter_gemini
      if (!_geminiService.isConfigured) {
        return ChatbotResult.error(
          'Gemini AI no está configurado correctamente',
        );
      }

      // Verificar que el reglamento esté cargado
      if (!_reglamentoService.isLoaded) {
        await _reglamentoService.cargarReglamento();
      }

      // Generar contexto del reglamento para la consulta
      final contextoReglamento = await _reglamentoService
          .generarContextoParaGemini(mensajeUsuario);

      // Obtener artículos relacionados para metadata
      final articulosRelacionados = await _reglamentoService.buscarArticulos(
        mensajeUsuario,
        umbralMinimo: 0.3,
      );

      // Buscar posts relacionados en el foro
      final postsRelacionados = await _forumService.searchPosts(mensajeUsuario);
      
      // Buscar artículos relacionados
      final articulosNoticias = await _articleService.searchArticles(mensajeUsuario);

      // CAMBIO: Generar respuesta con flutter_gemini
      final geminiResponse = await _geminiService.askAboutReglamento(
        userQuestion: mensajeUsuario,
        reglamentoContext: contextoReglamento,
        userName: usuario?.nombre,
      );

      if (!geminiResponse.success || geminiResponse.content == null) {
        return ChatbotResult.error(
          geminiResponse.error ?? 'Error generando respuesta',
        );
      }

      // CAMBIO: Formatear respuesta con nuevas utilidades
      final respuestaFormateada = FlutterGeminiUtils.formatResponse(
        geminiResponse.content!,
      );

      // Agregar información sobre contenido relacionado si existe
      String respuestaConRelacionados = respuestaFormateada;
      
      if (postsRelacionados.isNotEmpty || articulosNoticias.isNotEmpty) {
        respuestaConRelacionados += '\n\n📋 **Contenido relacionado:**\n';
        
        if (postsRelacionados.isNotEmpty) {
          respuestaConRelacionados += '\n🗨️ **Posts del foro:**\n';
          for (int i = 0; i < postsRelacionados.take(3).length; i++) {
            final post = postsRelacionados[i];
            respuestaConRelacionados += '• ${post.titulo}\n';
          }
        }
        
        if (articulosNoticias.isNotEmpty) {
          respuestaConRelacionados += '\n📰 **Artículos:**\n';
          for (int i = 0; i < articulosNoticias.take(3).length; i++) {
            final articulo = articulosNoticias[i];
            respuestaConRelacionados += '• ${articulo.titulo}\n';
          }
        }
      }

      // Crear mensaje de respuesta del asistente
      final mensajeRespuesta = ChatMessage.asistente(
        texto: respuestaConRelacionados,
        metadatos: {
          'articulos_relacionados': articulosRelacionados
              .map((a) => a.id)
              .toList(),
          'posts_relacionados': postsRelacionados
              .map((p) => p.id)
              .toList(),
          'articulos_noticias': articulosNoticias
              .map((a) => a.id)
              .toList(),
          'consulta_original': mensajeUsuario,
          'timestamp_procesamiento': DateTime.now().toIso8601String(),
          'modelo_usado': 'gemini-1.5-flash', // CAMBIO: Modelo actualizado
          'servicio': 'flutter_gemini', // CAMBIO: Nuevo identificador
        },
      );

      return ChatbotResult.success(
        mensajeRespuesta,
        articulosRelacionados: articulosRelacionados.map((a) => a.id).toList(),
        postsRelacionados: postsRelacionados.map((p) => p.id).toList(),
      );
    } catch (e) {
      return ChatbotResult.error('Error procesando mensaje: $e');
    }
  }

  /// Generar mensaje de bienvenida personalizado
  ChatMessage generarMensajeBienvenida({Usuario? usuario}) {
    return ChatMessage.bienvenida(nombreUsuario: usuario?.nombre);
  }

  /// Procesar comandos especiales (sin cambios en la lógica)
  Future<ChatbotResult?> procesarComandoEspecial(String mensaje) async {
    final mensajeLimpio = mensaje.toLowerCase().trim();

    // Comando de ayuda
    if (mensajeLimpio == '/ayuda' || mensajeLimpio == 'ayuda') {
      final mensajeAyuda = ChatMessage.asistente(
        texto:
            '''¡Hola! Soy tu asistente para consultar el reglamento de PoliCode.

¿Cómo puedo ayudarte?
• Pregúntame sobre cualquier tema del reglamento en lenguaje natural
• Puedes preguntar sobre artículos específicos: "¿Qué dice el artículo 15?"
• También sobre temas generales: "¿Cuáles son mis derechos como estudiante?"

Ejemplos de consultas:
• "Proceso de calificaciones"
• "Sanciones disciplinarias"
• "Servicios de biblioteca"
• "Derechos y obligaciones"

Funciones adicionales:
• Guarda artículos importantes con el botón ⭐
• Ve tu historial de artículos guardados
• Configura tus preferencias

¡Solo escribe tu duda y te ayudo a encontrar la información en el reglamento!''',
        metadatos: {'tipo': 'ayuda'},
      );

      return ChatbotResult.success(mensajeAyuda);
    }

    // Comando de estadísticas
    if (mensajeLimpio == '/stats' || mensajeLimpio == 'estadísticas') {
      final articulos = await _reglamentoService.articulos;
      final stats = ReglamentoUtils.generarEstadisticas(articulos);

      final mensajeStats = ChatMessage.asistente(
        texto:
            '''📊 Estadísticas del Reglamento:

• Total de artículos: ${stats['total_articulos']}
• Palabras totales: ${stats['total_palabras']}
• Promedio por artículo: ${(stats['promedio_palabras_por_articulo'] as double).toStringAsFixed(1)} palabras
• Artículos con palabras clave: ${(stats['porcentaje_con_palabras_clave'] as double).toStringAsFixed(1)}%

Categorías disponibles:
${(stats['categorias'] as Map<String, int>).entries.map((e) => '• ${e.key}: ${e.value} artículos').join('\n')}''',
        metadatos: {'tipo': 'estadisticas', 'stats': stats},
      );

      return ChatbotResult.success(mensajeStats);
    }

    // Comando para listar categorías
    if (mensajeLimpio == '/categorias' || mensajeLimpio == 'categorías') {
      final categorias = await _reglamentoService.obtenerCategorias();

      final mensajeCategorias = ChatMessage.asistente(
        texto:
            '''📋 Categorías del Reglamento:

${categorias.map((cat) => '• $cat').join('\n')}

Puedes preguntarme sobre cualquiera de estas categorías. Por ejemplo:
"Cuéntame sobre ${categorias.first}"''',
        metadatos: {'tipo': 'categorias', 'categorias': categorias},
      );

      return ChatbotResult.success(mensajeCategorias);
    }

    return null; // No es un comando especial
  }

  /// Generar sugerencias basadas en consulta parcial
  Future<List<String>> generarSugerencias(String consultaParcial) async {
    try {
      if (consultaParcial.trim().length < 2) return [];

      return await _reglamentoService.obtenerSugerencias(consultaParcial);
    } catch (e) {
      print('Error generando sugerencias: $e');
      return [];
    }
  }

  /// Obtener artículos relacionados para mostrar en la UI
  Future<List<String>> obtenerArticulosRelacionados(String articuloId) async {
    try {
      final relacionados = await _reglamentoService
          .obtenerArticulosRelacionados(articuloId);
      return relacionados.map((a) => a.id).toList();
    } catch (e) {
      print('Error obteniendo relacionados: $e');
      return [];
    }
  }

  /// Búsqueda directa en el reglamento (sin Gemini)
  Future<ChatbotResult> busquedaDirecta(String consulta) async {
    try {
      final articulos = await _reglamentoService.buscarArticulos(consulta);

      if (articulos.isEmpty) {
        final sugerencias = await generarSugerencias(consulta);
        final mensajeSinResultados = ChatMessage.asistente(
          texto:
              '''No encontré información específica sobre "$consulta" en el reglamento.

${sugerencias.isNotEmpty ? '''¿Te refieres a alguno de estos temas?
${sugerencias.map((s) => '• $s').join('\n')}''' : ''}

Intenta con otras palabras clave o pregúntame de manera diferente.''',
          metadatos: {
            'tipo': 'sin_resultados',
            'consulta_original': consulta,
            'sugerencias': sugerencias,
          },
        );

        return ChatbotResult.success(mensajeSinResultados);
      }

      // Crear respuesta con artículos encontrados
      final mensaje = ChatMessage.asistente(
        texto:
            '''Encontré ${articulos.length} artículo${articulos.length > 1 ? 's' : ''} relacionado${articulos.length > 1 ? 's' : ''} con "$consulta":

${articulos.take(3).map((art) => '''**${art.numero}: ${art.titulo}**
${art.resumen}''').join('\n---\n')}

${articulos.length > 3 ? '\nY ${articulos.length - 3} artículo${articulos.length - 3 > 1 ? 's' : ''} más...' : ''}''',
        metadatos: {
          'tipo': 'busqueda_directa',
          'articulos_encontrados': articulos.map((a) => a.id).toList(),
          'consulta_original': consulta,
        },
      );

      return ChatbotResult.success(
        mensaje,
        articulosRelacionados: articulos.map((a) => a.id).toList(),
      );
    } catch (e) {
      return ChatbotResult.error('Error en búsqueda: $e');
    }
  }

  /// Validar y sanitizar entrada del usuario
  String _sanitizarEntrada(String entrada) {
    return FlutterGeminiUtils.sanitizeText(entrada)
        .replaceAll(RegExp(r'\s+'), ' ') // Normalizar espacios
        .trim();
  }

  /// Verificar si la consulta es apropiada
  bool _esConsultaApropiada(String consulta) {
    // Lista de palabras/frases inapropiadas
    final palabrasInapropiadas = [
      'hack', 'crack', 'bypass', 'exploit',
      // Agregar más según necesidades
    ];

    final consultaLimpia = consulta.toLowerCase();
    return !palabrasInapropiadas.any(
      (palabra) => consultaLimpia.contains(palabra),
    );
  }

  /// Procesar mensaje completo con todas las validaciones
  Future<ChatbotResult> procesarMensajeCompleto({
    required String mensajeUsuario,
    Usuario? usuario,
    List<ChatMessage>? historialReciente,
    bool usarBusquedaDirecta = false,
  }) async {
    try {
      // Sanitizar entrada
      final mensajeLimpio = _sanitizarEntrada(mensajeUsuario);

      if (mensajeLimpio.isEmpty) {
        return ChatbotResult.error('Por favor, escribe una consulta válida');
      }

      // Verificar si es apropiada
      if (!_esConsultaApropiada(mensajeLimpio)) {
        return ChatbotResult.error(
          'La consulta contiene contenido inapropiado',
        );
      }

      // Verificar comandos especiales primero
      final comandoEspecial = await procesarComandoEspecial(mensajeLimpio);
      if (comandoEspecial != null) {
        return comandoEspecial;
      }

      // Usar búsqueda directa o Gemini según configuración
      if (usarBusquedaDirecta) {
        return await busquedaDirecta(mensajeLimpio);
      } else {
        return await procesarMensaje(
          mensajeUsuario: mensajeLimpio,
          usuario: usuario,
          historialReciente: historialReciente,
        );
      }
    } catch (e) {
      return ChatbotResult.error('Error procesando consulta: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    _geminiService.dispose();
  }
}

/// Extensiones para facilitar el uso
extension ChatbotServiceExtension on ChatbotService {
  /// Respuesta rápida sin historial
  Future<ChatbotResult> respuestaRapida(String consulta, {Usuario? usuario}) {
    return procesarMensajeCompleto(mensajeUsuario: consulta, usuario: usuario);
  }

  /// Verificar si el servicio está listo
  Future<bool> get estaListo async {
    return FlutterGeminiUtils.isApiKeyConfigured &&
        (_reglamentoService.isLoaded ||
            (await _reglamentoService.cargarReglamento()).success);
  }

  /// Obtener información del estado del servicio
  Future<Map<String, dynamic>> get estadoServicio async {
    return {
      'gemini_configurado': FlutterGeminiUtils.isApiKeyConfigured,
      'reglamento_cargado': _reglamentoService.isLoaded,
      'ultimo_error_reglamento': _reglamentoService.lastError,
      'servicio_gemini': 'flutter_gemini', // CAMBIO: Identificador actualizado
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
