import 'package:flutter/material.dart';

import 'screens/balance_sheet_screen.dart';
import 'services/balance_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BalanceTrackerApp());
}

class BalanceTrackerApp extends StatefulWidget {
  const BalanceTrackerApp({super.key});

  @override
  State<BalanceTrackerApp> createState() => _BalanceTrackerAppState();
}

class _BalanceTrackerAppState extends State<BalanceTrackerApp> {
  final BalanceController _controller = BalanceController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E293B)),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (!_controller.isLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return BalanceSheetScreen(controller: _controller);
        },
      ),
    );
  }
}
