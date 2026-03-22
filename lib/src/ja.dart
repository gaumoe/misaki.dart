import 'package:mecab/mecab.dart';

import 'ja_tables.dart';

/// Japanese grapheme-to-phoneme converter for Kokoro TTS.
///
/// Uses MeCab for morphological analysis and converts readings
/// to Kokoro-compatible phonemes.
///
/// ```dart
/// final g2p = JapaneseG2P.init('/path/to/ipadic');
/// final phonemes = g2p.convert('こんにちは世界');
/// print(phonemes); // koɴɲiʨiβa sekai
/// g2p.dispose();
/// ```
class JapaneseG2P {
  final Mecab _mecab;
  final Map<String, String> _table = hiraganaToPhoneme; // ignore: prefer_const_declarations

  JapaneseG2P._(this._mecab);

  /// Initialize with MeCab IpaDic dictionary path.
  factory JapaneseG2P.init(String dictPath) {
    final mecab = Mecab.init(dictPath);
    return JapaneseG2P._(mecab);
  }

  /// Convert Japanese text to Kokoro phonemes.
  String convert(String text) {
    if (text.trim().isEmpty) return '';

    final tokens = _mecab.parse(text);
    final buf = StringBuffer();

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final surface = token.surface;

      // Check if it's punctuation.
      final punct = _mapPunctuation(surface);
      if (punct != null) {
        if (buf.isNotEmpty &&
            punct.isNotEmpty &&
            _isPunctStop(punct) &&
            !_endsWithSpace(buf)) {
          // No space before punctuation.
        } else if (punct.isNotEmpty &&
            _isPunctStart(punct) &&
            buf.isNotEmpty &&
            !_endsWithSpace(buf)) {
          buf.write(' ');
        }
        buf.write(punct);
        if (punct.isNotEmpty && _isPunctStop(punct)) buf.write(' ');
        continue;
      }

      // ASCII passthrough.
      if (_isAscii(surface)) {
        if (buf.isNotEmpty && !_endsWithSpace(buf)) buf.write(' ');
        buf.write(surface);
        continue;
      }

      // Get reading from MeCab.
      final reading = token.pronunciation.isNotEmpty
          ? token.pronunciation
          : token.reading;

      if (reading.isEmpty) continue;

      // Convert katakana reading to hiragana.
      final hira = _katakanaToHiragana(reading);

      // Convert hiragana to phonemes.
      final phonemes = _hiraganaToPhonemes(hira);
      if (phonemes.isEmpty) continue;

      // Add word boundary space.
      if (buf.isNotEmpty && !_endsWithSpace(buf) && !_endsWithPunct(buf)) {
        buf.write(' ');
      }
      buf.write(phonemes);
    }

    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Convert a hiragana string to phonemes.
  String _hiraganaToPhonemes(String hira) {
    final buf = StringBuffer();
    for (var i = 0; i < hira.length; i++) {
      final char = hira[i];
      final next = i + 1 < hira.length ? hira[i + 1] : null;
      final prev = i > 0 ? hira[i - 1] : null;

      // Check digraph first.
      if (next != null) {
        final digraph = _table['$char$next'];
        if (digraph != null) {
          buf.write(digraph);
          i++; // skip next
          continue;
        }
      }

      // Skip sutegana handled as part of previous digraph.
      if (prev != null && _table['$prev$char'] != null) continue;

      // Sutegana after consonant (e.g. きゃ when not in digraph table).
      if (sutegana.contains(char) && prev != null) {
        final prevPhoneme = _table[prev];
        if (prevPhoneme != null && prevPhoneme.length >= 2) {
          buf.write(_table[char] ?? '');
          continue;
        }
        continue;
      }

      // っ (gemination / glottal stop).
      if (char == 'っ') {
        buf.write('ʔ');
        continue;
      }

      // ん (nasal assimilation).
      if (char == 'ん') {
        buf.write(_nasalN(next));
        continue;
      }

      // ー (long vowel).
      if (char == 'ー') {
        buf.write('ː');
        continue;
      }

      // Regular kana.
      final phoneme = _table[char];
      if (phoneme != null) {
        buf.write(phoneme);
      }
    }
    return buf.toString();
  }

  /// ん assimilation based on following sound.
  String _nasalN(String? nextChar) {
    if (nextChar == null) return 'ɴ';
    final nextPhoneme = _table[nextChar];
    if (nextPhoneme == null) return 'ɴ';
    final first = nextPhoneme[0];
    if ('mpb'.contains(first)) return 'm';
    if ('kɡ'.contains(first)) return 'ŋ';
    if (nextPhoneme.startsWith('ɲ') ||
        nextPhoneme.startsWith('ʨ') ||
        nextPhoneme.startsWith('ʥ'))
      return 'ɲ';
    if ('ntdɾz'.contains(first)) return 'n';
    return 'ɴ';
  }

  /// Release resources.
  void dispose() => _mecab.dispose();

  static String? _mapPunctuation(String surface) {
    if (surface.length == 1 && punctuationMap.containsKey(surface)) {
      return punctuationMap[surface];
    }
    return null;
  }

  static bool _isPunctStop(String p) =>
      p.isNotEmpty && '!),.:;?\u201d'.contains(p[p.length - 1]);

  static bool _isPunctStart(String p) =>
      p.isNotEmpty && '(\u201c'.contains(p[0]);

  static bool _isAscii(String s) => s.codeUnits.every((c) => c < 128);

  static bool _endsWithSpace(StringBuffer buf) {
    final s = buf.toString();
    return s.isNotEmpty && s[s.length - 1] == ' ';
  }

  static bool _endsWithPunct(StringBuffer buf) {
    final s = buf.toString();
    return s.isNotEmpty && _isPunctStop(s[s.length - 1]);
  }

  static String _katakanaToHiragana(String katakana) {
    final buf = StringBuffer();
    for (final rune in katakana.runes) {
      // Katakana range: 0x30A1-0x30F6 → Hiragana: 0x3041-0x3096
      if (rune >= 0x30A1 && rune <= 0x30F6) {
        buf.writeCharCode(rune - 0x60);
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }
}
