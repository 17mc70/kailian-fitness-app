import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';

/// Apple-style search field with cancel button and clear icon.
class KLSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onCancel;
  final FocusNode? focusNode;
  final bool isFocused;

  const KLSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.onCancel,
    this.focusNode,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText ?? '搜索',
          hintStyle: TextStyle(color: colors.placeholder, fontSize: 15),
          prefixIcon: Icon(Icons.search, size: 20, color: colors.placeholder),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller ?? TextEditingValueNotifier(),
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  (controller ?? TextEditingController()).clear();
                  onChanged?.call('');
                  onClear?.call();
                },
                child: Icon(Icons.cancel, size: 18, color: colors.placeholder),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

/// Helper to provide a ValueNotifier for TextEditingController when null.
class TextEditingValueNotifier extends ValueNotifier<TextEditingValue> {
  TextEditingValueNotifier() : super(TextEditingValue.empty);
}
