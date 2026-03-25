import 'package:flutter_test/flutter_test.dart';

import 'package:open_code_lumina/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenCodeLuminaApp());

    expect(find.text('OpenCodeLumina'), findsOneWidget);
    expect(find.text('输入消息...'), findsOneWidget);
  });

  testWidgets('Welcome message displays', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenCodeLuminaApp());

    expect(find.text('欢迎使用 OpenCodeLumina'), findsOneWidget);
    expect(
        find.text('基于 Ollama 的智能助手\n支持 Markdown 和 LaTeX 数学公式'), findsOneWidget);
  });

  testWidgets('Connection status displays', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenCodeLuminaApp());

    expect(find.text('未连接服务器'), findsOneWidget);
  });
}
