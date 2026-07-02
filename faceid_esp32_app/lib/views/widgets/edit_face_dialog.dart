import 'package:flutter/material.dart';

class EditFaceDialog extends StatefulWidget {
  final String initialLabel;

  const EditFaceDialog({super.key, required this.initialLabel});

  @override
  State<EditFaceDialog> createState() => _EditFaceDialogState();
}

class _EditFaceDialogState extends State<EditFaceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa nhãn khuôn mặt'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nhãn',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}