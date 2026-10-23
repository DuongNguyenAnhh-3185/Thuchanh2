import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_doc_manager/data/datasources/local/app_database.dart';
import 'package:study_doc_manager/main.dart';
import 'package:study_doc_manager/service_locator.dart';

void main() {
  setUpAll(() async {
    await AppDatabase.createInMemoryDatabase(useIsolate: false);
    await ServiceLocator.instance.initialize();
  });
  tearDownAll(() async => AppDatabase.instance.close());

  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    testWidgets('Library renders at ${size.width}px without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const CashewDocApp());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      expect(find.text('CashewDoc'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
