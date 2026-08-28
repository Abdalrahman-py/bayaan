import 'package:bayaan/services/reciter_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pads sura and aya to three digits each', () {
    expect(
      Reciter.alafasy.urlFor(1, 1).toString(),
      'https://everyayah.com/data/Alafasy_128kbps/001001.mp3',
    );
    expect(
      Reciter.husary.urlFor(2, 255).toString(),
      'https://everyayah.com/data/Husary_Muallim_128kbps/002255.mp3',
    );
    // Last ayah of the mushaf — the widest sura and aya numbers there are.
    expect(
      Reciter.abdulBasit.urlFor(114, 6).toString(),
      'https://everyayah.com/data/Abdul_Basit_Mujawwad_128kbps/114006.mp3',
    );
  });

  test('an unknown or missing id falls back to the teacher recording', () {
    expect(Reciter.byId(null), Reciter.husary);
    expect(Reciter.byId('nobody'), Reciter.husary);
    expect(Reciter.byId('alafasy'), Reciter.alafasy);
  });

  test('every reciter has a distinct id and folder', () {
    expect(Reciter.all.map((r) => r.id).toSet(), hasLength(Reciter.all.length));
    expect(
      Reciter.all.map((r) => r.folder).toSet(),
      hasLength(Reciter.all.length),
    );
  });
}
