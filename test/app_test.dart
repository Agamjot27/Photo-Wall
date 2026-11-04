import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/app/photo_wall_app.dart';

void main() {
  testWidgets('app starts on the Photo Wall screen', (tester) async {
    await tester.pumpWidget(const PhotoWallApp());

    expect(find.text('Photo Wall'), findsOneWidget);
    expect(find.text('Your photo collection starts here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
