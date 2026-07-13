import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/torrent_manager.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TorrentManager()..initSession(),
      child: const DirXploreProApp(),
    ),
  );
}

class DirXploreProApp extends StatelessWidget {
  const DirXploreProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DirXplore Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0B10),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF00FF87),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const HomePage(),
    );
  }
}
