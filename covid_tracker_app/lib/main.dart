import 'dart:async';
import 'dart:convert';

import 'package:blinkid_flutter/microblink_scanner.dart';
import 'package:blinkid_flutter/overlay_settings.dart';
import 'package:blinkid_flutter/recognizer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Covid Tracker App',
      theme: CupertinoThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primaryColor: Colors.amber),
      home: MyHomePage(title: 'Covid Tracker App'),
      localizationsDelegates: const <LocalizationsDelegate>[
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String _covidStatus = 'negative';

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void _setCovidState(String state) {
    setState(() {
      _covidStatus = state;
    });
  }

  Future<List<RecognizerResult>?> scan() async {
    List<RecognizerResult> results;

    BlinkIdRecognizer recognizer = BlinkIdRecognizer();
    OverlaySettings settings = BlinkIdOverlaySettings();
    settings.country = "Indonesia";
    settings.useFrontCamera = false;

    // set your license
    var license =
        "sRwAAAElY29tLmFkaXR5YXB1cndhLmNvdmlkLXRyYWNrZXItZmx1dHRlcnwFOkM6f9j9DST+sOlF3d9Kj7n+DuLqPbA1yNV9KAPz5YLCpuP2lpEqYNJlCJZrNsIDC0kUxZJAutdB/1fdVDy1pDQgrAx9t3Y4Kb3NhutWvA8tDWtksNZcyWEQAn4Lnk4i62Us44dgJ2IaIZEjrt9oXjDvEBGB+6v/OS9YntqkCjJHhUXQXwmCECaquIcn6ePGMhnA92yDUfZcoPLUaf3jXTzkrb/Dhzr3ZGQTqg==";
    try {
      // perform scan and gather results
      results = await MicroblinkScanner.scanWithCamera(
          RecognizerCollection([recognizer]), settings, license);
      BlinkIdRecognizerResult result = results.first as BlinkIdRecognizerResult;
      var res =
          await http.post(Uri.parse("https://covid-api.lucentshard.com/scan"),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(<String, String>{
                'nik': result.documentNumber,
                'name': result.fullName,
                'birthday': DateTime(result.dateOfBirth.year,
                        result.dateOfBirth.month, result.dateOfBirth.day)
                    .toIso8601String(),
                'birthplace': result.placeOfBirth,
                'address1': result.address,
                'address2': result.additionalAddressInformation,
                'city': result.placeOfBirth,
                'province':
                    result.additionalAddressInformation.split("\n").first
              }));
      print(jsonEncode(<String, String>{
        'nik': result.documentNumber,
        'name': result.fullName,
        'birthday': DateTime(result.dateOfBirth.year, result.dateOfBirth.month,
                result.dateOfBirth.day)
            .toIso8601String(),
        'birthplace': result.placeOfBirth,
        'address1': result.address,
        'address2': result.additionalAddressInformation,
        'city': result.placeOfBirth,
        'province': result.additionalAddressInformation.split("\n").first
      }));
      var data = jsonDecode(res.body);
      print(data['logs']);

      if (data['logs'].length == 0) {
        _setCovidState('negative');
      } else {
        dynamic firstLog = data['logs'][0];
        if (firstLog == null) {
          _setCovidState('negative');
        }else {
          var firstLogDate = DateTime.parse(firstLog["testDate"]);
          var now = DateTime.now();
          final diff =
              now.millisecondsSinceEpoch - firstLogDate.millisecondsSinceEpoch;
          if (diff / 1000 / 60 / 60 / 24 <= 7 &&
              firstLog["status"] == "positive") {
            _setCovidState('positive');
          } else {
            _setCovidState('negative');
          }
        }
      }
    } on Exception {}
    Timer(Duration(seconds: 3), () async {
      _setCovidState("neutral");
      Timer(Duration(seconds: 3), () async {
        await scan();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    this.scan().then((value) => {});
  }

  Widget getWidgetForStatus() {
    switch (_covidStatus) {
      case "negative":
        return Card(
          elevation: 0,
          color: Color.fromARGB(255, 220, 240, 220),
          child: Container(
            padding: EdgeInsets.all(100),
            child: Column(
              children: [
                Text(
                  'Covid Negative',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w100,
                      fontSize: 100),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'You may enter the area',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w400,
                        fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        );
      case "positive":
        return Card(
          elevation: 0,
          color: Color.fromARGB(255, 240, 220, 220),
          child: Container(
            padding: EdgeInsets.all(100),
            child: Column(
              children: [
                Text(
                  'Covid Positive',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w100,
                      fontSize: 100),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'You are not allowed to enter, please maintain safe distance',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w400,
                        fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return Card(
          elevation: 0,
          color: Color.fromARGB(255, 240, 240, 240),
          child: Container(
            padding: EdgeInsets.all(100),
            child: Column(
              children: [
                Text(
                  'Waiting',
                  style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w100,
                      fontSize: 100),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'Please wait',
                    style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                        fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[getWidgetForStatus()],
        ),
      ),
    );
  }
}
