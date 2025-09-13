import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassmorphismInput extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final IconData? prefixIcon;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const GlassmorphismInput({
    super.key,
    this.labelText,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.onTap,
    this.validator,
    this.onChanged,
  });

  @override
  State<GlassmorphismInput> createState() => _GlassmorphismInputState();
}

class _GlassmorphismInputState extends State<GlassmorphismInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _focusController;
  late Animation<double> _focusAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  void _requestFocus() {
    setState(() {
      _isFocused = true;
      _focusController.forward();
    });
  }

  void _loseFocus() {
    setState(() {
      _isFocused = false;
      _focusController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16), // Medium rounded (xl)
            border: Border.all(
              color: _isFocused
                  ? AppColors.electricBlue.withOpacity(0.5)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            maxLines: widget.maxLines,
            onTap: widget.onTap,
            validator: widget.validator,
            onChanged: widget.onChanged,
            style: const TextStyle(
              color: AppColors.textColor,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused
                          ? AppColors.electricBlue
                          : AppColors.secondaryTextColor,
                    )
                  : null,
              labelStyle: TextStyle(
                color: _isFocused
                    ? AppColors.electricBlue
                    : AppColors.secondaryTextColor,
                fontFamily: 'Poppins',
              ),
              hintStyle: const TextStyle(
                color: AppColors.secondaryTextColor,
                fontFamily: 'Poppins',
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
            onTapOutside: (event) => _loseFocus(),
            onEditingComplete: _loseFocus,
          ),
        );
      },
    );
  }
}