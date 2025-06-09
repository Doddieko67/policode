import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Configuración para Gemini AI
class GeminiConfig {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String _model =
      'gemini-1.5-flash'; // Modelo más rápido y económico

  // TODO: Reemplaza con tu API key de Google AI Studio
  // Obtén tu API key en: https://makersuite.google.com/app/apikey
  static const String _apiKey = 'TU_GEMINI_API_KEY_AQUI';

  /// URL completa para generar contenido
  static String get generateUrl =>
      '$_baseUrl/models/$_model:generateContent?key=$_apiKey';

  /// Headers por defecto para las peticiones
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
  };

  /// Configuración por defecto para generación
  static Map<String, dynamic> get defaultGenerationConfig => {
    'temperature': 0.7, // Creatividad balanceada
    'topK': 40, // Diversidad de tokens
    'topP': 0.95, // Probabilidad acumulativa
    'maxOutputTokens': 2048, // Máximo de tokens en respuesta
  };

  /// Configuración de seguridad por defecto
  static List<Map<String, dynamic>> get defaultSafetySettings => [
    {
      'category': 'HARM_CATEGORY_HARASSMENT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
  ];
}

/// Respuesta de Gemini AI
class GeminiResponse {
  final bool success;
  final String? content;
  final String? error;
  final Map<String, dynamic>? metadata;

  const GeminiResponse({
    required this.success,
    this.content,
    this.error,
    this.metadata,
  });

  factory GeminiResponse.success(
    String content, [
    Map<String, dynamic>? metadata,
  ]) => GeminiResponse(success: true, content: content, metadata: metadata);

  factory GeminiResponse.error(String error) =>
      GeminiResponse(success: false, error: error);
}

