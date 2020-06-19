import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_progress_button/flutter_progress_button.dart';

import 'otp.dart';
//import 'package:otp/otp.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(MyApp(
    initialRoute: prefs.containsKey("sharedSecret") ? '/freieRaeume' : '/start',
  ));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  MyApp({this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freie Räume',
      routes: {
        '/start': (context) => SelectSchool(),
        '/login': (context) => Login(),
        '/freieRaeume': (context) => FreieRaeume()
      },
      initialRoute: initialRoute,
    );
  }
}

class SelectSchool extends StatefulWidget {
  @override
  _SelectSchoolState createState() => new _SelectSchoolState();
}

class _SelectSchoolState extends State<SelectSchool> {
  String url = 'https://mobile.webuntis.com/ms/schoolquery2/?v=a4.1.5';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        title: Text("Schule auswählen"),
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 20,
            child: Container(
              width: MediaQuery.of(context).size.width / 4 * 3,
              child: TypeAheadField(
                textFieldConfiguration: TextFieldConfiguration(
                    autofocus: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      labelStyle: new TextStyle(color: Colors.white),
                    )),
                suggestionsCallback: (pattern) async {
                  var suggestions = [];
                  var data = await _getSuggestions(pattern);
                  var json = jsonDecode(data.body);

                  suggestions = [];
                  if (json.containsKey("result")) {
                    var schools = json['result']['schools'] as List;

                    for (int i = 0; i < schools.length; i++) {
                      suggestions.add({
                        'name': schools[i]['displayName'],
                        'address': schools[i]['address'],
                        'api': (schools[i]['mobileServiceUrl'] +
                            "?school=" +
                            schools[i]['loginName'])
                      });
                    }
                  } else {
                    if (json.containsKey("error")) {
                      suggestions.add({
                        'name': "Too many results",
                        'api': "",
                        'address': ''
                      });
                    }
                  }
                  return suggestions;
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    title: Text(suggestion['name']),
                    subtitle: suggestion['address'] != ''
                        ? Text(suggestion['address'])
                        : null,
                  );
                },
                onSuggestionSelected: (suggestion) async {
                  if (suggestion['api'] != '') {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    prefs.setString("apiLink", suggestion['api']);
                    Navigator.of(context).pushNamed("/login");
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<http.Response> _getSuggestions(String part) async {
    return http.post(url,
        body: json.encode({
          'id': "untis-mobile-android-4.1.5",
          'jsonrpc': "2.0",
          'method': 'searchSchool',
          'params': [
            {'schoolid': 0, 'search': part}
          ]
        }));
  }
}

Future<String> checkLogin(String username, String password) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString("username", username);
  var data = await http.post(
      prefs.getString("apiLink") + "&v=4.1.5&gm=getAppSharedSecret",
      body: jsonEncode({
        'id': "untis-mobile-android-4.1.5",
        'jsonrpc': "2.0",
        'method': 'getAppSharedSecret',
        'params': [
          {'password': password, 'userName': username}
        ]
      }));
  var json = jsonDecode(data.body);
  if (json['result'] != null) {
    return json['result'];
  } else {
    if (json['error'] != null) {
      throw Error();
    }
  }
}

class Login extends StatefulWidget {
  @override
  _LoginState createState() => new _LoginState();
}

class _LoginState extends State<Login> {
  bool enabled = true;
  String username = "";
  String password = "";
  @override
  Widget build(BuildContext context) {
    final emailField = TextField(
      obscureText: false,
      onChanged: (text) => username = text,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Email",
          enabled: enabled,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );
    final passwordField = TextField(
      obscureText: true,
      onChanged: (text) => password = text,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Password",
          enabled: enabled,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Login"),
      ),
      body: Center(
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                emailField,
                SizedBox(height: 25.0),
                passwordField,
                SizedBox(
                  height: 35.0,
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return ProgressButton(
                      color: Color(0xff01A0C7),
                      defaultWidget: const Text(
                        'Login',
                        style: TextStyle(color: Colors.white),
                      ),
                      progressWidget: const CircularProgressIndicator(),
                      width: 196,
                      height: 40,
                      onPressed: () async {
                        try {
                          var data = await checkLogin(username, password);
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          prefs.setString("sharedSecret", data);
                          Navigator.of(context).pushNamedAndRemoveUntil(
                              '/freieRaeume', (Route<dynamic> route) => false);
                        } catch (e) {
                          Scaffold.of(context).showSnackBar(SnackBar(
                            content: Text(
                                "An error occured. Check your connection or login credentials"),
                          ));
                        }
                      },
                    );
                  },
                ),
                SizedBox(
                  height: 15.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Timegrid {
  final DateTime startTime;
  final DateTime endTime;

  Timegrid({this.startTime, this.endTime});

  factory Timegrid.fromJson(Map<String, dynamic> json) {
    var format = new DateFormat("HH:mm");
    return Timegrid(
        startTime: format.parse((json['startTime']).toString().substring(1)),
        endTime: format.parse((json['endTime']).toString().substring(1)));
  }
}

class Room {
  final int id;
  final String name;
  final String longName;

  Room({this.id, this.name, this.longName});

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
        id: json['id'] as int,
        name: json['name'] as String,
        longName: json['longName'] as String);
  }
}

class FreieRaeume extends StatefulWidget {
  @override
  _FreieRaeumeState createState() => new _FreieRaeumeState();
}

class _FreieRaeumeState extends State<FreieRaeume> {
  Timegrid dropdownValue;
  List<Timegrid> items = [];
  List<Room> rooms = [];
  DateFormat df = DateFormat("HH:mm");
  DateTime selectedDate = DateTime.now();
  ValueNotifier<Future<List<Room>>> freeRooms =
      ValueNotifier(Future.value(null));
  GlobalKey roomListKey = GlobalKey();
  DateTime currentDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    _getData().then((data) {
      if (data != null) {
        var json = jsonDecode(data.body);
        rooms = (json['result']['masterData']['rooms'] as List).map((room) {
          return Room.fromJson(room);
        }).toList();
        List l = (json['result']['masterData']['timeGrid']['days'] as List)[0]
            ['units'] as List;
        List<Timegrid> timegrids = l.map((timegrid) {
          return Timegrid.fromJson(timegrid);
        }).toList();
        setState(() {
          items = timegrids;
        });
      }
    });
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        title: Text("Freie Räume"),
      ),
      body: Form(
        child: FutureBuilder(
          future: _getData(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "An Error has occured, try again or check your internet connection",
                  style: TextStyle(color: Colors.red),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.done) {
              return Column(
                children: <Widget>[
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<Timegrid>(
                          value: dropdownValue,
                          icon: Icon(Icons.arrow_downward),
                          iconSize: 24,
                          elevation: 16,
                          onChanged: (Timegrid newValue) {
                            dropdownValue = newValue;
                            if (currentDate != null) {
                              freeRooms.value = _getFreeRooms(
                                  dropdownValue.startTime,
                                  dropdownValue.endTime,
                                  currentDate);
                            }
                            setState(() {});
                          },
                          items: items.map<DropdownMenuItem<Timegrid>>(
                              (Timegrid value) {
                            return DropdownMenuItem<Timegrid>(
                                value: value,
                                child: Text(
                                  (items.indexOf(value) + 1).toString() +
                                      ". Stunde (" +
                                      df.format(value.startTime) +
                                      " - " +
                                      df.format(value.endTime) +
                                      ")",
                                ));
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("Datum: "),
                    FlatButton(
                      onPressed: () {
                        DatePicker.showDatePicker(context,
                            showTitleActions: true,
                            minTime: DateTime(2000, 1, 1),
                            maxTime: DateTime(2022, 12, 31),
                            // onChanged: (date) {print('change $date');},
                            onConfirm: (date) {
                          currentDate = date;
                          if (dropdownValue != null) {
                            freeRooms.value = _getFreeRooms(
                                dropdownValue.startTime,
                                dropdownValue.endTime,
                                date);
                          }
                          setState(() {});
                        }, currentTime: DateTime.now());
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: Colors.grey))),
                        child: Text(
                          DateFormat("dd.MM.yyyy").format(currentDate),
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.normal),
                        ),
                      ),
                    ),
                  ]),
                  ValueListenableBuilder(
                    valueListenable: freeRooms,
                    builder: (context, value, child) {
                      return FutureBuilder(
                        future: value,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return RoomList(snapshot.data);
                          }
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  child: CircularProgressIndicator(),
                                )
                              ],
                            );
                          }
                          return Container();
                        },
                      );
                    },
                  )
                ],
              );
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Future<List<Room>> _getFreeRooms(
      DateTime start, DateTime end, DateTime selectedDate) async {
    DateTime startTime = new DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, start.hour, start.minute);
    DateTime endTime = new DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, end.hour, end.minute);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateFormat formatter = DateFormat("yyyy-MM-dd'T'HH:mm'Z'");
    int millis = new DateTime.now().millisecondsSinceEpoch;
    var value = await http.post(
        prefs.getString("apiLink") + "&v=4.1.5&gm=getAvailableRooms2017",
        body: json.encode({
          "id": "untis-mobile-android-4.1.5",
          "jsonrpc": "2.0",
          "method": "getAvailableRooms2017",
          "params": [
            {
              "endDateTime": formatter.format(endTime),
              "startDateTime": formatter.format(startTime),
              "auth": {
                "clientTime": millis,
                "otp": OTP.generateTOTPCode(
                    prefs.getString("sharedSecret"), millis),
                "user": prefs.getString("username")
              }
            }
          ]
        }));
    var decoded = jsonDecode(value.body);

    return ((decoded['result']['roomIds'] as List).map<Room>((id) {
      return rooms.singleWhere((room) => room.id == id);
    }).toList());
  }

  Future<http.Response> _getData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int millis = new DateTime.now().millisecondsSinceEpoch;
    if (items.length == 0) {
      return http.post(
          prefs.getString("apiLink") + "&v=4.1.5&gm=getUserData2017",
          body: json.encode({
            "id": "untis-mobile-android-4.1.5",
            "jsonrpc": "2.0",
            "method": "getUserData2017",
            "params": [
              {
                "currentFcmToken": "",
                "deviceOs": "AND",
                "deviceOsVersion": "whyDoYouCare",
                "elementId": 0,
                "imei": "whyDoYouCare",
                "oldFcmToken": "",
                "auth": {
                  "clientTime": millis,
                  "otp": OTP.generateTOTPCode(
                      prefs.getString("sharedSecret"), millis),
                  "user": prefs.getString("username")
                }
              }
            ]
          }));
    } else {
      return Future.delayed(Duration(milliseconds: 0));
    }
  }
}

class RoomList extends StatelessWidget {
  List<Room> freeRooms;
  RoomList(this.freeRooms);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        itemCount: freeRooms.length,
        itemBuilder: (BuildContext context, int index) {
          Room room = freeRooms[index];
          return Card(
            child: ListTile(
              title: Text(room.name),
              subtitle: Text(room.longName),
            ),
          );
        },
      ),
    );
  }
}
