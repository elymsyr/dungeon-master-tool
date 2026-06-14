/// FormulaEvaluator — the tiny §4.3 expression evaluator (SHADOW).
///
/// Roadmap PR-T7 / PR-2.4 (slice 3). A small recursive-descent evaluator for
/// the formula grammar in docs/new_system/the-template-system.md §4.3, used by
/// the `formula` value source of a `modify_stat` rule (and, later, pouch
/// max/grant sources). It reads an [AspectContext] — the PC card's published
/// aspects — and computes a single number.
///
/// **Authority status — SHADOW ONLY.** Nothing in the live app evaluates a
/// formula yet; it is exercised only by `tool/template_rule_resolver_harness.dart`
/// through [TemplateRuleResolver]. The old hardcoded engine stays authoritative
/// until the Phase 3.11 flip.
///
/// **Grammar (§4.3):**
///   * identifiers = aspect names — `aspects.value(name)`, **0 when absent**
///     (so an unpublished aspect never throws, it just contributes 0);
///   * the computed `class_level(<slug>)` aspect is captured whole, so a
///     hyphenated slug isn't split into subtraction;
///   * integer/decimal literals;
///   * binary `+` `-` `*` `/` (real division; wrap in `floor()` for D&D maths)
///     with standard precedence, and unary `-`/`+`;
///   * functions `floor(x)` `ceil(x)` `min(a,b,…)` `max(a,b,…)`;
///   * `table(expr, "1:2,5:3,9:4,…")` — a step table: the value of the highest
///     `threshold` that is `<= expr` (0 when below every threshold);
///   * parentheses for grouping.
///
/// There are **no conditionals** in v1 (per §4.3) — anything needing a
/// predicate becomes a `note` rule instead. Any malformed expression throws a
/// [FormulaException]; the resolver catches it and records a precise deferral
/// reason rather than crashing or silently dropping the rule.
library;

import 'aspect_context.dart';

/// Thrown on a lex/parse/eval failure of a formula string. The resolver turns
/// it into a `deferred` reason — never a silent stat change.
class FormulaException implements Exception {
  final String message;
  const FormulaException(this.message);

  @override
  String toString() => 'FormulaException: $message';
}

/// Stateless evaluator for §4.3 formula strings.
class FormulaEvaluator {
  const FormulaEvaluator();

  /// Evaluate [expr] against [aspects], returning the computed number.
  ///
  /// Throws [FormulaException] on any lexical/syntactic/semantic error.
  num evaluate(String expr, AspectContext aspects) {
    final tokens = _tokenize(expr);
    final parser = _Parser(tokens, aspects);
    final result = parser.parseExpression();
    parser.expectEnd();
    return result;
  }

  // ── Lexer ────────────────────────────────────────────────────────────────

  static List<_Token> _tokenize(String src) {
    final tokens = <_Token>[];
    var i = 0;
    final n = src.length;

    while (i < n) {
      final c = src[i];

      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        i++;
        continue;
      }

      switch (c) {
        case '+':
          tokens.add(const _Token(_Tok.plus));
          i++;
          continue;
        case '-':
          tokens.add(const _Token(_Tok.minus));
          i++;
          continue;
        case '*':
          tokens.add(const _Token(_Tok.star));
          i++;
          continue;
        case '/':
          tokens.add(const _Token(_Tok.slash));
          i++;
          continue;
        case '(':
          tokens.add(const _Token(_Tok.lparen));
          i++;
          continue;
        case ')':
          tokens.add(const _Token(_Tok.rparen));
          i++;
          continue;
        case ',':
          tokens.add(const _Token(_Tok.comma));
          i++;
          continue;
      }

      // String literal (the `table` spec), single- or double-quoted.
      if (c == '"' || c == "'") {
        final quote = c;
        final sb = StringBuffer();
        i++;
        while (i < n && src[i] != quote) {
          sb.write(src[i]);
          i++;
        }
        if (i >= n) {
          throw const FormulaException('unterminated string literal');
        }
        i++; // consume the closing quote
        tokens.add(_Token(_Tok.string, text: sb.toString()));
        continue;
      }

      // Numeric literal (integer or decimal).
      if (_isDigit(c)) {
        final start = i;
        var seenDot = false;
        while (i < n && (_isDigit(src[i]) || (src[i] == '.' && !seenDot))) {
          if (src[i] == '.') seenDot = true;
          i++;
        }
        final text = src.substring(start, i);
        final value = num.tryParse(text);
        if (value == null) {
          throw FormulaException('invalid number "$text"');
        }
        tokens.add(_Token(_Tok.number, number: value));
        continue;
      }

      // Identifier / function name / computed `class_level(<slug>)` aspect.
      if (_isIdentStart(c)) {
        final start = i;
        while (i < n && _isIdentPart(src[i])) {
          i++;
        }
        var text = src.substring(start, i);

        // `class_level(<slug>)` is a single computed-aspect name (§4.3), not a
        // function call — capture it whole so a hyphenated slug (e.g.
        // `battle-master`) isn't lexed as `battle` `-` `master`.
        if (text == 'class_level') {
          var j = i;
          while (j < n && (src[j] == ' ' || src[j] == '\t')) {
            j++;
          }
          if (j < n && src[j] == '(') {
            final close = src.indexOf(')', j);
            if (close == -1) {
              throw const FormulaException('class_level missing closing ")"');
            }
            final slug = src.substring(j + 1, close).trim();
            if (slug.isEmpty) {
              throw const FormulaException('class_level missing slug');
            }
            tokens.add(_Token(_Tok.ident, text: 'class_level($slug)'));
            i = close + 1;
            continue;
          }
        }

        tokens.add(_Token(_Tok.ident, text: text));
        continue;
      }

      throw FormulaException('unexpected character "$c" at index $i');
    }

