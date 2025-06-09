import 'package:flutter/material.dart';

/// Tipos de botón disponibles
enum ButtonType {
  primary, // Botón principal (azul)
  secondary, // Botón secundario (blanco con borde)
  danger, // Botón de peligro (rojo)
  success, // Botón de éxito (verde)
  text, // Botón de solo texto
  outline, // Botón con borde
}

/// Tamaños de botón disponibles
enum ButtonSize {
  small, // 32px altura
  medium, // 40px altura
  large, // 48px altura
  extraLarge, // 56px altura
}

/// Botón personalizado y reutilizable para PoliCode
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool isLoading;
  final bool isExpanded;
  final IconData? icon;
  final IconData? suffixIcon;
  final Color? customColor;
  final TextStyle? customTextStyle;
  final EdgeInsetsGeometry? customPadding;
  final BorderRadius? borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
    this.icon,
    this.suffixIcon,
    this.customColor,
    this.customTextStyle,
    this.customPadding,
    this.borderRadius,
  });

  // Factory constructors para casos comunes
  factory CustomButton.primary({
    required String text,
    VoidCallback? onPressed,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isExpanded = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      type: ButtonType.primary,
      size: size,
      isLoading: isLoading,
      isExpanded: isExpanded,
      icon: icon,
    );
  }

  factory CustomButton.secondary({
    required String text,
    VoidCallback? onPressed,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isExpanded = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      type: ButtonType.secondary,
      size: size,
      isLoading: isLoading,
      isExpanded: isExpanded,
      icon: icon,
    );
  }

  factory CustomButton.danger({
    required String text,
    VoidCallback? onPressed,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    bool isExpanded = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      type: ButtonType.danger,
      size: size,
      isLoading: isLoading,
      isExpanded: isExpanded,
      icon: icon,
    );
  }

  factory CustomButton.text({
    required String text,
    VoidCallback? onPressed,
    ButtonSize size = ButtonSize.medium,
    bool isLoading = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      type: ButtonType.text,
      size: size,
      isLoading: isLoading,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = _getButtonStyle(theme);
    final textStyle = _getTextStyle(theme);
    final buttonHeight = _getButtonHeight();
    final buttonPadding = _getButtonPadding();

    Widget button;

    switch (type) {
      case ButtonType.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: _buildButtonContent(textStyle),
        );
        break;
      case ButtonType.outline:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: _buildButtonContent(textStyle),
        );
        break;
      default:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: _buildButtonContent(textStyle),
        );
    }

    return SizedBox(
      height: buttonHeight,
      width: isExpanded ? double.infinity : null,
      child: button,
    );
  }

  /// Construir el contenido del botón (texto, iconos, loading)
  Widget _buildButtonContent(TextStyle textStyle) {
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _getLoadingSize(),
            height: _getLoadingSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getLoadingColor()),
            ),
          ),
          const SizedBox(width: 8),
          Text('Cargando...', style: textStyle),
        ],
      );
    }

    final children = <Widget>[];

    // Icono inicial
    if (icon != null) {
      children.add(Icon(icon, size: _getIconSize()));
      children.add(const SizedBox(width: 8));
    }

    // Texto
    children.add(Text(text, style: textStyle));

    // Icono final
    if (suffixIcon != null) {
      children.add(const SizedBox(width: 8));
      children.add(Icon(suffixIcon, size: _getIconSize()));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Obtener el estilo del botón según el tipo
  ButtonStyle _getButtonStyle(ThemeData theme) {
    final borderRadius = this.borderRadius ?? BorderRadius.circular(8);
    final padding = customPadding ?? _getButtonPadding();

    switch (type) {
      case ButtonType.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: customColor ?? theme.primaryColor,
          foregroundColor: Colors.white,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          elevation: 2,
        );

      case ButtonType.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: customColor ?? Colors.white,
          foregroundColor: theme.primaryColor,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: theme.primaryColor),
          ),
          elevation: 0,
        );

      case ButtonType.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: customColor ?? Colors.red,
          foregroundColor: Colors.white,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          elevation: 2,
        );

      case ButtonType.success:
        return ElevatedButton.styleFrom(
          backgroundColor: customColor ?? Colors.green,
          foregroundColor: Colors.white,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          elevation: 2,
        );

      case ButtonType.text:
        return TextButton.styleFrom(
          foregroundColor: customColor ?? theme.primaryColor,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        );

      case ButtonType.outline:
        return OutlinedButton.styleFrom(
          foregroundColor: customColor ?? theme.primaryColor,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          side: BorderSide(color: customColor ?? theme.primaryColor),
        );
    }
  }

  /// Obtener el estilo del texto
  TextStyle _getTextStyle(ThemeData theme) {
    if (customTextStyle != null) return customTextStyle!;

    final fontSize = _getFontSize();
    final fontWeight = _getFontWeight();

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.5,
    );
  }

  /// Obtener altura del botón según el tamaño
  double _getButtonHeight() {
    switch (size) {
      case ButtonSize.small:
        return 32;
      case ButtonSize.medium:
        return 40;
      case ButtonSize.large:
        return 48;
      case ButtonSize.extraLarge:
        return 56;
    }
  }

  /// Obtener padding del botón según el tamaño
  EdgeInsetsGeometry _getButtonPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case ButtonSize.extraLarge:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  /// Obtener tamaño de fuente según el tamaño del botón
  double _getFontSize() {
    switch (size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 14;
      case ButtonSize.large:
        return 16;
      case ButtonSize.extraLarge:
        return 18;
    }
  }

  /// Obtener peso de fuente
  FontWeight _getFontWeight() {
    return FontWeight.w600;
  }

  /// Obtener tamaño del icono según el tamaño del botón
  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 20;
      case ButtonSize.extraLarge:
        return 22;
    }
  }

  /// Obtener tamaño del loading indicator
  double _getLoadingSize() {
    switch (size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 18;
      case ButtonSize.extraLarge:
        return 20;
    }
  }

  /// Obtener color del loading indicator
  Color _getLoadingColor() {
    switch (type) {
      case ButtonType.primary:
      case ButtonType.danger:
      case ButtonType.success:
        return Colors.white;
      case ButtonType.secondary:
      case ButtonType.text:
      case ButtonType.outline:
        return customColor ?? Colors.blue;
    }
  }
}

