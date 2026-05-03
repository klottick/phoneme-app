import 'package:flutter/material.dart';

class IpaKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onClear;

  const IpaKeyboard({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow([
            'æ', 'ɑ', 'ʌ', 'ə', 'ɪ', 'iː', 'uː', 'ʊ',
          ]),
          _buildRow([
            'eɪ', 'aɪ', 'ɔɪ', 'əʊ', 'aʊ', 'ɪə', 'eə', 'ʊə',
          ]),
          _buildRow([
            'p', 'b', 't', 'd', 'k', 'g', 'f', 'v',
          ]),
          _buildRow([
            'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'h', 'm',
          ]),
          _buildRow([
            'n', 'ŋ', 'l', 'r', 'j', 'w', 'ɒ', 'ɔː',
          ]),
          _buildRow([
            'ɜː', 'ɜ', 'ɑː', 'ɔ', 'ʊ', 'i', 'u', 'ɜ',
          ]),
          _buildActionRow(),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((k) => _KeyButton(
          character: k,
          onPressed: () => onKeyPressed(k),
        )).toList(),
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.clear,
            onPressed: onClear,
            label: 'Clear',
          ),
          _ActionButton(
            icon: Icons.backspace_outlined,
            onPressed: onBackspace,
            label: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String character;
  final VoidCallback onPressed;

  const _KeyButton({required this.character, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Text(
            character,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;

  const _ActionButton({
    required this.icon,
    this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class IpaTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool autofocus;

  const IpaTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.autofocus = false,
  });

  @override
  State<IpaTextField> createState() => _IpaTextFieldState();
}

class _IpaTextFieldState extends State<IpaTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.keyboard),
              onPressed: () => _showKeyboard(context),
            ),
          ),
          onTap: () => _showKeyboard(context),
        ),
        if (_focusNode.hasFocus)
          SizedBox(
            height: 200,
            child: IpaKeyboard(
              onKeyPressed: (key) {
                widget.controller.text += key;
              },
              onBackspace: () {
                if (widget.controller.text.isNotEmpty) {
                  widget.controller.text = widget.controller.text
                      .substring(0, widget.controller.text.length - 1);
                }
              },
              onClear: () {
                widget.controller.clear();
              },
            ),
          ),
      ],
    );
  }

  void _showKeyboard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => IpaKeyboard(
        onKeyPressed: (key) {
          widget.controller.text += key;
          Navigator.pop(context);
        },
        onBackspace: () {
          if (widget.controller.text.isNotEmpty) {
            widget.controller.text = widget.controller.text
                .substring(0, widget.controller.text.length - 1);
          }
        },
        onClear: () {
          widget.controller.clear();
        },
      ),
    );
  }
}