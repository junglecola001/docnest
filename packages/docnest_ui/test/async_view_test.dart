import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gives the tree the directionality a bare [Text] needs.
Widget host(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  testWidgets('AsyncView renders its data builder', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        AsyncView<int>(
          value: const AsyncValue<int>.data(42),
          data: (BuildContext context, int value) => Text('value $value'),
        ),
      ),
    );

    expect(find.text('value 42'), findsOneWidget);
  });

  testWidgets('AsyncView shows the skeleton before data arrives', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        AsyncView<int>(
          value: const AsyncValue<int>.loading(),
          data: (BuildContext context, int value) => Text('value $value'),
        ),
      ),
    );

    expect(find.byType(SkeletonPill), findsWidgets);
  });

  testWidgets('AsyncView honours a custom loading builder', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        AsyncView<int>(
          value: const AsyncValue<int>.loading(),
          data: (BuildContext context, int value) => Text('value $value'),
          loading: (BuildContext context) => const Text('loading'),
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);
  });
}
