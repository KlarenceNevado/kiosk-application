import 'package:flutter/material.dart';
import '../widgets/virtual_keyboard.dart';

mixin VirtualKeyboardMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();
  bool isKeyboardVisible = false;

  void showKeyboard(
    TextEditingController controller,
    GlobalKey? fieldKey, {
    KeyboardType type = KeyboardType.text,
    int? maxLength,
  }) {
    // If the keyboard is already open, just ensure the field is visible
    if (isKeyboardVisible) {
      if (fieldKey?.currentContext != null) {
        Scrollable.ensureVisible(
          fieldKey!.currentContext!,
          alignment: 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    setState(() => isKeyboardVisible = true);

    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: VirtualKeyboard(
          controller: controller,
          type: type,
          maxLength: maxLength,
          onSubmit: () => Navigator.pop(ctx),
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => isKeyboardVisible = false);
        if (scrollController.hasClients) {
          scrollController.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      }
    });

    if (fieldKey?.currentContext != null) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (fieldKey?.currentContext == null) return;
        Scrollable.ensureVisible(
          fieldKey!.currentContext!,
          alignment: 0.0, // Push field to the very top to avoid keyboard overlap
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }
}
