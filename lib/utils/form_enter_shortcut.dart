import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intent personnalisé pour déclencher l'action principale d'un formulaire (Enregistrer)
class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
}

/// Action qui gère la soumission de formulaire via la touche Entrée
class SubmitFormAction extends Action<SubmitFormIntent> {
  SubmitFormAction(this.onSubmit);

  final VoidCallback onSubmit;

  @override
  void invoke(SubmitFormIntent intent) {
    onSubmit();
  }
}

/// Widget qui enveloppe un formulaire et active la soumission avec Entrée
///
/// Règles :
/// - Entrée déclenche [onSubmit] uniquement si le focus n'est pas dans un TextField multi-ligne
/// - Si [formKey] est fourni, valide le formulaire avant de soumettre
/// - Si la validation échoue, met le focus sur le premier champ invalide
class FormWithEnterShortcut extends StatelessWidget {
  const FormWithEnterShortcut({
    super.key,
    required this.child,
    required this.onSubmit,
    this.formKey,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onSubmit;
  final GlobalKey<FormState>? formKey;
  final bool enabled;

  void _handleSubmit(BuildContext context) {
    if (!enabled) return;

    // Vérifier si le focus est dans un TextField multi-ligne
    final FocusNode? focusedNode = FocusManager.instance.primaryFocus;
    if (focusedNode != null && focusedNode.context != null) {
      final widget = focusedNode.context!.widget;
      // Si c'est un EditableText (utilisé par TextField) avec maxLines > 1, ignorer
      if (widget is EditableText &&
          (widget.maxLines == null || widget.maxLines! > 1)) {
        return;
      }
    }

    // Si un formKey est fourni, valider le formulaire
    if (formKey != null) {
      final formState = formKey!.currentState;
      if (formState != null) {
        if (!formState.validate()) {
          // Validation échouée : chercher le premier champ invalide et y mettre le focus
          _focusFirstInvalidField(context);
          return;
        }
      }
    }

    // Tout est OK : soumettre
    onSubmit();
  }

  /// Trouve et met le focus sur le premier champ invalide
  void _focusFirstInvalidField(BuildContext context) {
    // Retarder légèrement pour laisser le temps aux erreurs de s'afficher
    Future.delayed(const Duration(milliseconds: 100), () {
      // Parcourir l'arbre de widgets pour trouver le premier FormField avec erreur
      context.visitChildElements((element) {
        _findFirstInvalidField(element);
      });
    });
  }

  bool _findFirstInvalidField(Element element) {
    bool found = false;
    element.visitChildElements((child) {
      if (found) return;

      final widget = child.widget;
      if (widget is FormField) {
        // Vérifier si le champ a une erreur
        final state = (child as StatefulElement).state as FormFieldState;
        if (state.hasError) {
          // Chercher le FocusNode associé
          child.visitChildElements((grandChild) {
            final gcWidget = grandChild.widget;
            if (gcWidget is Focus || gcWidget is FocusScope) {
              final focusNode = (gcWidget as dynamic).focusNode as FocusNode?;
              if (focusNode != null &&
                  focusNode.context != null &&
                  focusNode.canRequestFocus) {
                focusNode.requestFocus();
                found = true;
              }
            }
          });
          if (!found) {
            // Essayer de trouver un TextField enfant
            _findAndFocusTextField(child);
            found = true;
          }
          return;
        }
      }

      if (!found) {
        found = _findFirstInvalidField(child);
      }
    });
    return found;
  }

  void _findAndFocusTextField(Element element) {
    element.visitChildElements((child) {
      final widget = child.widget;
      if (widget is TextField || widget is TextFormField) {
        final focusNode = (widget as dynamic).focusNode as FocusNode?;
        if (focusNode != null &&
            focusNode.context != null &&
            focusNode.canRequestFocus) {
          focusNode.requestFocus();
          return;
        }
      }
      _findAndFocusTextField(child);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): SubmitFormIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): SubmitFormIntent(),
      },
      child: Actions(
        actions: {
          SubmitFormIntent: SubmitFormAction(() => _handleSubmit(context)),
        },
        child: child,
      ),
    );
  }
}

/// Extension pour simplifier l'utilisation sur les formulaires existants
extension FormEnterShortcutExtension on Widget {
  /// Enveloppe le widget avec le raccourci Entrée pour soumettre
  Widget withEnterToSubmit({
    required VoidCallback onSubmit,
    GlobalKey<FormState>? formKey,
    bool enabled = true,
  }) {
    return FormWithEnterShortcut(
      onSubmit: onSubmit,
      formKey: formKey,
      enabled: enabled,
      child: this,
    );
  }
}
