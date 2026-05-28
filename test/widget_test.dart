import 'package:flutter_test/flutter_test.dart';
import 'package:project_hand/main.dart';

void main() {
  testWidgets('mostra la control room', (tester) async {
    await tester.pumpWidget(const HandProjectApp());

    expect(find.text('Hand Project'), findsWidgets);
    expect(find.text('Controllo manuale'), findsOneWidget);
    expect(find.text('Apri tutto'), findsOneWidget);
    expect(find.text('Chiudi tutto'), findsOneWidget);
  });
}
