import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kailian/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App loads and shows the primary navigation', (tester) async {
    await tester.pumpWidget(const KaiLianApp());

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('训练'), findsOneWidget);
    expect(find.text('进度'), findsOneWidget);
    expect(find.text('教练'), findsOneWidget);
  });
}