/// Botón de icono personalizado
class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final ButtonSize size;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isLoading;
  final BorderRadius? borderRadius;

  const CustomIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = ButtonSize.medium,
    this.backgroundColor,
    this.iconColor,
    this.isLoading = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonSize = _getButtonSize();
    final iconSize = _getIconSize();

    Widget button = Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.primaryColor.withOpacity(0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize * 0.8,
                    height: iconSize * 0.8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        iconColor ?? theme.primaryColor,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    size: iconSize,
                    color: iconColor ?? theme.primaryColor,
                  ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }

  double _getButtonSize() {
    switch (size) {
      case ButtonSize.small:
        return 32;
      case ButtonSize.medium:
        return 40;
      case ButtonSize.large:
        return 48;
      case ButtonSize.extraLarge:
        return 56;
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
      case ButtonSize.extraLarge:
        return 28;
    }
  }
}

/// Botón flotante personalizado (FAB)
class CustomFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isLoading;
  final bool isExtended;
  final String? label;

  const CustomFloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.iconColor,
    this.isLoading = false,
    this.isExtended = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isExtended && label != null) {
      return FloatingActionButton.extended(
        onPressed: isLoading ? null : onPressed,
        backgroundColor: backgroundColor ?? theme.primaryColor,
        foregroundColor: iconColor ?? Colors.white,
        tooltip: tooltip,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon),
        label: Text(label!),
      );
    }

    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: backgroundColor ?? theme.primaryColor,
      foregroundColor: iconColor ?? Colors.white,
      tooltip: tooltip,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon),
    );
  }
}
