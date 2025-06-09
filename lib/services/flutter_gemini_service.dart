import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:async';

/// Resultado de respuesta de Gemini
class GeminiResponse {
  final bool success;
  final String? content;
  final String? error;

  const GeminiResponse({required this.success, this.content, this.error});

  factory GeminiResponse.success(String content) =>
      GeminiResponse(success: true, content: content);

  factory GeminiResponse.error(String error) =>
      GeminiResponse(success: false, error: error);
}

/// Configuración para el modelo Gemini
class GeminiConfig {
  final String model;
  final double temperature;
  final int maxOutputTokens;
  final List<SafetySetting>? safetySettings;

  const GeminiConfig({
    this.model = 'gemini-1.5-flash',
    this.temperature = 0.7,
    this.maxOutputTokens = 2048,
    this.safetySettings,
  });

  static List<SafetySetting> get defaultSafetySettings => [
    SafetySetting(
      category: SafetyCategory.harassment,
      threshold: SafetyThreshold.blockMediumAndAbove,
    ),
    SafetySetting(
      category: SafetyCategory.hateSpeech,
      threshold: SafetyThreshold.blockMediumAndAbove,
    ),
    SafetySetting(
      category: SafetyCategory.sexuallyExplicit,
      threshold: SafetyThreshold.blockMediumAndAbove,
    ),
    SafetySetting(
      category: SafetyCategory.dangerous,
      threshold: SafetyThreshold.blockMediumAndAbove,
    ),
  ];
}

/// Servicio simplificado que usa flutter_gemini SOLO para texto
class FlutterGeminiService {
  static final FlutterGeminiService _instance =
      FlutterGeminiService._internal();
  factory FlutterGeminiService() => _instance;
  FlutterGeminiService._internal();

  final GeminiConfig _config = GeminiConfig(
    safetySettings: GeminiConfig.defaultSafetySettings,
  );

  /// Instancia de Gemini
  Gemini get _gemini => Gemini.instance;

  /// Verificar si Gemini está configurado correctamente
  bool get isConfigured {
    try {
      return _gemini != null;
    } catch (e) {
      return false;
    }
  }

  /// Generar respuesta sobre el reglamento - VERSIÓN SIMPLIFICADA
  Future<GeminiResponse> askAboutReglamento({
    required String userQuestion,
    required String reglamentoContext,
    String? userName,
  }) async {
    try {
      if (!isConfigured) {
        return GeminiResponse.error('Gemini no está configurado correctamente');
      }

      final prompt = _buildReglamentoPrompt(
        userQuestion: userQuestion,
        reglamentoContext: reglamentoContext,
        userName: userName,
      );

      // Usar método text() que es más simple y estable
      final response = await _gemini.text(prompt);

      // Manejo seguro de la respuesta
      final output = response?.output;
      if (output != null && output.isNotEmpty) {
        return GeminiResponse.success(output);
      } else {
        return GeminiResponse.error('No se recibió respuesta válida de Gemini');
      }
    } catch (e) {
      return GeminiResponse.error('Error al comunicarse con Gemini: $e');
    }
  }

  /// Construir prompt especializado para consultas del reglamento
  String _buildReglamentoPrompt({
    required String userQuestion,
    required String reglamentoContext,
    String? userName,
  }) {
    final userGreeting = userName != null ? 'Hola $userName, ' : 'Hola, ';

    return '''
Eres un asistente especializado en el reglamento de PoliCode. Tu función es ayudar a los usuarios a entender y consultar el reglamento de manera clara y precisa.

INSTRUCCIONES:
1. Responde únicamente basándote en la información del reglamento proporcionada
2. Si la información no está en el contexto, di claramente que no tienes esa información específica
3. Mantén un tono profesional pero amigable
4. Proporciona respuestas concisas y bien estructuradas
5. Si es relevante, menciona números de artículos específicos

CONTEXTO DEL REGLAMENTO:
$reglamentoContext

PREGUNTA DEL USUARIO:
$userQuestion

RESPUESTA:
$userGreeting te ayudo con tu consulta sobre el reglamento de PoliCode.

''';
  }

  /// Método para generar texto simple
  Future<GeminiResponse> generateText({
    required String prompt,
    double? temperature,
    int? maxTokens,
  }) async {
    try {
      if (!isConfigured) {
        return GeminiResponse.error('Gemini no está configurado correctamente');
      }

      // Usar método text() simple
      final response = await _gemini.text(prompt);

      final output = response?.output;
      if (output != null && output.isNotEmpty) {
        return GeminiResponse.success(output);
      } else {
        return GeminiResponse.error('No se recibió respuesta válida de Gemini');
      }
    } catch (e) {
      return GeminiResponse.error('Error al generar texto: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    print('FlutterGeminiService disposed');
  }
}

/// Utilidades para trabajar con flutter_gemini
class FlutterGeminiUtils {
  /// Verificar si la API key está configurada
  static bool get isApiKeyConfigured {
    try {
      final gemini = Gemini.instance;
      return gemini != null;
    } catch (e) {
      return false;
    }
  }

  /// Formatear respuesta de Gemini
  static String formatResponse(String response) {
    return response
        .trim()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Reducir líneas múltiples
        .replaceAll(
          RegExp(r'^\*\*(.+?)\*\*$', multiLine: true),
          r'$1',
        ) // Limpiar formato markdown excesivo
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Remover headers markdown
        .trim();
  }

  /// Sanitizar texto de entrada
  static String sanitizeText(String text) {
    return text
        .replaceAll(
          RegExp(r'[^\w\s\.,!?¿¡áéíóúüñÁÉÍÓÚÜÑ()-]'),
          '',
        ) // Mantener solo caracteres seguros
        .replaceAll(RegExp(r'\s+'), ' ') // Normalizar espacios
        .trim();
  }

  /// Truncar texto si es muy largo
  static String truncateText(String text, {int maxLength = 1000}) {
    if (text.length <= maxLength) return text;

    return '${text.substring(0, maxLength)}...';
  }

  /// Validar que el texto no esté vacío después de sanitizar
  static bool isValidInput(String text) {
    final sanitized = sanitizeText(text);
    return sanitized.isNotEmpty && sanitized.length >= 2;
  }
}
