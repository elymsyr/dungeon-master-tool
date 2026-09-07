import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/services/publish_media_pinner.dart';

/// `isMediaRef` yayının tek karar noktası: yanlış pozitif her metin alanını
/// R2'ye yüklemeye kalkar, yanlış negatif medyayı yayında kırık bırakır.
void main() {
  group('PublishMediaPinner.isMediaRef', () {
    test('pinlenir: local görsel path, public, transient, sayılan cloud', () {
      expect(PublishMediaPinner.isMediaRef('/home/a/media/x.png'), isTrue);
      expect(PublishMediaPinner.isMediaRef(r'C:\worlds\w\media\x.JPG'), isTrue);
      expect(PublishMediaPinner.isMediaRef('dmt-public://u/${'a' * 64}.png'),
          isTrue);
      expect(PublishMediaPinner.isMediaRef('dmt-transient://${'a' * 64}.png'),
          isTrue);
      expect(
          PublishMediaPinner.isMediaRef('dmt-asset://u/w/${'a' * 64}.png'),
          isTrue);
    });

    test('pinlenmez: zaten pub/, first-party art, düz metin', () {
      expect(PublishMediaPinner.isMediaRef('dmt-asset://pub/${'a' * 64}.png'),
          isFalse);
      expect(PublishMediaPinner.isMediaRef('dmt-art://abc.webp'), isFalse);
      expect(PublishMediaPinner.isMediaRef(''), isFalse);
      expect(PublishMediaPinner.isMediaRef('Goblin'), isFalse);
      expect(PublishMediaPinner.isMediaRef('a.png'), isFalse); // ayırıcı yok
      expect(PublishMediaPinner.isMediaRef('notes/readme.txt'), isFalse);
      expect(PublishMediaPinner.isMediaRef('x' * 2000), isFalse);
    });
  });
}
