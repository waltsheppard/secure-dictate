import 'package:flutter/material.dart';
import 'package:authapp1/theme/app_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.maxContentWidth = 480,
    this.showCard = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double maxContentWidth;
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
    if (showCard) {
      content = Card(child: content);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: content,
          ),
        ),
      ),
    );
  }
}
