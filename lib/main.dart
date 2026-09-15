import 'package:flutter/material.dart';
import 'package:galileo_flutter/galileo_flutter.dart';

import 'benchmark_runner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception is AssertionError &&
        details.exception.toString().contains('KeyDownEvent is dispatched')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  try {
    await initGalileo();
  } catch (e) {
    debugPrint('initGalileo initialization notice: $e');
  }

  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galileo Flutter vs Flutter Map Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF09090B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF18181B),
        ),
      ),
      home: const BenchmarkRunnerScreen(),
    );
  }
}
