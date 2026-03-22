# misaki

[![pub package](https://img.shields.io/pub/v/misaki.svg)](https://pub.dev/packages/misaki)

Grapheme-to-phoneme for Kokoro TTS models. Dart port of [hexgrad/misaki](https://github.com/hexgrad/misaki).

## Supported Languages

- Japanese (via [mecab](https://pub.dev/packages/mecab))

## Usage

```dart
import 'package:misaki/misaki.dart';

final g2p = JapaneseG2P.init('/path/to/ipadic');

final phonemes = g2p.convert('こんにちは世界');
print(phonemes); // koɲɲiʨiβa sekai

g2p.dispose();
```

## Requirements

- MeCab IpaDic dictionary (see [mecab](https://pub.dev/packages/mecab) package)

## License

Apache 2.0, same as [hexgrad/misaki](https://github.com/hexgrad/misaki).
