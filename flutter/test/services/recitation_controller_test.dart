import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/models/models.dart';
import 'package:bayaan/services/recitation_controller.dart';

const _verse = Verse(
  sura: 2,
  aya: 1,
  surahNameEn: 'Al-Baqarah',
  surahNameAr: 'البقرة',
  uthmani: 'الم',
);

void main() {
  group('buildWav', () {
    test('emits a byte-identical 44-byte RIFF/WAVE header', () {
      final pcm = Uint8List.fromList([1, 2, 3, 4]);
      final wav = RecitationController.buildWav(pcm);

      expect(wav.length, 44 + pcm.length);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(_le32(wav, 4), 36 + pcm.length); // RIFF chunk size
      expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
      expect(ascii.decode(wav.sublist(12, 16)), 'fmt ');
      expect(_le32(wav, 16), 16); // fmt chunk size
      expect(_le16(wav, 20), 1); // audio format = PCM
      expect(_le16(wav, 22), 1); // mono
      expect(_le32(wav, 24), 16000); // sample rate
      expect(_le32(wav, 28), 32000); // byte rate = 16000 * 2
      expect(_le16(wav, 32), 2); // block align
      expect(_le16(wav, 34), 16); // bits per sample
      expect(ascii.decode(wav.sublist(36, 40)), 'data');
      expect(_le32(wav, 40), pcm.length);
    });

    test('empty pcm yields a bare 44-byte header', () {
      final wav = RecitationController.buildWav(Uint8List(0));
      expect(wav.length, 44);
    });

    test('pcm bytes are appended verbatim after the header', () {
      final pcm = Uint8List.fromList([0x80, 0x00, 0x7f, 0xff]);
      final wav = RecitationController.buildWav(pcm);
      expect(wav.sublist(44), pcm);
    });
  });

  group('parseResponse', () {
    test('maps a success payload to ResultState with engine text', () {
      final s = RecitationController.parseResponse(
        jsonEncode({
          'errors': [
            {
              'uthmani_pos': [1, 3],
              'error_type': 'tajweed',
              'speech_error_type': 'replace',
              'ref_tajweed_rules': [
                {'name': {'en': 'Madd', 'ar': 'مد'}}
              ],
            }
          ],
          'sifat_errors': [],
          'all_correct': false,
          'uthmani': 'مُحَمَّد',
        }),
        200,
        _verse,
      );

      expect(s, isA<ResultState>());
      final r = s as ResultState;
      expect(r.allCorrect, isFalse);
      expect(r.verse.uthmani, 'مُحَمَّد'); // engine override applied
      expect(r.mistakes, hasLength(1));
      expect(r.mistakes.single.charRange.start, 1);
      expect(r.mistakes.single.charRange.end, 3);
      expect(r.mistakes.single.isTajweed, isTrue);
      expect(r.mistakes.single.ruleNameEn, 'Madd');
    });

    test('empty errors and all_correct true → allCorrect true', () {
      final s = RecitationController.parseResponse(
        jsonEncode({'errors': [], 'sifat_errors': [], 'all_correct': true}),
        200,
        _verse,
      );
      expect((s as ResultState).allCorrect, isTrue);
      expect((s).mistakes, isEmpty);
    });

    test('sifat errors force allCorrect false even if engine says true', () {
      final s = RecitationController.parseResponse(
        jsonEncode({
          'errors': [],
          'sifat_errors': [
            {
              'phonemes_group': 'g',
              'attribute': 'a',
              'predicted': 'p',
              'expected': 'e',
            }
          ],
          'all_correct': true,
        }),
        200,
        _verse,
      );
      expect((s as ResultState).allCorrect, isFalse);
    });

    test('pad and non-speech sifat tokens are filtered out and do not cause false errors', () {
      final s = RecitationController.parseResponse(
        jsonEncode({
          'errors': [],
          'sifat_errors': [
            {
              'phonemes_group': 'قل',
              'attribute': 'qalqla',
              'predicted': '[pad]',
              'expected': 'not_moqalqal',
            },
            {
              'phonemes_group': 'ش',
              'attribute': 'tafashie',
              'predicted': '<pad>',
              'expected': 'not_motafashie',
            }
          ],
          'all_correct': true,
        }),
        200,
        _verse,
      );
      expect(s, isA<ResultState>());
      final r = s as ResultState;
      expect(r.allCorrect, isTrue);
      expect(r.sifatErrors, isEmpty);
    });

    test('missing all_correct throws FormatException', () {
      expect(
        () => RecitationController.parseResponse(
          jsonEncode({'errors': [], 'sifat_errors': []}),
          200,
          _verse,
        ),
        throwsFormatException,
      );
    });

    test('malformed mistake (missing uthmani_pos) throws FormatException', () {
      expect(
        () => RecitationController.parseResponse(
          jsonEncode({
            'errors': [
              {'error_type': 'tajweed', 'speech_error_type': 'replace'}
            ],
            'sifat_errors': [],
            'all_correct': false,
          }),
          200,
          _verse,
        ),
        throwsFormatException,
      );
    });

    test('mistakes without the engine text throw rather than mismark', () {
      // Char offsets index the engine's own reference text. Painting them onto
      // the bundled asset text would put marks on letters the reciter got
      // right — a wrong answer is worse here than an honest retry prompt.
      expect(
        () => RecitationController.parseResponse(
          jsonEncode({
            'errors': [
              {
                'uthmani_pos': [1, 3],
                'error_type': 'tajweed',
                'speech_error_type': 'replace',
              }
            ],
            'sifat_errors': [],
            'all_correct': false,
          }),
          200,
          _verse,
        ),
        throwsFormatException,
      );
    });

    test('malformed sifat error throws FormatException', () {
      expect(
        () => RecitationController.parseResponse(
          jsonEncode({
            'errors': [],
            'sifat_errors': [
              {'phonemes_group': 'g'} // missing attribute/predicted/expected
            ],
            'all_correct': false,
          }),
          200,
          _verse,
        ),
        throwsFormatException,
      );
    });

    test('non-2xx surfaces the server message', () {
      final s = RecitationController.parseResponse(
        jsonEncode({'message': 'audio too short'}),
        422,
        _verse,
      );
      expect(s, isA<ErrorState>());
      expect((s as ErrorState).message, 'audio too short');
    });

    test('non-2xx with non-JSON body falls back to a fixed message', () {
      final s = RecitationController.parseResponse('<html>oops</html>', 500, _verse);
      expect((s as ErrorState).message, contains("couldn't process"));
    });

    test('non-map JSON payload throws FormatException', () {
      expect(
        () => RecitationController.parseResponse('[1,2,3]', 200, _verse),
        throwsFormatException,
      );
    });
  });
}

int _le16(Uint8List b, int off) => b[off] | (b[off + 1] << 8);
int _le32(Uint8List b, int off) =>
    b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24);
