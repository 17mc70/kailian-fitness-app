import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';

/// Apple-style scaffold with large-title sliver support and blur nav area.
class KLScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const KLScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.systemBackground,
      appBar: appBar,
      body: body,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
