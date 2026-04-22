import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

enum KeyboardType { text, numeric }

enum ShiftState { none, shift, capsLock }

class VirtualKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final KeyboardType type;
  final VoidCallback? onSubmit;
  final int? maxLength;

  const VirtualKeyboard({
    super.key,
    required this.controller,
    this.type = KeyboardType.text,
    this.onSubmit,
    this.maxLength,
  });

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  ShiftState _shiftState = ShiftState.none;
  bool _isSymbols = false;
  Timer? _backspaceTimer;

  final List<String> _rowsText = [
    "1234567890",
    "QWERTYUIOP",
    "ASDFGHJKL",
    "ZXCVBNM",
  ];

  final List<String> _rowsSymbols = [
    "1234567890",
    "@#\$_&-+()/",
    "*\"':;!?,.~",
    "\\|<=>[]{}",
  ];

  void _onKeyTap(String val) {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    if (widget.maxLength != null &&
        widget.controller.text.length >= widget.maxLength!) {
      return;
    }
    if (widget.maxLength == null && widget.controller.text.length >= 100) {
      return;
    }

    String text = val;

    if (widget.type == KeyboardType.text && !_isSymbols) {
      if (_shiftState == ShiftState.shift ||
          _shiftState == ShiftState.capsLock) {
        text = val.toUpperCase();
      } else {
        text = val.toLowerCase();
      }
    }

    final currentText = widget.controller.text;
    final selection = widget.controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0) {
      start = currentText.length;
      end = currentText.length;
    }

    final newText = currentText.replaceRange(start, end, text);
    final newCursor = start + text.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    // If it was just a regular shift, turn it off after one key
    if (_shiftState == ShiftState.shift && !_isSymbols) {
      setState(() => _shiftState = ShiftState.none);
    }
  }

  void _onBackspace() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    final currentText = widget.controller.text;
    if (currentText.isEmpty) return;

    final selection = widget.controller.selection;
    int start = selection.start;
    int end = selection.end;

    if (start < 0) {
      start = currentText.length;
      end = currentText.length;
    }

    String newText;
    int newCursor;

    if (start == end) {
      if (start == 0) return;
      newText = currentText.replaceRange(start - 1, start, '');
      newCursor = start - 1;
    } else {
      newText = currentText.replaceRange(start, end, '');
      newCursor = start;
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  void _startBackspaceTimer() {
    _onBackspace();
    _backspaceTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _onBackspace();
    });
  }

  void _stopBackspaceTimer() {
    _backspaceTimer?.cancel();
  }

  void _onSpace() {
    _onKeyTap(" ");
  }

  @override
  void dispose() {
    _backspaceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB), // Lighter, more modern grey
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4), // Balanced shadow
            )
          ]),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: widget.type == KeyboardType.numeric
          ? _buildNumericPad()
          : _buildFullBoard(),
    );
  }

  Widget _buildFullBoard() {
    final rows = _isSymbols ? _rowsSymbols : _rowsText;
    const double keyHeight = 62.0;
    const double rowSpacing = 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFlexibleRow(rows[0], keyHeight),
        const SizedBox(height: rowSpacing),
        _buildFlexibleRow(rows[1], keyHeight),
        const SizedBox(height: rowSpacing),
        _buildFlexibleRow(rows[2], keyHeight, paddingHorizontal: 12.0),
        const SizedBox(height: rowSpacing),

        // Row 4
        Row(
          children: [
            _buildActionKey(
              icon: _isSymbols
                  ? Icons.numbers
                  : (_shiftState == ShiftState.capsLock
                      ? Icons.keyboard_capslock_rounded
                      : (_shiftState == ShiftState.shift
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_upward_outlined)),
              color: (_shiftState != ShiftState.none && !_isSymbols)
                  ? AppColors.brandGreen
                  : Colors.white,
              iconColor: (_shiftState != ShiftState.none && !_isSymbols)
                  ? Colors.white
                  : Colors.black87,
              onTap: () {
                if (_isSymbols) return; // Do nothing if symbols are open
                setState(() {
                  if (_shiftState == ShiftState.none) {
                    _shiftState = ShiftState.shift;
                  } else if (_shiftState == ShiftState.shift) {
                    _shiftState = ShiftState.capsLock;
                  } else {
                    _shiftState = ShiftState.none;
                  }
                });
              },
              label: _isSymbols ? "#+=" : null,
              flex: 3,
              height: keyHeight,
            ),
            const SizedBox(width: 4),
            ...rows[3]
                .split('')
                .map((e) => _buildExpandedKey(e, height: keyHeight)),
            const SizedBox(width: 4),
            _buildBackspaceKey(flex: 3, height: keyHeight),
          ],
        ),

        const SizedBox(height: rowSpacing),

        // Row 5
        Row(
          children: [
            _buildActionKey(
              label: _isSymbols ? "ABC" : "?123",
              onTap: () => setState(() => _isSymbols = !_isSymbols),
              flex: 3,
              height: keyHeight,
              color: Colors.grey[200]!,
            ),
            const SizedBox(width: 4),
            _buildExpandedKey(",", height: keyHeight, flex: 2),
            const SizedBox(width: 4),
            _buildExpandedKey("SPACE",
                height: keyHeight, flex: 9, onTap: _onSpace),
            const SizedBox(width: 4),
            _buildExpandedKey(".", height: keyHeight, flex: 2),
            const SizedBox(width: 4),
            _buildActionKey(
              icon: Icons.check_rounded,
              label: "DONE",
              color: AppColors.brandGreen,
              iconColor: Colors.white,
              onTap: widget.onSubmit ?? () => Navigator.pop(context),
              flex: 4,
              height: keyHeight,
              isDark: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumericPad() {
    const double keyHeight = 72.0;
    const double spacing = 10.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNumRow(["1", "2", "3"], keyHeight, spacing),
        const SizedBox(height: spacing),
        _buildNumRow(["4", "5", "6"], keyHeight, spacing),
        const SizedBox(height: spacing),
        _buildNumRow(["7", "8", "9"], keyHeight, spacing),
        const SizedBox(height: spacing),
        Row(
          children: [
            _buildActionKey(
                icon: Icons.keyboard_hide_rounded,
                onTap: () => Navigator.pop(context),
                flex: 1,
                height: keyHeight),
            const SizedBox(width: spacing),
            _buildExpandedKey("0", height: keyHeight, flex: 1, isNumeric: true),
            const SizedBox(width: spacing),
            _buildBackspaceKey(flex: 1, height: keyHeight),
          ],
        ),
      ],
    );
  }

  Widget _buildNumRow(List<String> keys, double height, double spacing) {
    return Row(
      children: keys.asMap().entries.map((entry) {
        int idx = entry.key;
        String val = entry.value;
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: idx == keys.length - 1 ? 0 : spacing),
            child: _buildKeyWidget(val, height: height, isNumeric: true),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlexibleRow(String chars, double height,
      {double paddingHorizontal = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
      child: Row(
        children: chars.split('').map((e) {
          return _buildExpandedKey(e, height: height);
        }).toList(),
      ),
    );
  }

  Widget _buildExpandedKey(String label,
      {double height = 48,
      int flex = 1,
      VoidCallback? onTap,
      bool isNumeric = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0),
        child: _buildKeyWidget(label,
            height: height, onTap: onTap, isNumeric: isNumeric),
      ),
    );
  }

  Widget _buildKeyWidget(String label,
      {double height = 48, VoidCallback? onTap, bool isNumeric = false}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap ?? () => _onKeyTap(label),
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.brandGreen.withValues(alpha: 0.1),
        highlightColor: AppColors.brandGreen.withValues(alpha: 0.05),
        child: Container(
          height: height,
          alignment: Alignment.center,
          child: Text(
            (int.tryParse(label) != null || _isSymbols || label.length > 1)
                ? label
                : (_shiftState != ShiftState.none
                    ? label.toUpperCase()
                    : label.toLowerCase()),
            style: TextStyle(
              fontSize: isNumeric ? 32 : (label.length > 1 ? 16 : 22),
              fontWeight: isNumeric ? FontWeight.w600 : FontWeight.w500,
              color: label == "SPACE" ? Colors.grey : Colors.black87,
              fontFamily: isNumeric ? null : 'sans-serif',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey({int flex = 1, double height = 48}) {
    return Expanded(
      flex: flex,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTapDown: (_) => _startBackspaceTimer(),
          onTapUp: (_) => _stopBackspaceTimer(),
          onTapCancel: () => _stopBackspaceTimer(),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.withValues(alpha: 0.2),
          child: Container(
            height: height,
            alignment: Alignment.center,
            child: const Icon(Icons.backspace_outlined,
                color: Colors.black, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    IconData? icon,
    String? label,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = Colors.black,
    int flex = 1,
    double height = 48,
    bool isDark = false,
  }) {
    return Expanded(
      flex: flex,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        elevation: isDark ? 4 : 1,
        shadowColor: isDark
            ? AppColors.brandGreen.withValues(alpha: 0.4)
            : Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.brandGreen.withValues(alpha: 0.1),
          child: Container(
            height: height,
            alignment: Alignment.center,
            child: label != null
                ? Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : iconColor,
                        letterSpacing: 0.5))
                : Icon(icon, color: iconColor, size: 28),
          ),
        ),
      ),
    );
  }
}
