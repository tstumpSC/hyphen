import 'package:flutter/material.dart';
import 'package:hyphen/hyphen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Hyphen? hyphenDe;

  final List<String> words = [
    "funktioniert",
    "Arbeit",
    "ankleiden",
    "abarbeiten",
    "ableiten",
    "anders",
    "arbeiten",
    "hineinschauen",
    "vorankommen",
    "schwören",
    "schworen",
  ];

  List<String>? hyphenatedWords;

  @override
  void initState() {
    // You need to provide your own .dic file here
    Hyphen.fromDictionaryPath("assets/hyph_de_DE_UTF.dic").then((hyphen) {
      hyphenDe = hyphen;

      List<String> hyphenateResults = [];
      for (String word in words) {
        final result = hyphenDe!.hnjHyphenate2(word);
        hyphenateResults.add(result);
      }

      setState(() => hyphenatedWords = hyphenateResults);
    });

    super.initState();
  }

  @override
  void dispose() {
    hyphenDe?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child:
              hyphenatedWords == null
                  ? SizedBox.square(
                    dimension: 48.0,
                    child: CircularProgressIndicator(),
                  )
                  : Column(
                    children: hyphenatedWords!.map((e) => Text(e)).toList(),
                  ),
        ),
      ),
    );
  }
}