/// Servicio para interactuar con Gemini AI
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  final http.Client _client = http.Client();

  /// Generar respuesta usando Gemini AI
  Future<GeminiResponse> generateResponse({
    required String prompt,
    String? systemInstruction,
    Map<String, dynamic>? generationConfig,
    List<Map<String, dynamic>>? safetySettings,
  }) async {
    try {
      // Construir el cuerpo de la petición
      final requestBody = _buildRequestBody(
        prompt: prompt,
        systemInstruction: systemInstruction,
        generationConfig: generationConfig,
        safetySettings: safetySettings,
      );

      // Realizar la petición HTTP
      final response = await _client.post(
        Uri.parse(GeminiConfig.generateUrl),
        headers: GeminiConfig.headers,
        body: jsonEncode(requestBody),
      );

      return _parseResponse(response);
    } on SocketException {
      return GeminiResponse.error('Sin conexión a internet');
    } on HttpException {
      return GeminiResponse.error('Error de conexión con el servidor');
    } catch (e) {
      return GeminiResponse.error('Error inesperado: ${e.toString()}');
    }
  }

  /// Generar respuesta sobre el reglamento
  Future<GeminiResponse> askAboutReglamento({
    required String userQuestion,
    required String reglamentoContext,
    String? userName,
  }) async {
    final systemInstruction = _buildReglamentoSystemInstruction();
    final prompt = _buildReglamentoPrompt(
      userQuestion: userQuestion,
      reglamentoContext: reglamentoContext,
      userName: userName,
    );

    return await generateResponse(
      prompt: prompt,
      systemInstruction: systemInstruction,
      generationConfig: {
        ...GeminiConfig.defaultGenerationConfig,
        'temperature': 0.5, // Menos creatividad para mayor precisión
      },
    );
  }

  /// Construir el cuerpo de la petición
  Map<String, dynamic> _buildRequestBody({
    required String prompt,
    String? systemInstruction,
    Map<String, dynamic>? generationConfig,
    List<Map<String, dynamic>>? safetySettings,
  }) {
    final contents = <Map<String, dynamic>>[];

    // Agregar instrucción del sistema si existe
    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'INSTRUCCIONES DEL SISTEMA: $systemInstruction'},
        ],
      });
    }

    // Agregar el prompt del usuario
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt},
      ],
    });

    return {
      'contents': contents,
      'generationConfig':
          generationConfig ?? GeminiConfig.defaultGenerationConfig,
      'safetySettings': safetySettings ?? GeminiConfig.defaultSafetySettings,
    };
  }

  /// Parsear la respuesta de Gemini
  GeminiResponse _parseResponse(http.Response response) {
    try {
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null &&
            (data['candidates'] as List).isNotEmpty) {
          final candidate = data['candidates'][0];

          if (candidate['content'] != null &&
              candidate['content']['parts'] != null &&
              (candidate['content']['parts'] as List).isNotEmpty) {
            final content = candidate['content']['parts'][0]['text'] as String;

            // Metadata adicional
            final metadata = <String, dynamic>{
              'finishReason': candidate['finishReason'],
              'safetyRatings': candidate['safetyRatings'],
            };

            return GeminiResponse.success(content.trim(), metadata);
          }
        }

        return GeminiResponse.error('Respuesta vacía del modelo');
      } else {
        final error = _parseError(response);
        return GeminiResponse.error(error);
      }
    } catch (e) {
      return GeminiResponse.error(
        'Error procesando respuesta: ${e.toString()}',
      );
    }
  }

  /// Parsear errores de la API
  String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        final error = data['error'];
        final message = error['message'] ?? 'Error desconocido';

        switch (response.statusCode) {
          case 400:
            return 'Petición inválida: $message';
          case 401:
            return 'API key inválida o faltante';
          case 403:
            return 'Acceso denegado: $message';
          case 429:
            return 'Límite de peticiones excedido. Intenta más tarde';
          case 500:
            return 'Error interno del servidor';
          default:
            return 'Error ${response.statusCode}: $message';
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }

    return 'Error ${response.statusCode}: ${response.reasonPhrase}';
  }

  /// Construir instrucción del sistema para el reglamento
  String _buildReglamentoSystemInstruction() {
    return '''
Eres un asistente especializado en el reglamento de PoliCode. Tu trabajo es:

1. Responder preguntas sobre el reglamento de manera clara y precisa
2. Usar un tono amigable y profesional, no robótico
3. Citar los artículos específicos cuando sea relevante
4. Si no tienes información suficiente, admítelo honestamente
5. Proporcionar respuestas útiles y bien estructuradas
6. Usar markdown para mejorar la legibilidad cuando sea apropiado

IMPORTANTE:
- Solo responde con información que esté en el contexto del reglamento proporcionado
- No inventes información que no esté en el reglamento
- Si la pregunta está fuera del alcance del reglamento, redirige educadamente al tema
''';
  }

  /// Construir prompt específico para el reglamento
  String _buildReglamentoPrompt({
    required String userQuestion,
    required String reglamentoContext,
    String? userName,
  }) {
    final greeting = userName != null ? 'Hola $userName, ' : '';

    return '''
$greeting aquí está tu consulta sobre el reglamento:

PREGUNTA DEL USUARIO:
$userQuestion

CONTEXTO DEL REGLAMENTO:
$reglamentoContext

Por favor, responde la pregunta basándote únicamente en la información del reglamento proporcionada.
''';
  }

  /// Limpiar recursos
  void dispose() {
    _client.close();
  }
}

/// Utilidades para trabajar con Gemini
class GeminiUtils {
  /// Validar que la API key esté configurada
  static bool get isApiKeyConfigured {
    return GeminiConfig._apiKey != 'TU_GEMINI_API_KEY_AQUI' &&
        GeminiConfig._apiKey.isNotEmpty;
  }

  /// Sanitizar texto para evitar problemas con la API
  static String sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s\.,;:¿?¡!\-\(\)áéíóúñÁÉÍÓÚÑ]'), '')
        .trim();
  }

  /// Truncar texto si excede el límite de tokens
  static String truncateText(String text, {int maxLength = 30000}) {
    if (text.length <= maxLength) return text;

    // Intentar cortar en una oración completa
    final truncated = text.substring(0, maxLength);
    final lastPeriod = truncated.lastIndexOf('.');

    if (lastPeriod > maxLength * 0.8) {
      return truncated.substring(0, lastPeriod + 1);
    }

    return '$truncated...';
  }

  /// Formatear respuesta de Gemini para mejor visualización
  static String formatResponse(String response) {
    return response
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), '**\$1**') // Bold
        .replaceAll(RegExp(r'\*(.*?)\*'), '*\$1*') // Italic
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Max 2 line breaks
        .trim();
  }
}
