import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/features/photos/models/photo.dart';
import 'package:photo_wall/features/photos/models/photo_catalog.dart';

void main() {
  test('catalog contains at least 100 distinct valid photo sources', () {
    expect(photoCatalog.length, greaterThanOrEqualTo(100));
    expect(
      photoCatalog.map((photo) => photo.id).toSet().length,
      photoCatalog.length,
    );
    for (final photo in photoCatalog) {
      expect(photo.author, isNotEmpty);
      expect(photo.width, greaterThan(0));
      expect(photo.height, greaterThan(0));
      final thumbnail = Uri.parse(photo.thumbnailUrl);
      final full = Uri.parse(photo.fullScreenUrl);
      expect(thumbnail.scheme, 'https');
      expect(full.host, 'picsum.photos');
      expect(thumbnail.pathSegments[1], photo.id);
      expect(full.pathSegments[1], photo.id);
      final width = int.parse(full.pathSegments[2]);
      final height = int.parse(full.pathSegments[3]);
      expect(width, inInclusiveRange(1, 1600));
      expect(height, inInclusiveRange(1, 1600));
      expect(width / height, closeTo(photo.width / photo.height, 0.02));
    }
  });

  test('viewer does not upscale small sources', () {
    const photo = Photo(id: 'test', author: 'Test', width: 200, height: 300);
    expect(photo.fullScreenUrl, 'https://picsum.photos/id/test/200/300');
  });
}
