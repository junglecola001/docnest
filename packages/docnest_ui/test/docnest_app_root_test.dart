import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DocNestAppRoot shows the home it is given', (WidgetTester tester) async {
    await tester.pumpWidget(
      DocNestAppRoot(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Center(child: Text('docnest home')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('docnest home'), findsOneWidget);
  });

  testWidgets('DocNestAppRoot publishes a mobile ViewScope below 600', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool? isMobile;
    await tester.pumpWidget(
      DocNestAppRoot(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) {
            isMobile = ViewScope.isMobileOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(isMobile, isTrue);
  });
}