    tokens.add(const _Token(_Tok.eof));
    return tokens;
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || c == '_';
  }

  static bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);
}

enum _Tok {
  number,
  ident,
  string,
  plus,
  minus,
  star,
  slash,
  lparen,
  rparen,
  comma,
  eof,
}

class _Token {
  final _Tok type;
  final num? number;
  final String? text;
  const _Token(this.type, {this.number, this.text});
}

/// Recursive-descent parser/evaluator. One instance per [evaluate] call.
///
/// Grammar (lowest→highest precedence):
///   expression := term     (('+' | '-') term)*
///   term       := factor   (('*' | '/') factor)*
///   factor     := ('-' | '+') factor | primary
///   primary    := number | '(' expression ')' | ident [ call-args ]
class _Parser {
  final List<_Token> tokens;
  final AspectContext aspects;
  int _pos = 0;

  _Parser(this.tokens, this.aspects);

  _Token get _current => tokens[_pos];
  bool _check(_Tok t) => _current.type == t;
  _Token _advance() => tokens[_pos++];

  bool _match(_Tok t) {
    if (_check(t)) {
      _pos++;
      return true;
    }
    return false;
  }

  _Token _expect(_Tok t, String what) {
    if (!_check(t)) {
      throw FormulaException('expected $what');
    }
    return _advance();
  }

  void expectEnd() {
    if (!_check(_Tok.eof)) {
      throw const FormulaException('unexpected trailing tokens');
    }
  }

  num parseExpression() {
    var left = _parseTerm();
    while (_check(_Tok.plus) || _check(_Tok.minus)) {
      final op = _advance().type;
      final right = _parseTerm();
      left = op == _Tok.plus ? left + right : left - right;
    }
    return left;
  }

  num _parseTerm() {
    var left = _parseFactor();
    while (_check(_Tok.star) || _check(_Tok.slash)) {
      final op = _advance().type;
      final right = _parseFactor();
      if (op == _Tok.star) {
        left = left * right;
      } else {
        if (right == 0) {
          throw const FormulaException('division by zero');
        }
        left = left / right;
      }
    }
    return left;
  }

  num _parseFactor() {
    if (_match(_Tok.minus)) return -_parseFactor();
    if (_match(_Tok.plus)) return _parseFactor();
    return _parsePrimary();
  }

  num _parsePrimary() {
    if (_check(_Tok.number)) {
      return _advance().number!;
    }
    if (_match(_Tok.lparen)) {
      final v = parseExpression();
      _expect(_Tok.rparen, '")"');
      return v;
    }
    if (_check(_Tok.ident)) {
      final name = _advance().text!;
      // A function call iff an identifier is immediately followed by "(".
      if (_check(_Tok.lparen)) {
        return _parseCall(name);
      }
      // Otherwise an aspect lookup (incl. the computed `class_level(<slug>)`
      // name captured by the lexer); 0 when the aspect is unpublished (§4.3).
      return aspects.value(name);
    }
    throw const FormulaException('unexpected token in expression');
  }

  num _parseCall(String name) {
    _expect(_Tok.lparen, '"("');
    switch (name) {
      case 'floor':
      case 'ceil':
        final arg = parseExpression();
        _expect(_Tok.rparen, '")"');
        return name == 'floor' ? arg.floor() : arg.ceil();

      case 'min':
      case 'max':
        final args = <num>[parseExpression()];
        while (_match(_Tok.comma)) {
          args.add(parseExpression());
        }
        _expect(_Tok.rparen, '")"');
        var acc = args.first;
        for (final a in args.skip(1)) {
          if (name == 'min') {
            if (a < acc) acc = a;
          } else {
            if (a > acc) acc = a;
          }
        }
        return acc;

      case 'table':
        final input = parseExpression();
        _expect(_Tok.comma, '"," (table needs a spec string)');
        final spec = _expect(_Tok.string, 'table spec string').text!;
        _expect(_Tok.rparen, '")"');
        return _evalTable(input, spec);

      default:
        throw FormulaException('unknown function "$name"');
    }
  }

  /// `table(expr, "1:2,5:3,9:4")` — pick the value of the highest threshold that
  /// is `<= input` (0 when [input] is below every threshold). Malformed pairs in
  /// the spec are skipped, never thrown.
  num _evalTable(num input, String spec) {
    num? bestThreshold;
    num result = 0;
    for (final part in spec.split(',')) {
      final kv = part.split(':');
      if (kv.length != 2) continue;
      final threshold = num.tryParse(kv[0].trim());
      final value = num.tryParse(kv[1].trim());
      if (threshold == null || value == null) continue;
      if (input >= threshold &&
          (bestThreshold == null || threshold > bestThreshold)) {
        bestThreshold = threshold;
        result = value;
      }
    }
    return result;
  }
}
