import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:isolate';
import 'dart:io';

void main() => runApp(MyApp());

final String _performanceTestCollection = 'performance-test';

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Perf',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: StreamMeasureWidget(title: 'Flutter Sync Performance'),
    );
  }
}

class StreamMeasureWidget extends StatefulWidget {
  StreamMeasureWidget({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _StreamMeasureWidgetState createState() => _StreamMeasureWidgetState();
}

void logUpdates(QuerySnapshot snap) {
  print("####logUpdate received " + snap.toString());

  int added = 0;

  for (DocumentChange change in snap.documentChanges) {
    if (change.type == DocumentChangeType.added) {
      added++;
    }
  }

  print("Added: " + added.toString());
}

void listenToFirestoreUpdate(SendPort sendPort) {
  print("starting listening on the firestore");

  var result =
      Firestore().collection(_performanceTestCollection).snapshots().listen(
    logUpdates,
    onError: (e) {
      print("Listen err " + e.toString());
    },
    onDone: () {
      print("Listen done");
    },
  );

  print("started firestore listener " + result.toString());

  print("waiting infinite");
  while (true) {
    //Test!!!!!
    sleep(Duration(seconds: 1));
  }
}

class _StreamMeasureWidgetState extends State<StreamMeasureWidget> {
  int _counter = 0;
  int _stopCount = -1;
  DateTime _stopTime;

  bool showSnapshot = false;

  bool initialUpdate = true;
  DateTime startTime;

  _StreamMeasureWidgetState() {
    final response = new ReceivePort();
    print("spawning isolate");
    //Isolate.spawn(listenToFirestoreUpdate, response.sendPort);

    var result =
        Firestore().collection(_performanceTestCollection)
            .snapshots().listen(
      updateCounter,
      onError: (e) {
        print("Listen err " + e.toString());
      },
      onDone: () {
        print("Listen done");
      },
    );
  }

  void addToCount(int n, bool doSetState) {
    if (_stopCount != -1 && _counter + n >= _stopCount) {
      setState(() {
        _stopTime = DateTime.now();
        _counter += 0;
      });
    }

    if(doSetState) {
      setState(() {
        _counter += n;
      });
    } else {
      _counter += n;
    }

  }

  void updateCounter(QuerySnapshot snap) {
    int added = 0;

    for (DocumentChange change in snap.documentChanges) {
      if (!initialUpdate && startTime == null) {
        startTime = DateTime.now();
      }

      if (change.type == DocumentChangeType.added) {
        added++;
      }
    }

    if (initialUpdate) {
      print("Initial update done!");
      initialUpdate = false;
      addToCount(added, true);
    } else {
      addToCount(added, false); //doSetState = false
    }
  }

  /*
  Widget counterWidget() {

    if(showSnapshot) {
      return StreamBuilder(stream:     Firestore.instance
          .collection(_performanceTestCollection)
          .snapshots(), builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(snapshot.data.documents.length.toString());
        }
        return Text("-");
      },);
    } else {
      return Text("no snapshot");
    }
  }*/

  @override
  Widget build(BuildContext context) {
    String startedInfo = "";
    String diffStr = "";

    if (startTime != null && _stopTime != null) {
      startedInfo = "";
      diffStr = "Took: " + _stopTime.difference(startTime).toString();
    } else if (startTime != null) {
      startedInfo = "Measurement running";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Received this many new documents:',
            ),
            //counterWidget(),

            Text(
              '$_counter',
              style: Theme.of(context).textTheme.display1,
            ),
            TextFormField(
              initialValue: "-1",
              keyboardType: TextInputType.numberWithOptions(
                  signed: false, decimal: false),
              onFieldSubmitted: (String newVal) {
                setState(() {
                  _stopCount = int.parse(newVal);
                  startTime = null;
                  _stopTime = null;
                });
              },
            ),
            Text(startedInfo),
            Text(diffStr),
            CircularProgressIndicator(),
            FlatButton(
              child: Text("Show"),
              onPressed: () {
                setState(() {
                  showSnapshot = true;
                });
              },
            )
          ],
        ),
      ),
    );
  }
}
