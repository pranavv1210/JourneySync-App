import 'package:flutter/material.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

Route<T> buildAppRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0.018, 0.012),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
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
