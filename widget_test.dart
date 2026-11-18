// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:proteqt/main.dart';

void main() {
  testWidgets('renders the Proteqt home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'profile_registered': true,
      'full_name': 'Test User',
      'mobile_number': '9000000000',
      'date_of_birth': '01/01/1990',
      'blood_group': 'O+',
      'emergency_name': 'Emergency Contact',
      'emergency_phone': '9111111111',
      'notes': '',
    });
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpWidget(const ProteqtApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('PROTE'), findsOneWidget);
    expect(find.text('YOU ARE SAFE'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
