@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:math_core/difficulty/structural_features.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:test/test.dart';

/// The dashboard computes structural features in SQL
/// (`owner_dashboard.structural_features`); the app's core computes them
/// in Dart. This runs every case of the SQL test against the Dart code:
/// one list of cases, both implementations — change one, change both.
/// Reads the file: VM only (the Dart rules run on JavaScript too, in
/// `structural_features_test.dart`).
void main() {
  final sql = File(
    '../../supabase/tests/96_structural_features_test.sql',
  ).readAsStringSync();
  final cases = RegExp(
    r"\('(\w+)', '(\{[^']*\})', (\d+), (\d+), (\d+), (\d+|null)\)",
  ).allMatches(sql).toList();

  test('the SQL test holds the cases', () {
    expect(cases.length, greaterThanOrEqualTo(15));
  });

  for (final c in cases) {
    test('${c[1]} ${c[2]}', () {
      final operands = (jsonDecode(c[2]!) as Map).cast<String, int>();
      final exercise = switch (c[1]) {
        'power' => PowerExercise(
          base: operands['base']!,
          exponent: operands['exponent']!,
        ),
        'squareRoot' => SquareRootExercise(radicand: operands['radicand']!),
        'percentage' => PercentageExercise(
          percent: operands['percent']!,
          base: operands['base']!,
        ),
        final operation => ArithmeticExercise(
          operandA: operands['operandA']!,
          operandB: operands['operandB']!,
          operationType: OperationType.values.byName(operation!),
        ),
      };
      expect(
        structuralFeatures(exercise),
        StructuralFeatures(
          carries: int.parse(c[3]!),
          borrows: int.parse(c[4]!),
          bigDigits: int.parse(c[5]!),
          roundDistance: c[6] == 'null' ? null : int.parse(c[6]!),
        ),
      );
    });
  }
}
