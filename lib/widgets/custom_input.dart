import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tipos de input disponibles
enum InputType {
  text, // Texto normal
  email, // Email con validación
  password, // Contraseña con toggle
  search, // Búsqueda con icono
  multiline, // Texto multilínea
  number, // Solo números
  phone, // Teléfono
}

/// Campo de entrada personalizado para PoliCode
class CustomInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final InputType type;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final bool isRequired;
  final bool isEnabled;
  final bool autofocus;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final BorderRadius? borderRadius;

  const CustomInput({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.type = InputType.text,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.isRequired = false,
    this.isEnabled = true,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixWidget,
    this.maxLines,
    this.maxLength,
    this.textInputAction,
    this.focusNode,
    this.contentPadding,
    this.fillColor,
    this.borderRadius,
  });

  // Factory constructors para casos comunes
  factory CustomInput.email({
    String? label,
    String? hint,
    TextEditingController? controller,
    Function(String)? onChanged,
    Function(String)? onSubmitted,
    String? Function(String?)? validator,
    bool isRequired = true,
    bool autofocus = false,
    FocusNode? focusNode,
  }) {
    return CustomInput(
      label: label ?? 'Email',
      hint: hint ?? 'Ingresa tu email',
      type: InputType.email,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: validator ?? _emailValidator,
      isRequired: isRequired,
      autofocus: autofocus,
      prefixIcon: Icons.email_outlined,
      textInputAction: TextInputAction.next,
      focusNode: focusNode,
    );
  }

  factory CustomInput.password({
    String? label,
    String? hint,
    TextEditingController? controller,
    Function(String)? onChanged,
    Function(String)? onSubmitted,
    String? Function(String?)? validator,
    bool isRequired = true,
    bool autofocus = false,
    FocusNode? focusNode,
  }) {
    return CustomInput(
      label: label ?? 'Contraseña',
      hint: hint ?? 'Ingresa tu contraseña',
      type: InputType.password,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: validator ?? _passwordValidator,
      isRequired: isRequired,
      autofocus: autofocus,
      prefixIcon: Icons.lock_outline,
      textInputAction: TextInputAction.done,
      focusNode: focusNode,
    );
  }

  factory CustomInput.search({
    String? hint,
    TextEditingController? controller,
    Function(String)? onChanged,
    Function(String)? onSubmitted,
    VoidCallback? onTap,
    bool autofocus = false,
    FocusNode? focusNode,
  }) {
    return CustomInput(
      hint: hint ?? 'Buscar en el reglamento...',
      type: InputType.search,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      autofocus: autofocus,
      prefixIcon: Icons.search,
      textInputAction: TextInputAction.search,
      focusNode: focusNode,
    );
  }

  factory CustomInput.multiline({
    String? label,
    String? hint,
    TextEditingController? controller,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    int maxLines = 4,
    int? maxLength,
    bool isRequired = false,
    FocusNode? focusNode,
  }) {
    return CustomInput(
      label: label,
      hint: hint ?? 'Escribe tu comentario...',
      type: InputType.multiline,
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      isRequired: isRequired,
      textInputAction: TextInputAction.newline,
      focusNode: focusNode,
    );
  }

  // Validadores por defecto
  static String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El email es requerido';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Ingresa un email válido';
    }
    return null;
  }

  static String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  late TextEditingController _controller;
  bool _isPasswordVisible = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          _buildLabel(theme),
          const SizedBox(height: 8),
        ],
        _buildTextField(theme),
      ],
    );
  }

  Widget _buildLabel(ThemeData theme) {
    return Row(
      children: [
        Text(
          widget.label!,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (widget.isRequired)
          Text(
            ' *',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(ThemeData theme) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _hasFocus = hasFocus;
        });
      },
      child: TextFormField(
        controller: _controller,
        focusNode: widget.focusNode,
        enabled: widget.isEnabled,
        autofocus: widget.autofocus,
        obscureText: widget.type == InputType.password && !_isPasswordVisible,
        keyboardType: _getKeyboardType(),
        textInputAction: widget.textInputAction ?? _getTextInputAction(),
        inputFormatters: _getInputFormatters(),
        maxLines: widget.type == InputType.password ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
        validator: widget.validator,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: widget.isEnabled ? null : theme.disabledColor,
        ),
        decoration: _buildDecoration(theme),
      ),
    );
  }

  InputDecoration _buildDecoration(ThemeData theme) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(12);
    final contentPadding =
        widget.contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16);

    final border = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: theme.colorScheme.outline.withOpacity(0.3),
        width: 1,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: theme.primaryColor, width: 2),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
    );

    return InputDecoration(
      hintText: widget.hint,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      prefixIcon: widget.prefixIcon != null
          ? Icon(
              widget.prefixIcon,
              color: _hasFocus
                  ? theme.primaryColor
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            )
          : null,
      suffixIcon: _buildSuffixIcon(theme),
      filled: true,
      fillColor:
          widget.fillColor ??
          (widget.isEnabled
              ? theme.colorScheme.surface
              : theme.colorScheme.surfaceContainerHighest),
      contentPadding: contentPadding,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
      counterText: '', // Ocultar contador por defecto
    );
  }

  Widget? _buildSuffixIcon(ThemeData theme) {
    if (widget.type == InputType.password) {
      return IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        onPressed: () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
        tooltip: _isPasswordVisible
            ? 'Ocultar contraseña'
            : 'Mostrar contraseña',
      );
    }

    if (widget.type == InputType.search && _controller.text.isNotEmpty) {
      return IconButton(
        icon: Icon(
          Icons.clear,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        onPressed: () {
          _controller.clear();
          widget.onChanged?.call('');
        },
        tooltip: 'Limpiar búsqueda',
      );
    }

    return widget.suffixWidget;
  }

  TextInputType _getKeyboardType() {
    switch (widget.type) {
      case InputType.email:
        return TextInputType.emailAddress;
      case InputType.password:
        return TextInputType.visiblePassword;
      case InputType.number:
        return TextInputType.number;
      case InputType.phone:
        return TextInputType.phone;
      case InputType.multiline:
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  TextInputAction _getTextInputAction() {
    switch (widget.type) {
      case InputType.email:
        return TextInputAction.next;
      case InputType.password:
        return TextInputAction.done;
      case InputType.search:
        return TextInputAction.search;
      case InputType.multiline:
        return TextInputAction.newline;
      default:
        return TextInputAction.done;
    }
  }

  List<TextInputFormatter>? _getInputFormatters() {
    switch (widget.type) {
      case InputType.number:
        return [FilteringTextInputFormatter.digitsOnly];
      case InputType.phone:
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ];
      default:
        return null;
    }
  }
}

/// Widget de búsqueda especializado con sugerencias
class SearchInput extends StatefulWidget {
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function(String)? onSuggestionTap;
  final List<String> suggestions;
  final String? hint;
  final bool autofocus;
  final FocusNode? focusNode;

  const SearchInput({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onSuggestionTap,
    this.suggestions = const [],
    this.hint,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  bool _showSuggestions = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus && widget.suggestions.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomInput.search(
          hint: widget.hint,
          controller: widget.controller,
          onChanged: (value) {
            widget.onChanged?.call(value);
            setState(() {
              _showSuggestions =
                  value.isNotEmpty && widget.suggestions.isNotEmpty;
            });
          },
          onSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          focusNode: _focusNode,
        ),
        if (_showSuggestions) _buildSuggestions(),
      ],
    );
  }

  Widget _buildSuggestions() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.suggestions.length > 5
            ? 5
            : widget.suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = widget.suggestions[index];
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.search,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            title: Text(suggestion, style: theme.textTheme.bodyMedium),
            onTap: () {
              widget.onSuggestionTap?.call(suggestion);
              _focusNode.unfocus();
            },
          );
        },
      ),
    );
  }
}
