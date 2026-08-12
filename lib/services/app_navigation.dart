import 'package:flutter/material.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

Route<T> buildAppRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final fade = Tween<double>(begin: 0, end: 1).animate(curve);
      final slide = Tween<Offset>(
        begin: const Offset(0.025, 0.018),
        end: Offset.zero,
      ).animate(curve);
      final scale = Tween<double>(begin: 0.985, end: 1).animate(curve);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
  );
}

Future<T?> pushAppRoute<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(buildAppRoute<T>(page));
}

Future<T?> replaceWithAppRoute<T, TO>(BuildContext context, Widget page) {
  return Navigator.of(context).pushReplacement<T, TO>(buildAppRoute<T>(page));
}
