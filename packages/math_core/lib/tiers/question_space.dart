import 'dart:math';

import '../models/exercise.dart';
import '../models/operation_type.dart';

/// Rules v9's drawing machinery (`doc/levels.md` v1.6, section 5, "Drawing
/// rules"): every tier's standard content and every pattern family at every
/// tier is a [QuestionSpace] — a finite set of distinct questions — drawn
/// **uniformly over its distinct questions** and, within a game, **without
/// repeating a question** while the space has unused ones, **never twice in
/// a row** once it has none ([OperationDraws]).
///
/// A space is described by [Form]s: products of value axes, each tuple
/// built into a question (rule 10: the parts first, the answer computed).
/// A space of at most [listLimit] tuples is listed once — every distinct
/// question once, commutative forms merged (4 + 5 = 5 + 4) — and drawn by
/// index: exactly uniform. A larger one (long sums from T3 on) is drawn axis
/// by axis, **each form an equal share** — every size a row names stays in
/// the mix ("7- and 8-digit numbers": 7 + 7 a third of T8, not the 0.8 %
/// its count would give) — and uniform over a form's tuples. No question of
/// such a space is ever more likely than one in 10⁵, so the rule's point
/// (no favoured question) holds; a sum of two equal numbers is half as
/// likely as another.
///
/// Neither ever draws and rejects (rule 10): a listed space draws an index
/// among the questions it may still ask; a large one, on the rare question
/// already asked, steps to the next tuple in a fixed order.

/// One axis of a [Form]: [count] values, the i-th by [at].
final class Axis {
  const Axis._(this.count, this._first, this._values);

  /// [min] to [max], both included.
  factory Axis.range(int min, int max) {
    if (max < min) throw ArgumentError.value((min, max), 'range', 'is empty.');
    return Axis._(max - min + 1, min, null);
  }

  /// Exactly [values], in that order.
  factory Axis.of(List<int> values) {
    if (values.isEmpty) throw ArgumentError.value(values, 'values', 'empty.');
    return Axis._(values.length, 0, List.unmodifiable(values));
  }

  final int count;
  final int _first;
  final List<int>? _values;

  int at(int i) => _values == null ? _first + i : _values[i];
}

/// A product of [axes], each tuple built into a question by [build].
/// [symmetric]: the question reads the same with its two operands swapped
/// and both operands come from the same values (`4 + 5`, `13 × 17`) — a
/// listed space stores it once and shows it either way round, a coin
/// deciding; a large space draws both orders, which already shows both.
final class Form {
  Form(this.axes, this.build, {this.symmetric = false}) {
    if (axes.isEmpty) throw ArgumentError.value(axes, 'axes', 'is empty.');
  }

  /// A form with no axis to draw: these questions, each once.
  Form.listed(List<Exercise> questions, {bool symmetric = false})
    : this(
        [Axis.range(0, questions.length - 1)],
        (c) => questions[c[0]],
        symmetric: symmetric,
      );

  final List<Axis> axes;
  final Exercise Function(List<int> values) build;
  final bool symmetric;

  /// How many tuples: a double, exact below 2⁵³ — the long sums' forms
  /// reach 10¹⁷.
  double get tuples => axes.fold(1.0, (n, a) => n * a.count);
}

/// Spaces of at most this many tuples are listed.
const listLimit = 30000;

/// [e] as a key: what counts as the same question (`doc/levels.md` v1.6:
/// "commutative forms count as the same question") — the operands of a sum
/// or a product in increasing order.
Exercise canonicalOf(Exercise e) {
  if (e is! ArithmeticExercise) return e;
  final op = e.operationType;
  if (op != OperationType.addition && op != OperationType.multiplication) {
    return e;
  }
  final c = e.operandC;
  if (c != null) {
    final sorted = [e.operandA, e.operandB, c]..sort();
    if (sorted[0] == e.operandA && sorted[1] == e.operandB) return e;
    return ArithmeticExercise(
      operandA: sorted[0],
      operandB: sorted[1],
      operandC: sorted[2],
      operationType: op,
    );
  }
  if (e.operandA <= e.operandB) return e;
  return ArithmeticExercise(
    operandA: e.operandB,
    operandB: e.operandA,
    operationType: op,
  );
}

