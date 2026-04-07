import 'package:flutter/material.dart';

Future<void> showLegalDocumentDialog({
  required BuildContext context,
  required String title,
  required String content,
  TextStyle? contentStyle,
  TextStyle? titleStyle,
  Color? actionColor,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title, style: titleStyle),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(content, style: contentStyle),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: actionColor ?? Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
}
