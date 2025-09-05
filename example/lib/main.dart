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
  /// Here we store both hyphen instances (for UTF-8 and ISO8859-encoded dictionaries) in order
  /// to be able to dispose them later.
  ///
  /// Usually you'll only need one of those, this is just for the example.
  List<Hyphen> hyphens = [];

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

  _HyphenationResults? hyphenationResultsIso8859;
  _HyphenationResults? hyphenationResultsUtf8;

  Future<_HyphenationResults> _hyphenateWithDictionary(
    String dictionaryPath,
  ) async {
    Hyphen hyphen = await Hyphen.fromDictionaryPath(dictionaryPath);
    hyphens.add(hyphen);

    List<String> hyphenateResults = [];
    List<String> hyphenateResultsLegacy2 = [];
    List<String> hyphenateResultsLegacy3 = [];

    for (String word in words) {
      /// Main hyphenation function which combines hnj_hyphenate2 and hnj_hyphenate3
      final result = hyphen.hyphenate(word, lhmin: 3, rhmin: 3);
      hyphenateResults.add(result.join("-"));

      /// Legacy API 2, using hnj_hyphenate2
      final resultLegacy2 = hyphen.hnjHyphenate2(word);
      hyphenateResultsLegacy2.add(resultLegacy2);

      /// Legacy API 3, using hnj_hyphenate3
      final resultLegacy3 = hyphen.hnjHyphenate3(word, lhmin: 3, rhmin: 3);
      hyphenateResultsLegacy3.add(resultLegacy3);
    }

    return _HyphenationResults(
      results: hyphenateResults,
      resultsLegacyApi2: hyphenateResultsLegacy2,
      resultsLegacyApi3: hyphenateResultsLegacy3,
    );
  }

  @override
  void initState() {
    super.initState();

    Future.wait([
      _hyphenateWithDictionary(
        "assets/hyph_de_DE_UTF.dic",
      ), // UTF8-encoded dictionary
      _hyphenateWithDictionary(
        "assets/hyph_de_DE.dic",
      ), // ISO8859-encoded dictionary
    ]).then((value) {
      setState(() {
        hyphenationResultsUtf8 = value[0];
        hyphenationResultsIso8859 = value[1];
      });
    });
  }

  @override
  void dispose() {
    for (var e in hyphens) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                hyphenationResultsUtf8 != null
                    ? _HyphenationResultsWidget(
                      results: hyphenationResultsUtf8!,
                      encoding: "UTF-8",
                    )
                    : CircularProgressIndicator(),
                hyphenationResultsIso8859 != null
                    ? _HyphenationResultsWidget(
                      results: hyphenationResultsIso8859!,
                      encoding: "ISO8859",
                    )
                    : CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HyphenationResultsWidget extends StatelessWidget {
  final _HyphenationResults results;
  final String encoding;

  const _HyphenationResultsWidget({
    required this.results,
    required this.encoding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          encoding,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 24),
        _SingleHyphenationResultWidget(
          title: "Hyphenated words:",
          hyphenatedWords: results.results,
        ),
        SizedBox(height: 16),
        _SingleHyphenationResultWidget(
          title: "Hyphenated words legacy API 2:",
          hyphenatedWords: results.resultsLegacyApi2,
        ),
        SizedBox(height: 16),
        _SingleHyphenationResultWidget(
          title: "Hyphenated words legacy API 3:",
          hyphenatedWords: results.resultsLegacyApi3,
        ),
      ],
    );
  }
}

class _SingleHyphenationResultWidget extends StatelessWidget {
  final List<String> hyphenatedWords;
  final String title;

  const _SingleHyphenationResultWidget({
    required this.hyphenatedWords,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ...hyphenatedWords.map((e) => Text(e)),
      ],
    );
  }
}

class _HyphenationResults {
  final List<String> results;
  final List<String> resultsLegacyApi2;
  final List<String> resultsLegacyApi3;

  _HyphenationResults({
    required this.results,
    required this.resultsLegacyApi2,
    required this.resultsLegacyApi3,
  });
}
