// ESE ES chat_screen.dart - SOLO LOS CAMBIOS NECESARIOS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart'; // AGREGAR ESTA LÍNEA
import 'package:policode/widgets/chat_components.dart';
import 'package:policode/widgets/loading_widgets.dart';
import '../services/chatbot_service.dart';
import '../services/auth_service.dart';

/// Pantalla principal del chat con el asistente IA
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  // AGREGAR ESTAS LÍNEAS
  static const String _geminiApiKey =
      'YOUR_API_KEY_HERE'; // Pon tu API key aquí
  bool _geminiInitialized = false;

  // Lista de mensajes del chat (usando Map temporalmente hasta tener el modelo)
  final List<Map<String, dynamic>> _messages = [];

  bool _isLoading = false;
  bool _isTyping = false;
  List<String> _sugerencias = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _inicializarChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _chatbotService.dispose();
    super.dispose();
  }

  // MODIFICAR ESTE MÉTODO
  Future<void> _inicializarChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // AGREGAR: Inicializar Gemini si no está inicializado
      if (!_geminiInitialized) {
        Gemini.init(
          apiKey: _geminiApiKey,
          enableDebugging: false, // Cambiar a true para desarrollo
        );
        _geminiInitialized = true;

        // Dar tiempo a que se inicialice
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // Verificar que el servicio esté listo
      final estaListo = await _chatbotService.estaListo;

      if (!estaListo) {
        setState(() {
          _errorMessage =
              'Error: El servicio de chat no está configurado correctamente';
          _isLoading = false;
        });
        return;
      }

      // Agregar mensaje de bienvenida
      final mensajeBienvenida = _chatbotService.generarMensajeBienvenida(
        usuario: _authService.currentUser,
      );

      _addMessage({
        'message': mensajeBienvenida.texto,
        'isUser': false,
        'timestamp': DateTime.now(),
        'type': 'welcome',
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inicializando chat: $e';
        _isLoading = false;
      });
    }
  }

  // RESTO DEL CÓDIGO SIN CAMBIOS...
  void _addMessage(Map<String, dynamic> message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviarMensaje(String texto) async {
    if (texto.trim().isEmpty || _isTyping) return;

    final mensajeUsuario = {
      'message': texto.trim(),
      'isUser': true,
      'timestamp': DateTime.now(),
    };

    _addMessage(mensajeUsuario);
    _textController.clear();

    setState(() {
      _isTyping = true;
      _errorMessage = null;
      _sugerencias = [];
    });

    try {
      // Simular delay de typing
      await Future.delayed(const Duration(milliseconds: 500));

      // Procesar mensaje con el chatbot
      final resultado = await _chatbotService.procesarMensajeCompleto(
        mensajeUsuario: texto.trim(),
        usuario: _authService.currentUser,
        // historialReciente: _getHistorialReciente(), // Temporalmente comentado
      );

      setState(() {
        _isTyping = false;
      });

      if (resultado.success && resultado.mensaje != null) {
        final mensajeRespuesta = {
          'message': resultado.mensaje!.texto,
          'isUser': false,
          'timestamp': DateTime.now(),
          'articulosRelacionados': resultado.articulosRelacionados,
          'metadatos': resultado.mensaje!.metadatos,
        };

        _addMessage(mensajeRespuesta);

        // Generar sugerencias basadas en la respuesta
        _generarSugerencias(texto);
      } else {
        _addMessage({
          'message': resultado.error ?? 'Error desconocido',
          'isUser': false,
          'timestamp': DateTime.now(),
          'hasError': true,
        });
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
      });

      _addMessage({
        'message': 'Error procesando mensaje: $e',
        'isUser': false,
        'timestamp': DateTime.now(),
        'hasError': true,
      });
    }
  }

  Future<void> _generarSugerencias(String consulta) async {
    try {
      final sugerencias = await _chatbotService.generarSugerencias(consulta);
      setState(() {
        _sugerencias = sugerencias.take(3).toList();
      });
    } catch (e) {
      // Ignorar errores de sugerencias
    }
  }

  List<Map<String, dynamic>> _getHistorialReciente() {
    // Retornar últimos 5 mensajes para contexto
    return _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;
  }

  void _onSugerenciaTap(String sugerencia) {
    _textController.text = sugerencia;
    setState(() {
      _sugerencias = [];
    });
  }

  void _onArticuloTap(String articuloId) {
    // Navegar a la pantalla de detalle del artículo
    Navigator.pushNamed(
      context,
      '/articulo',
      arguments: {'articuloId': articuloId},
    );
  }

  void _limpiarChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Chat'),
        content: const Text(
          '¿Estás seguro de que quieres limpiar todo el historial del chat?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
              });
              _inicializarChat();
            },
            child: Text(
              'Limpiar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarComandosAyuda() {
    _enviarMensaje('/ayuda');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _errorMessage != null
          ? _buildErrorState()
          : _buildChatContent(),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 1,
      backgroundColor: theme.colorScheme.surface,
      shadowColor: Colors.black.withOpacity(0.1),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              backgroundImage: AssetImage('assets/images/logo.png'),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asistente PoliCode',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _isTyping ? 'Escribiendo...' : 'En línea',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isTyping ? theme.primaryColor : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Ayuda'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Limpiar Chat'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 12),
                  Text('Exportar'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: CustomErrorWidget.generic(
        title: 'Error en el Chat',
        message: _errorMessage,
        onRetry: _inicializarChat,
      ),
    );
  }

  Widget _buildChatContent() {
    return Column(
      children: [
        // Lista de mensajes
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                      return const TypingIndicator(
                        userName: 'Asistente',
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      );
                    }

                    final message = _messages[index];
                    return ChatBubble(
                      message: message['message'] ?? '',
                      isUser: message['isUser'] ?? false,
                      timestamp: message['timestamp'] ?? DateTime.now(),
                      hasError: message['hasError'] ?? false,
                      articulosRelacionados: message['articulosRelacionados'],
                      onArticuloTap: _onArticuloTap,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    );
                  },
                ),
        ),

        // Input del chat
        ChatInput(
          controller: _textController,
          onSend: _enviarMensaje,
          onChanged: (text) {
            // Generar sugerencias mientras escribe (con debounce)
            if (text.length > 2) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_textController.text == text) {
                  _generarSugerencias(text);
                }
              });
            } else {
              setState(() {
                _sugerencias = [];
              });
            }
          },
          isEnabled: !_isTyping,
          isLoading: _isTyping,
          hint: 'Pregúntame sobre el reglamento...',
          suggestions: _sugerencias,
          onSuggestionTap: _onSugerenciaTap,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(child: EmptyStateWidget.noChatHistory());
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'help':
        _mostrarComandosAyuda();
        break;
      case 'clear':
        _limpiarChat();
        break;
      case 'export':
        _exportarChat();
        break;
    }
  }

  void _exportarChat() {
    // Convertir mensajes a texto
    final chatText = _messages
        .map(
          (msg) =>
              '${msg['isUser'] ? 'Usuario' : 'Asistente'}: ${msg['message']}\n',
        )
        .join('\n');

    // Copiar al clipboard
    Clipboard.setData(ClipboardData(text: chatText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chat copiado al portapapeles'),
        backgroundColor: Theme.of(context).primaryColor,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
