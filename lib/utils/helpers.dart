import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/additive_info.dart';

double parseNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String safeStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v.trim().isEmpty ? fallback : v.trim();
  return v.toString().trim();
}

/// Composite Food Quality Score 0–100
int computeQualityScore(Map<String, dynamic> p) {
  final nutriments = p['nutriments'] as Map<String, dynamic>? ?? {};

  // ── Nutri-Score component (20 pts) ──────────────────────────────────────
  final ns = safeStr(p['nutrition_grades']).toUpperCase();
  final nsScore = {'A': 20, 'B': 16, 'C': 12, 'D': 8, 'E': 4}[ns] ?? 10;

  // ── NOVA processing component (15 pts) ──────────────────────────────────
  final nova = parseNum(p['nova_group']).round();
  final novaScore = {1: 15, 2: 11, 3: 7, 4: 3}[nova] ?? 8;

  // ── Additive component (10 pts) ──────────────────────────────────────────
  final additives = (p['additives_tags'] as List<dynamic>? ?? []);
  int addPenalty = 0;
  for (final a in additives) {
    final key = safeStr(a).replaceFirst('en:', '').toLowerCase();
    final info = kAdditives[key];
    if (info != null) {
      if (info.risk == AdditiveRisk.concern) addPenalty += 3;
      if (info.risk == AdditiveRisk.moderate) addPenalty += 1;
    } else {
      addPenalty += 1; // unknown additive, slight penalty
    }
  }
  final addScore = max(0, 10 - addPenalty);

  // ── Health score from nutriments (50 pts) ────────────────────────────────
  double health = 25.0; // baseline

  final sugar   = parseNum(nutriments['sugars_100g']);
  final satFat  = parseNum(nutriments['saturated-fat_100g']);
  final sodium  = parseNum(nutriments['sodium_100g']) * 1000; // mg
  final fiber   = parseNum(nutriments['fiber_100g']);
  final protein = parseNum(nutriments['proteins_100g']);

  // Sugar penalties
  if (sugar > 22) health -= 8;
  else if (sugar > 12) health -= 4;
  else if (sugar < 5) health += 3;

  // Saturated fat penalties
  if (satFat > 10) health -= 7;
  else if (satFat > 5) health -= 3;
  else if (satFat < 2) health += 2;

  // Sodium penalties
  if (sodium > 800) health -= 6;
  else if (sodium > 400) health -= 3;

  // Fibre bonus
  if (fiber > 6) health += 8;
  else if (fiber > 3) health += 4;

  // Protein bonus
  if (protein > 15) health += 5;
  else if (protein > 8) health += 2;

  final healthScore = max(0, min(50, health.round()));

  // ── Sustainability (5 pts) — use ecoscore if available ───────────────────
  final eco   = safeStr(p['ecoscore_grade']).toUpperCase();
  final ecoSc = {'A': 5, 'B': 4, 'C': 3, 'D': 2, 'E': 1}[eco] ?? 3;

  return (nsScore + novaScore + addScore + healthScore + ecoSc).clamp(0, 100);
}

/// Parse nutriments' negative factors for "Why Rated Poorly"
List<String> whyRatedPoorly(Map<String, dynamic> p) {
  final nutriments = p['nutriments'] as Map<String, dynamic>? ?? {};
  final reasons = <String>[];
  final sugar  = parseNum(nutriments['sugars_100g']);
  final satFat = parseNum(nutriments['saturated-fat_100g']);
  final salt   = parseNum(nutriments['salt_100g']);
  final fiber  = parseNum(nutriments['fiber_100g']);
  final prot   = parseNum(nutriments['proteins_100g']);
  final nova   = parseNum(p['nova_group']).round();

  if (sugar > 22)  reasons.add('Very high sugar (${sugar.toStringAsFixed(1)} g/100g)');
  else if (sugar > 12) reasons.add('High sugar (${sugar.toStringAsFixed(1)} g/100g)');

  if (satFat > 10) reasons.add('Very high saturated fat (${satFat.toStringAsFixed(1)} g/100g)');
  else if (satFat > 5) reasons.add('Elevated saturated fat (${satFat.toStringAsFixed(1)} g/100g)');

  if (salt > 1.5) reasons.add('High salt (${salt.toStringAsFixed(2)} g/100g)');

  if (fiber < 1.5) reasons.add('Low dietary fibre (${fiber.toStringAsFixed(1)} g/100g)');
  if (prot < 3)   reasons.add('Low protein (${prot.toStringAsFixed(1)} g/100g)');
  if (nova == 4)  reasons.add('Ultra-processed (NOVA group 4)');

  return reasons;
}

List<String> whatsDoneWell(Map<String, dynamic> p) {
  final nutriments = p['nutriments'] as Map<String, dynamic>? ?? {};
  final goods = <String>[];
  final sugar  = parseNum(nutriments['sugars_100g']);
  final satFat = parseNum(nutriments['saturated-fat_100g']);
  final fiber  = parseNum(nutriments['fiber_100g']);
  final prot   = parseNum(nutriments['proteins_100g']);
  final nova   = parseNum(p['nova_group']).round();

  if (sugar < 5)   goods.add('Low sugar (${sugar.toStringAsFixed(1)} g/100g)');
  if (satFat < 2)  goods.add('Low saturated fat');
  if (fiber > 6)   goods.add('High in fibre (${fiber.toStringAsFixed(1)} g/100g)');
  if (prot > 15)   goods.add('High in protein (${prot.toStringAsFixed(1)} g/100g)');
  if (nova <= 2)   goods.add('Minimally processed (NOVA ${nova == 0 ? "?" : nova})');
  return goods;
}

Color nutriColor(String grade) {
  switch (grade.toUpperCase()) {
    case 'A': return const Color(0xFF00897B);
    case 'B': return colorSuccess;
    case 'C': return colorWarning;
    case 'D': return const Color(0xFFC0603A);
    case 'E': return colorDanger;
    default:  return backgroundTertiary;
  }
}

Color qualityColor(int score) {
  if (score >= 75) return colorSuccess;
  if (score >= 55) return colorWarning;
  return colorDanger;
}
