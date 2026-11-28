import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/widget/widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = WidgetBridge.channel;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('WidgetBridge', () {
    test('setDays sends the number, and never a negative one', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (c) async {
        calls.add(c);
        return null;
      });
      await WidgetBridge.instance.setDays(5);
      await WidgetBridge.instance.setDays(-3);
      await WidgetBridge.instance.clear();
      expect(calls.map((c) => c.method), everyElement('setDays'));
      expect(calls.map((c) => (c.arguments as Map)['days']), [5, 0, 0]);
    });

    test('takePending returns a waiting mood once it is given', () async {
      messenger.setMockMethodCallHandler(channel, (c) async => c.method == 'takePending' ? 4 : null);
      expect(await WidgetBridge.instance.takePending(), 4);
    });

    test('0 means a blank new entry, and nothing waiting is null', () async {
      messenger.setMockMethodCallHandler(channel, (c) async => 0);
      expect(await WidgetBridge.instance.takePending(), 0);
      messenger.setMockMethodCallHandler(channel, (c) async => null);
      expect(await WidgetBridge.instance.takePending(), isNull);
    });

    test('numbers outside 0 to 5 are ignored', () async {
      messenger.setMockMethodCallHandler(channel, (c) async => 9);
      expect(await WidgetBridge.instance.takePending(), isNull);
      messenger.setMockMethodCallHandler(channel, (c) async => -2);
      expect(await WidgetBridge.instance.takePending(), isNull);
    });

    test('without the widget code the calls do nothing and do not throw', () async {
      messenger.setMockMethodCallHandler(channel, null);
      await WidgetBridge.instance.setDays(3);
      expect(await WidgetBridge.instance.takePending(), isNull);
    });

    test('a platform error is swallowed', () async {
      messenger.setMockMethodCallHandler(channel, (c) async {
        throw PlatformException(code: 'boom');
      });
      await WidgetBridge.instance.setDays(3);
      expect(await WidgetBridge.instance.takePending(), isNull);
    });

    test('a tap that arrives while the app is open calls the listener', () async {
      var taps = 0;
      final stop = WidgetBridge.instance.listen(() => taps++);
      Future<void> send(String method) async {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method)),
          (_) {},
        );
      }

      await send('widgetAction');
      await send('somethingElse');
      expect(taps, 1);
      stop();
      await send('widgetAction');
      expect(taps, 1);
    });
  });

  // The native files cannot run in a Dart test, but these checks catch the
  // mistakes that are easy to make: a renamed id, a missing receiver, a
  // channel name that does not match.
  group('Android widget files', () {
    String read(String path) => File(path).readAsStringSync();
    const main = 'android/app/src/main';

    test('the manifest registers the widget and points at its info file', () {
      final m = read('$main/AndroidManifest.xml');
      expect(m, contains('android:name=".MindPalWidget"'));
      expect(m, contains('android.appwidget.action.APPWIDGET_UPDATE'));
      expect(m, contains('@xml/mindpal_widget_info'));
      expect(File('$main/res/xml/mindpal_widget_info.xml').existsSync(), isTrue);
    });

    test('the info file uses the layout that exists', () {
      final info = read('$main/res/xml/mindpal_widget_info.xml');
      expect(info, contains('@layout/mindpal_widget'));
      expect(info, contains('android:updatePeriodMillis="0"'));
      expect(File('$main/res/layout/mindpal_widget.xml').existsSync(), isTrue);
    });

    test('every view id the Kotlin code uses is in the layout', () {
      final layout = read('$main/res/layout/mindpal_widget.xml');
      final kotlin = read('$main/kotlin/com/example/mindpal/MindPalWidget.kt');
      final ids = RegExp(r'R\.id\.(\w+)').allMatches(kotlin).map((m) => m.group(1)!).toSet();
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(layout, contains('@+id/$id'), reason: id);
      }
    });

    test('every string and drawable the layout uses exists', () {
      final layout = read('$main/res/layout/mindpal_widget.xml');
      final strings = read('$main/res/values/mindpal_widget_strings.xml');
      for (final m in RegExp(r'@string/(\w+)').allMatches(layout)) {
        expect(strings, contains('name="${m.group(1)}"'), reason: m.group(1));
      }
      for (final m in RegExp(r'@drawable/(\w+)').allMatches(layout)) {
        expect(File('$main/res/drawable/${m.group(1)}.xml').existsSync(), isTrue,
            reason: m.group(1));
      }
    });

    test('the channel name is the same in Dart and in Kotlin', () {
      final activity = read('$main/kotlin/com/example/mindpal/MainActivity.kt');
      expect(activity, contains('"${WidgetBridge.channel.name}"'));
      for (final method in ['setDays', 'takePending', 'widgetAction']) {
        expect(activity, contains('"$method"'));
      }
    });

    test('the widget shows no journal text: it only reads a count', () {
      final kotlin = read('$main/kotlin/com/example/mindpal/MindPalWidget.kt');
      expect(kotlin, contains('getInt(KEY_DAYS'));
      expect(kotlin, isNot(contains('getString(KEY_')));
    });

    test('the five mood buttons match the app moods', () {
      final layout = read('$main/res/layout/mindpal_widget.xml');
      for (final e in ['😞', '😕', '😐', '🙂', '😄']) {
        expect(layout, contains(e));
      }
    });
  });
}
