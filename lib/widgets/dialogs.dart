import 'package:flutter/material.dart';

Future<String?> promptForInput({
  required BuildContext context,
  required String title,
  required String label,
  TextInputType keyboard = TextInputType.text,
  bool obscure = false,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboard,
        obscureText: obscure,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('OK')),
      ],
    ),
  );
  controller.dispose();
  return result;
}



