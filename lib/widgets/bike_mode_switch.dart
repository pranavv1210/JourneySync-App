import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Website-inspired Ride Mode toggle: an animated orange ON state and a calm
/// grey OFF state, with the motorcycle/call icon travelling inside the thumb.
class BikeModeSwitch extends StatefulWidget {
  const BikeModeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.busy = false,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  State<BikeModeSwitch> createState() => _BikeModeSwitchState();
}

class _BikeModeSwitchState extends State<BikeModeSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.value ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant BikeModeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.animateTo(
      widget.value ? 1 : 0,
      duration: Duration(milliseconds: reduceMotion ? 1 : 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.busy) return;
    HapticFeedback.selectionClick();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      container: true,
      button: true,
      toggled: widget.value,
      label: 'Ride Mode',
      value: widget.value ? 'On' : 'Off',
      hint: widget.value
          ? 'Double tap to turn off call handling'
          : 'Double tap to enable call handling',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: SizedBox(
            width: 132,
            height: 54,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final activeColor = Color.lerp(
                  const Color(0xFF9E9D98),
                  AppColors.primary,
                  t,
                )!;
                return AnimatedContainer(
                  duration: Duration(milliseconds: reduceMotion ? 1 : 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 15,
                        child: Opacity(
                          opacity: 1 - t,
                          child: const Text(
                            'OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 15,
                        child: Opacity(
                          opacity: t,
                          child: const Text(
                            'ON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.lerp(
                          Alignment.centerLeft,
                          Alignment.centerRight,
                          Curves.easeOutCubic.transform(t),
                        )!,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFEFA),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: AnimatedSwitcher(
                              duration: Duration(
                                milliseconds: reduceMotion ? 1 : 240,
                              ),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                              child: Icon(
                                widget.value
                                    ? Icons.two_wheeler_rounded
                                    : Icons.phone_in_talk_rounded,
                                key: ValueKey<bool>(widget.value),
                                size: 23,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.busy)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