/// [e] with its two operands swapped.
ArithmeticExercise _swapped(ArithmeticExercise e) => ArithmeticExercise(
  operandA: e.operandB,
  operandB: e.operandA,
  operationType: e.operationType,
);

/// A finite set of distinct questions, drawn uniformly ([QuestionSpace.of]).
sealed class QuestionSpace {
  /// Listed when [forms] hold at most [listLimit] tuples, else drawn axis
  /// by axis. Throws when there is no form (rule 13).
  factory QuestionSpace.of(List<Form> forms) {
    if (forms.isEmpty) throw ArgumentError.value(forms, 'forms', 'is empty.');
    final tuples = forms.fold(0.0, (n, f) => n + f.tuples);
    return tuples <= listLimit ? _ListedSpace(forms) : _DrawnSpace(forms);
  }

  /// How many distinct questions — exact for a listed space; for a drawn
  /// one, more than [listLimit] / 2 (its tuples, both orders of a symmetric
  /// form counted once).
  int get distinct;

  /// [distinct], for a drawn space estimated from its tuples (both orders
  /// of a symmetric form counted once): reports and analysis only.
  double get approximateDistinct;

  /// Whether [key] (a [canonicalOf] question) is one of this space's.
  /// A drawn space answers for its listed questions only: `false` (no fact
  /// of the weak-spot catalogue is that large).
  bool containsKey(Exercise key);

  /// How many of its questions are not in [avoid] (keys).
  int remaining(Set<Exercise> avoid);

  /// A question not in [avoid] (keys), uniformly; throws when [remaining]
  /// is 0 (the caller widens [avoid] first, [OperationDraws]).
  Exercise draw(Random random, Set<Exercise> avoid);

  /// The question [key] is, shown as this space shows it (either way round
  /// for a symmetric one, a coin deciding): a weak spot re-asked. Throws for
  /// a key not here (rule 13).
  Exercise ask(Exercise key, Random random);

  /// Every question, for tests and analysis: a listed space only.
  List<Exercise> get questions;
}

final class _ListedSpace implements QuestionSpace {
  _ListedSpace(List<Form> forms) {
    for (final form in forms) {
      final counts = [for (final a in form.axes) a.count];
      final c = List.filled(counts.length, 0);
      while (true) {
        final shown = form.build([
          for (var k = 0; k < c.length; k++) form.axes[k].at(c[k]),
        ]);
        final key = canonicalOf(shown);
        if (!_index.containsKey(key)) {
          _index[key] = _keys.length;
          _keys.add(key);
          // A symmetric form's question is kept as its key and shown either
          // way round; any other as it was built.
          _shown.add(form.symmetric ? key : shown);
          _flips.add(form.symmetric && key is ArithmeticExercise);
        }
        var k = c.length - 1;
        while (k >= 0 && ++c[k] == counts[k]) {
          c[k] = 0;
          k--;
        }
        if (k < 0) break;
      }
    }
  }

  final List<Exercise> _keys = [];
  final List<Exercise> _shown = [];
  final List<bool> _flips = [];
  final Map<Exercise, int> _index = {};

  @override
  int get distinct => _keys.length;

  @override
  double get approximateDistinct => _keys.length.toDouble();

  @override
  bool containsKey(Exercise key) => _index.containsKey(key);

  List<int> _avoided(Set<Exercise> avoid) =>
      [for (final key in avoid) ?_index[key]]..sort();

  @override
  int remaining(Set<Exercise> avoid) => _keys.length - _avoided(avoid).length;

  @override
  Exercise draw(Random random, Set<Exercise> avoid) {
    final skipped = _avoided(avoid);
    final free = _keys.length - skipped.length;
    if (free <= 0) throw StateError('No question left to draw.');
    // The i-th question not avoided: i among the free ones, then past every
    // avoided index at or below it.
    var i = random.nextInt(free);
    for (final s in skipped) {
      if (s <= i) i++;
    }
    return _show(i, random);
  }

