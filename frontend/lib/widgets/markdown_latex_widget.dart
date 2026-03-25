import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownLatexWidget extends StatelessWidget {
  final String data;
  final bool isUser;

  const MarkdownLatexWidget({
    super.key,
    required this.data,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _buildWithLatex(context, isDark);
  }

  Widget _buildWithLatex(BuildContext context, bool isDark) {
    final segments = _parseLatexSegments(data);

    if (segments.length == 1 && !segments.first.isLatex) {
      return _buildMarkdownText(segments.first.content, context, isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        if (segment.isLatex) {
          return _buildLatexWidget(segment.content, isDark);
        } else {
          return _buildMarkdownText(segment.content, context, isDark);
        }
      }).toList(),
    );
  }

  List<({String content, bool isLatex})> _parseLatexSegments(String text) {
    final segments = <({String content, bool isLatex})>[];
    final pattern = RegExp(
      r'(\$\$[\s\S]*?\$\$|\$[^$\n]+\$|\\\[[\s\S]*?\\\]|\\\([\s\S]*?\\\))',
    );

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        final plainText = text.substring(lastEnd, match.start);
        if (plainText.trim().isNotEmpty) {
          segments.add((content: plainText, isLatex: false));
        }
      }

      String latex = match.group(0)!;
      latex = _cleanLatex(latex);
      segments.add((content: latex, isLatex: true));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final plainText = text.substring(lastEnd);
      if (plainText.trim().isNotEmpty) {
        segments.add((content: plainText, isLatex: false));
      }
    }

    if (segments.isEmpty) {
      segments.add((content: text, isLatex: false));
    }

    return segments;
  }

  String _cleanLatex(String latex) {
    if (latex.startsWith(r'$$') && latex.endsWith(r'$$')) {
      return latex.substring(2, latex.length - 2).trim();
    }
    if (latex.startsWith(r'$') && latex.endsWith(r'$')) {
      return latex.substring(1, latex.length - 1).trim();
    }
    if (latex.startsWith(r'\[') && latex.endsWith(r'\]')) {
      return latex.substring(2, latex.length - 2).trim();
    }
    if (latex.startsWith(r'\(') && latex.endsWith(r'\)')) {
      return latex.substring(2, latex.length - 2).trim();
    }
    return latex;
  }

  Widget _buildLatexWidget(String latex, bool isDark) {
    final displayText = _latexToDisplay(latex);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE1E4E8),
        ),
      ),
      child: SelectableText(
        displayText,
        style: TextStyle(
          fontSize: 20,
          fontFamily: 'serif',
          color: isDark ? Colors.white : const Color(0xFF343541),
          height: 1.8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _latexToDisplay(String latex) {
    String result = latex;

    // 希腊字母
    final greekLetters = {
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\delta': 'δ',
      r'\epsilon': 'ε',
      r'\zeta': 'ζ',
      r'\eta': 'η',
      r'\theta': 'θ',
      r'\iota': 'ι',
      r'\kappa': 'κ',
      r'\lambda': 'λ',
      r'\mu': 'μ',
      r'\nu': 'ν',
      r'\xi': 'ξ',
      r'\pi': 'π',
      r'\rho': 'ρ',
      r'\sigma': 'σ',
      r'\tau': 'τ',
      r'\upsilon': 'υ',
      r'\phi': 'φ',
      r'\chi': 'χ',
      r'\psi': 'ψ',
      r'\omega': 'ω',
      r'\Gamma': 'Γ',
      r'\Delta': 'Δ',
      r'\Theta': 'Θ',
      r'\Lambda': 'Λ',
      r'\Xi': 'Ξ',
      r'\Pi': 'Π',
      r'\Sigma': 'Σ',
      r'\Phi': 'Φ',
      r'\Psi': 'Ψ',
      r'\Omega': 'Ω',
    };

    // 数学符号
    final mathSymbols = {
      r'\infty': '∞',
      r'\partial': '∂',
      r'\nabla': '∇',
      r'\pm': '±',
      r'\mp': '∓',
      r'\times': '×',
      r'\div': '÷',
      r'\cdot': '·',
      r'\circ': '∘',
      r'\bullet': '•',
      r'\leq': '≤',
      r'\geq': '≥',
      r'\neq': '≠',
      r'\approx': '≈',
      r'\equiv': '≡',
      r'\propto': '∝',
      r'\sim': '∼',
      r'\simeq': '≃',
      r'\cong': '≅',
      r'\subset': '⊂',
      r'\supset': '⊃',
      r'\subseteq': '⊆',
      r'\supseteq': '⊇',
      r'\in': '∈',
      r'\notin': '∉',
      r'\cup': '∪',
      r'\cap': '∩',
      r'\emptyset': '∅',
      r'\forall': '∀',
      r'\exists': '∃',
      r'\neg': '¬',
      r'\land': '∧',
      r'\lor': '∨',
      r'\rightarrow': '→',
      r'\leftarrow': '←',
      r'\Rightarrow': '⇒',
      r'\Leftarrow': '⇐',
      r'\leftrightarrow': '↔',
      r'\Leftrightarrow': '⇔',
      r'\uparrow': '↑',
      r'\downarrow': '↓',
      r'\langle': '⟨',
      r'\rangle': '⟩',
      r'\lfloor': '⌊',
      r'\rfloor': '⌋',
      r'\lceil': '⌈',
      r'\rceil': '⌉',
      r'\sum': '∑',
      r'\prod': '∏',
      r'\int': '∫',
      r'\oint': '∮',
      r'\ldots': '…',
      r'\cdots': '⋯',
      r'\vdots': '⋮',
      r'\ddots': '⋱',
    };

    // 上标数字映射
    final superscripts = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      'n': 'ⁿ',
      'i': 'ⁱ',
      '+': '⁺',
      '-': '⁻',
      '=': '⁼',
      '(': '⁽',
      ')': '⁾',
    };

    // 下标数字映射
    final subscripts = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
      '+': '₊',
      '-': '₋',
      '=': '₌',
      '(': '₍',
      ')': '₎',
      'a': 'ₐ',
      'e': 'ₑ',
      'o': 'ₒ',
      'x': 'ₓ',
      'h': 'ₕ',
      'k': 'ₖ',
      'l': 'ₗ',
      'm': 'ₘ',
      'n': 'ₙ',
      'p': 'ₚ',
      's': 'ₛ',
      't': 'ₜ',
    };

    // 替换希腊字母和数学符号
    for (final entry in {...greekLetters, ...mathSymbols}.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    // 处理上标 ^{}
    result = result.replaceAllMapped(
      RegExp(r'\^{([^}]+)}'),
      (match) {
        final content = match.group(1)!;
        return content.split('').map((c) => superscripts[c] ?? c).join();
      },
    );
    // 处理上标 ^x (单字符)
    result = result.replaceAllMapped(
      RegExp(r'\^(\w)'),
      (match) {
        final c = match.group(1)!;
        return superscripts[c] ?? '^$c';
      },
    );

    // 处理下标 _{}
    result = result.replaceAllMapped(
      RegExp(r'_{([^}]+)}'),
      (match) {
        final content = match.group(1)!;
        return content.split('').map((c) => subscripts[c] ?? c).join();
      },
    );
    // 处理下标 _x (单字符)
    result = result.replaceAllMapped(
      RegExp(r'_(\w)'),
      (match) {
        final c = match.group(1)!;
        return subscripts[c] ?? '_$c';
      },
    );

    // 处理分数 \frac{a}{b} → a/b
    result = result.replaceAllMapped(
      RegExp(r'\\frac{([^}]+)}{([^}]+)}'),
      (match) => '${match.group(1)}/${match.group(2)}',
    );

    // 处理平方根 \sqrt{x} → √(x)
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt{([^}]+)}'),
      (match) => '√(${match.group(1)})',
    );
    result = result.replaceAll(r'\sqrt', '√');

    // 处理向量 \vec{x} → x⃗
    result = result.replaceAllMapped(
      RegExp(r'\\vec{([^}]+)}'),
      (match) => '${match.group(1)}⃗',
    );

    // 处理帽子 \hat{x} → x̂
    result = result.replaceAllMapped(
      RegExp(r'\\hat{([^}]+)}'),
      (match) => '${match.group(1)}̂',
    );

    // 处理横线 \bar{x} → x̄
    result = result.replaceAllMapped(
      RegExp(r'\\bar{([^}]+)}'),
      (match) => '${match.group(1)}̄',
    );

    // 处理点 \dot{x} → ẋ
    result = result.replaceAllMapped(
      RegExp(r'\\dot{([^}]+)}'),
      (match) => '${match.group(1)}̇',
    );

    // 处理双点 \ddot{x} → ẍ
    result = result.replaceAllMapped(
      RegExp(r'\\ddot{([^}]+)}'),
      (match) => '${match.group(1)}̈',
    );

    // 清理多余的反斜杠
    result = result.replaceAll(r'\\', '');
    result = result.replaceAll(r'\left', '');
    result = result.replaceAll(r'\right', '');
    result = result.replaceAll(r'\text{', '');
    result = result.replaceAll(r'}', '');
    result = result.replaceAll('{', '(');
    result = result.replaceAll('}', ')');

    return result;
  }

  Widget _buildMarkdownText(String text, BuildContext context, bool isDark) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: isUser
              ? Colors.white
              : (isDark ? const Color(0xFFECECEC) : const Color(0xFF343541)),
        ),
        h1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF343541),
        ),
        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF343541),
        ),
        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF343541),
        ),
        code: TextStyle(
          backgroundColor:
              isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF6F8FA),
          color: isDark ? const Color(0xFFE06C75) : const Color(0xFFE83E8C),
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE1E4E8),
          ),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          color: isDark ? const Color(0xFF9A9A9A) : const Color(0xFF6A737D),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isDark ? const Color(0xFF555555) : const Color(0xFFDFE2E5),
              width: 4,
            ),
          ),
        ),
        listBullet: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF343541),
        ),
        a: const TextStyle(
          color: Color(0xFF10A37F),
          decoration: TextDecoration.underline,
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF343541),
        ),
        tableBody: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF343541),
        ),
        tableBorder: TableBorder.all(
          color: isDark ? const Color(0xFF555555) : const Color(0xFFDFE2E5),
        ),
      ),
      builders: {'code': CodeElementBuilder(isDark: isDark)},
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final bool isDark;

  CodeElementBuilder({required this.isDark});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceFirst('language-', '');
    final code = element.textContent;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE1E4E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language != null && language.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Text(
                language,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF9A9A9A)
                      : const Color(0xFF6A737D),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color:
                    isDark ? const Color(0xFFD4D4D4) : const Color(0xFF343541),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
