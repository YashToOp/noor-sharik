import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'screens/role_picker_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const NoorSharikApp());
}

class NoorSharikApp extends StatelessWidget {
  const NoorSharikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noor Sharik',
      debugShowCheckedModeBanner: false,
      theme: buildNoorTheme(),
      home: const RolePickerScreen(),
    );
  }
}
