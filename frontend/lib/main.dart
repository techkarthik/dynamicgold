import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/glass_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProGoldApp());
}

class ProGoldApp extends StatelessWidget {
  const ProGoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'ProGold Multi-Tenant PostgreSQL Platform',
        debugShowCheckedModeBanner: false,
        theme: GlassTheme.lightTheme,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              child: auth.isAuthenticated
                  ? const HomeScreen(key: ValueKey('Home'))
                  : const AuthScreen(key: ValueKey('Auth')),
            );
          },
        ),
      ),
    );
  }
}
