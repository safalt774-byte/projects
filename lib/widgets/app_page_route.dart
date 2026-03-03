import 'package:flutter/material.dart';
import 'package:projects/services/app_feedback_service.dart';

/// Custom animated page transitions with sound + haptic feedback.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute.slideUp({required Widget page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, anim, secondaryAnim, child) {
            if (anim.status == AnimationStatus.forward && anim.value < 0.05) {
              AppFeedbackService.hapticLight();
            }
            final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );

  AppPageRoute.fadeScale({required Widget page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, anim, secondaryAnim, child) {
            if (anim.status == AnimationStatus.forward && anim.value < 0.05) {
              AppFeedbackService.hapticLight();
            }
            final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );

  AppPageRoute.slideLeft({required Widget page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, anim, secondaryAnim, child) {
            if (anim.status == AnimationStatus.forward && anim.value < 0.05) {
              AppFeedbackService.hapticLight();
            }
            final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
}

