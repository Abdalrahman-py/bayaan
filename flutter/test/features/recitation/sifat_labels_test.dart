import 'package:bayaan/features/recitation/sifat_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sifatAttributeLabel', () {
    test('names the ten attributes the engine actually emits', () {
      expect(sifatAttributeLabel('tafkheem_or_taqeeq'), 'Heavy or light');
      expect(sifatAttributeLabel('hams_or_jahr'), 'Breath');
      expect(sifatAttributeLabel('qalqla'), 'Qalqalah (bounce)');
    });

    test('an unknown key still reads as words, never as a raw token', () {
      expect(sifatAttributeLabel('some_new_attribute'), 'Some new attribute');
    });
  });

  group('sifatValueLabel', () {
    test('glosses the vocabulary seen in the S1 engine output', () {
      expect(sifatValueLabel('mofakham'), 'heavy (mofakham)');
      expect(sifatValueLabel('moraqaq'), 'light (moraqaq)');
      expect(sifatValueLabel('jahr'), 'voiced (jahr)');
    });

    test('negated values read as the absence of the thing', () {
      expect(sifatValueLabel('not_moqalqal'), 'not bounced (qalqalah)');
      expect(sifatValueLabel('no_safeer'), 'not whistled (safeer)');
    });

    test('an unknown value degrades to plain words', () {
      expect(sifatValueLabel('brand_new_value'), 'brand new value');
    });
  });

  test('sifatDetail leads with the target, not the mistake', () {
    expect(
      sifatDetail('moraqaq', 'mofakham'),
      'Should be light (moraqaq) — you said heavy (mofakham)',
    );
  });
}
