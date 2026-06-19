import 'package:flutter_test/flutter_test.dart';

import 'package:haul/dev/widget_gallery.dart';

void main() {
  testWidgets('Widget gallery renders without crashing', (tester) async {
    await tester.pumpWidget(const WidgetGallery());
    await tester.pump();

    // Verify gallery title is present.
    expect(find.text('Widget Gallery'), findsOneWidget);
  });
}
