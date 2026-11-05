import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front/widgets/gradient_button.dart';

void main() {
  testWidgets('loading blocks duplicate form submissions', (tester) async {
    var submissions = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GradientButton(
        text: 'Ingresar',
        isLoading: true,
        onPressed: () => submissions++,
      )),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    expect(submissions, 0);
  });

  testWidgets('enabled button submits once per tap', (tester) async {
    var submissions = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GradientButton(
        text: 'Ingresar',
        onPressed: () => submissions++,
      )),
    ));
    await tester.tap(find.text('Ingresar'));
    expect(submissions, 1);
  });

  testWidgets('missing callback keeps the button disabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GradientButton(text: 'Ingresar')),
    ));
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
  });
}