  Exercise _show(int i, Random random) {
    final shown = _shown[i];
    if (_flips[i] && random.nextInt(2) == 0) {
      final a = shown as ArithmeticExercise;
      if (a.operandA != a.operandB) return _swapped(a);
    }
    return shown;
  }

  @override
  Exercise ask(Exercise key, Random random) => _show(
    _index[key] ??
        (throw ArgumentError.value(key, 'key', 'is not in this space.')),
    random,
  );

  @override
  List<Exercise> get questions => List.unmodifiable(_shown);
}

final class _DrawnSpace implements QuestionSpace {
  _DrawnSpace(this._forms);

  final List<Form> _forms;

  @override
  int get distinct => listLimit ~/ 2 + 1;

  @override
  double get approximateDistinct =>
      _forms.fold(0.0, (n, f) => n + (f.symmetric ? f.tuples / 2 : f.tuples));

  @override
  bool containsKey(Exercise key) => false;

  @override
  int remaining(Set<Exercise> avoid) => listLimit;

  @override
  Exercise draw(Random random, Set<Exercise> avoid) {
    final form = _forms[random.nextInt(_forms.length)];
    final c = [for (final a in form.axes) random.nextInt(a.count)];
    Exercise build() =>
        form.build([for (var k = 0; k < c.length; k++) form.axes[k].at(c[k])]);
    var question = build();
    // Already asked in this game (about one game in a million): the next
    // tuple in order, the last axis first.
    while (avoid.contains(canonicalOf(question))) {
      var k = c.length - 1;
      while (k >= 0 && ++c[k] == form.axes[k].count) {
        c[k] = 0;
        k--;
      }
      question = build();
    }
    return question;
  }

  @override
  Exercise ask(Exercise key, Random random) =>
      throw ArgumentError.value(key, 'key', 'is not listed in a drawn space.');

  @override
  List<Exercise> get questions =>
      throw StateError('A drawn space is not listed.');
}

/// One operation's draws in one game (rules v9): what it asked, from which
/// space, and the last question. [draw] keeps the drawing rules:
///
/// - never a question asked earlier in the game from another source (a
///   standard question that a pattern family or a weak spot already asked,
///   or the reverse) while the space has others;
/// - no repeat from the same space until it has none left; then a new
///   round of it — repeats allowed, **never two in a row**.
final class OperationDraws {
  final List<(Exercise key, Object source)> _asked = [];
  final Map<Object, Set<Exercise>> _round = {};
  final Set<Exercise> _reserved = {};
  Exercise? _last;

  /// Keeps [keys] out of every draw while the spaces allow: the weak spots
  /// this game will ask (their questions are asked as such, not drawn).
  void reserve(Iterable<Exercise> keys) => _reserved.addAll(keys);

  /// How many questions of [space] this game has not asked yet, from any
  /// source (the weak spots it will ask included).
  int fresh(QuestionSpace space) =>
      space.remaining({for (final (key, _) in _asked) key, ..._reserved});

  /// A question of [space], by the rules above.
  Exercise draw(QuestionSpace space, Random random) {
    final others = {
      for (final (key, source) in _asked)
        if (!identical(source, space)) key,
      ..._reserved,
    };
    final round = _round.putIfAbsent(space, () => {});
    final last = _last;
    var avoid = {...others, ...round, ?last};
    if (space.remaining(avoid) == 0) {
      round.clear();
      avoid = {...others, ?last};
    }
    if (space.remaining(avoid) == 0) avoid = {?last};
    if (space.remaining(avoid) == 0) avoid = {};
    final question = space.draw(random, avoid);
    final key = canonicalOf(question);
    _asked.add((key, space));
    round.add(key);
    _last = key;
    return question;
  }

  /// Records [question], asked as a weak spot from [source].
  void note(Exercise question, Object source) {
    final key = canonicalOf(question);
    _asked.add((key, source));
    _last = key;
  }
}
