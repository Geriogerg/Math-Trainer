import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/state/session_controller.dart';
import '../exercise_prompt.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// Plus longue réponse possible : 10⁵ (puissances) ; 7 laisse une marge sans
/// laisser une saisie folle déborder de l'écran.
const _maxTypedDigits = 7;

/// Rangée des chiffres *physique*, pas logique : sur un clavier AZERTY, ces
/// touches produisent « & é " ' ( - è _ ç à » sans Maj — le joueur doit
/// pouvoir taper les chiffres sans Maj, comme sur un pavé numérique.
final _digitKeys = {
  PhysicalKeyboardKey.digit0: '0',
  PhysicalKeyboardKey.digit1: '1',
  PhysicalKeyboardKey.digit2: '2',
  PhysicalKeyboardKey.digit3: '3',
  PhysicalKeyboardKey.digit4: '4',
  PhysicalKeyboardKey.digit5: '5',
  PhysicalKeyboardKey.digit6: '6',
  PhysicalKeyboardKey.digit7: '7',
  PhysicalKeyboardKey.digit8: '8',
  PhysicalKeyboardKey.digit9: '9',
  PhysicalKeyboardKey.numpad0: '0',
  PhysicalKeyboardKey.numpad1: '1',
  PhysicalKeyboardKey.numpad2: '2',
  PhysicalKeyboardKey.numpad3: '3',
  PhysicalKeyboardKey.numpad4: '4',
  PhysicalKeyboardKey.numpad5: '5',
  PhysicalKeyboardKey.numpad6: '6',
  PhysicalKeyboardKey.numpad7: '7',
  PhysicalKeyboardKey.numpad8: '8',
  PhysicalKeyboardKey.numpad9: '9',
};

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> with TickerProviderStateMixin {
  String _typedDigits = '';
  bool? _feedbackCorrect;

  late final AnimationController _chronoController;
  late final AnimationController _feedbackController;

  @override
  void initState() {
    super.initState();
    _chronoController = AnimationController(
      vsync: this,
      duration: widget.controller.questionTimeout,
    )..forward();
    // Durée réelle posée juste avant chaque .forward() (AppMotion.feedback,
    // lu depuis le thème — indisponible ici, avant le premier frame).
    _feedbackController = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void didUpdateWidget(covariant SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nouvelle question : le contrôleur est le même objet d'une question à
    // l'autre (seul son état interne change), donc c'est le seul signal
    // fiable — comparer les exercices par valeur risquerait de rater un
    // redémarrage si la même opération revient deux fois d'affilée.
    _chronoController.forward(from: 0);

    // Un timeout fait avancer la session sans passer par _submit() (aucune
    // touche « valider » pressée) : sans ce contrôle, il n'y aurait aucun
    // flash/haptique, alors qu'un timeout compte comme une réponse fausse et
    // doit se voir au même titre (règle 14).
    final outcomes = widget.controller.state.outcomes;
    final lastOutcome = outcomes.isEmpty ? null : outcomes.last;
    if (lastOutcome != null && lastOutcome.isTimeout) {
      _playFeedback(false);
    }
  }

  @override
  void dispose() {
    _chronoController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    widget.controller.registerActivity();
    if (_typedDigits.length >= _maxTypedDigits) return;
    setState(() => _typedDigits += digit);
  }

  /// Clavier physique (web, ordinateur, tablette avec clavier) : sans lui,
  /// chaque chiffre se clique à la souris sur le pavé — le jeu se vend sur la
  /// vitesse. Mêmes chemins que le pavé tactile, donc même chronométrage et
  /// même détection d'activité.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final digit = _digitKeys[event.physicalKey];
    if (digit != null) {
      _appendDigit(digit);
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      // Pas de répétition : garder Entrée enfoncé ne doit pas valider la
      // question suivante avant même qu'elle soit lue.
      if (event is KeyDownEvent) _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _backspace() {
    widget.controller.registerActivity();
    if (_typedDigits.isEmpty) return;
    setState(() => _typedDigits = _typedDigits.substring(0, _typedDigits.length - 1));
  }

  void _submit() {
    final exercise = widget.controller.state.currentExercise;
    if (exercise == null) return;
    final value = int.tryParse(_typedDigits);
    if (value == null) return;

    // Calculé avant `submitAnswer` : le domaine expose déjà `isCorrectAnswer`,
    // pas besoin d'attendre le contrôleur pour savoir quel flash déclencher.
    // `submitAnswer` est appelé tout de suite après, sans délai — le
    // chronométrage interne du contrôleur (qui sert au score) reste exact.
    final isCorrect = exercise.isCorrectAnswer(value);
    widget.controller.submitAnswer(value);
    _playFeedback(isCorrect);
  }

  /// Partagé entre une validation explicite et un timeout (`didUpdateWidget`)
  /// — dans les deux cas la réponse à la question qui vient de se terminer
  /// est connue, seule la source du déclenchement diffère.
  void _playFeedback(bool isCorrect) {
    HapticFeedback.lightImpact();
    if (!isCorrect) HapticFeedback.heavyImpact();

    final motion = Theme.of(context).extension<AppMotion>()!.feedback;
    _feedbackController.duration = motion.duration;
    setState(() {
      _typedDigits = '';
      _feedbackCorrect = isCorrect;
    });
    _feedbackController.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _feedbackCorrect = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final exercise = state.currentExercise;
    if (exercise == null) {
      return EmptyState(
        message: 'Aucune question à afficher.',
        actionLabel: 'Quitter',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }

    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final level = widget.controller.config.levels[exercise.type] ?? 1;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        children: [
          Padding(
            padding: metrics.rootPadding,
            child: _TopBar(
              questionIndex: state.outcomes.length + 1,
              totalQuestions: widget.controller.config.exerciseCount,
              chrono: _chronoController,
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // Série visible seulement si > 0 : pas de bruit « série 0 »
                    // à chaque première question (`doc/decisions.md` —
                    // currentStreak affiché pendant la session).
                    state.currentStreak > 0
                        ? '${exerciseTypeLabel(exercise.type)} · niveau $level · série ${state.currentStreak}'
                        : '${exerciseTypeLabel(exercise.type)} · niveau $level',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.extension<AppPalette>()!.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: theme.extension<AppMotion>()!.questionTransition.duration,
                    switchInCurve: theme.extension<AppMotion>()!.questionTransition.curve,
                    switchOutCurve: theme.extension<AppMotion>()!.questionTransition.curve,
                    child: ExercisePrompt(key: ValueKey(exercise), exercise: exercise),
                  ),
                  const SizedBox(height: 24),
                  _AnswerDisplay(
                    typedDigits: _typedDigits,
                    feedback: _feedbackController,
                    feedbackCorrect: _feedbackCorrect,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            // Hauteur fixe en premier, l'opération prend ce qu'il reste
            // au-dessus (`Expanded`) — rien ne bouge entre deux questions
            // (`doc/design.md` : jamais un ratio d'écran, voir `AppMetrics`).
            height: metrics.keypadHeight,
            child: _NumericKeypad(onDigit: _appendDigit, onBackspace: _backspace, onValidate: _submit),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.questionIndex, required this.totalQuestions, required this.chrono});

  final int questionIndex;
  final int totalQuestions;
  final Animation<double> chrono;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$questionIndex / $totalQuestions',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AnimatedBuilder(
            animation: chrono,
            builder: (context, _) => LinearProgressIndicator(
              value: 1 - chrono.value,
              minHeight: 4,
              backgroundColor: colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Réponse en cours de saisie. Le flash/mouvement de feedback (règle 14 :
/// jamais la couleur seule) s'applique ici, pas à l'écran entier
/// (`doc/design.md` : « flash [...] sur le champ de saisie »).
class _AnswerDisplay extends StatelessWidget {
  const _AnswerDisplay({
    required this.typedDigits,
    required this.feedback,
    required this.feedbackCorrect,
  });

  final String typedDigits;
  final Animation<double> feedback;
  final bool? feedbackCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineMedium;
    final text = Text(typedDigits, style: style);

    return AnimatedBuilder(
      animation: feedback,
      builder: (context, child) {
        final correct = feedbackCorrect;
        if (correct == null) return child!;

        final t = feedback.value;
        final flashColor = correct ? theme.colorScheme.onSurface : theme.colorScheme.error;
        final opacity = (1 - t).clamp(0.0, 1.0);
        // Mise à l'échelle 1,0 → 1,06 → 1,0 (doc/design.md) : une bosse en
        // sinus atteint son maximum au milieu de l'animation.
        final scale = correct ? 1.0 + 0.06 * math.sin(t * math.pi) : 1.0;
        // Secousse horizontale amortie : oscille puis se stabilise.
        final shakeDx = correct ? 0.0 : 8 * math.sin(t * math.pi * 4) * (1 - t);

        return Transform.translate(
          offset: Offset(shakeDx, 0),
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: flashColor.withValues(alpha: opacity * 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child),
            ),
          ),
        );
      },
      child: text,
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({required this.onDigit, required this.onBackspace, required this.onValidate});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onValidate;

  static const _digitRows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _digitRows)
          Expanded(
            child: Row(
              children: [
                for (final digit in row)
                  Expanded(child: _KeypadKey(label: digit, onTap: () => onDigit(digit))),
              ],
            ),
          ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _KeypadKey(icon: Icons.backspace_outlined, semanticLabel: 'Effacer', onTap: onBackspace),
              ),
              Expanded(child: _KeypadKey(label: '0', onTap: () => onDigit('0'))),
              Expanded(
                child: _KeypadKey(icon: Icons.check, semanticLabel: 'Valider', onTap: onValidate, isPrimary: true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Touche/valider en `Surface`, valider en `Accent` (« action principale »,
/// doc/design.md). Animation d'enfoncement 60 ms easeOut (`AppMotion.
/// keyPress`, posée au commit A, premier consommateur ici).
class _KeypadKey extends StatefulWidget {
  const _KeypadKey({this.label, this.icon, this.semanticLabel, required this.onTap, this.isPrimary = false});

  final String? label;
  final IconData? icon;

  /// Lu par les lecteurs d'écran pour les touches sans texte (icônes).
  final String? semanticLabel;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final motion = theme.extension<AppMotion>()!.keyPress;
    final background = widget.isPrimary ? colorScheme.primary : colorScheme.surfaceContainerHigh;
    final foreground = widget.isPrimary ? colorScheme.onPrimary : colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: motion.duration,
        curve: motion.curve,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(widget.icon, color: foreground, semanticLabel: widget.semanticLabel)
              : Text(widget.label!, style: theme.textTheme.displaySmall?.copyWith(color: foreground)),
        ),
      ),
    );
  }
}
