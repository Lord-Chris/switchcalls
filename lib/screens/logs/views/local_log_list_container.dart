import 'dart:async';

import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_phone_state/phone_event.dart';
import 'package:intl/intl.dart';
import 'package:switchcalls/widgets/quiet_box.dart';

class LocalLogListContainer extends StatefulWidget {
  @override
  _LocalLogListContainerState createState() => _LocalLogListContainerState();
}

class _LocalLogListContainerState extends State<LocalLogListContainer> {
  StreamController<Iterable<CallLogEntry>> phoneCallCont =
      StreamController<Iterable<CallLogEntry>>.broadcast();

  StreamSubscription<Iterable<CallLogEntry>> phoneCallSub;

  Widget getLocalIcon(CallType callStatus) {
    Icon _icon;
    double _iconSize = 15;

    switch (callStatus) {
      case CallType.outgoing:
        _icon = Icon(
          Icons.call_made,
          size: _iconSize,
          color: Colors.green,
        );
        break;

      case CallType.missed:
        _icon = Icon(
          Icons.call_missed,
          color: Colors.red,
          size: _iconSize,
        );
        break;
      case CallType.incoming:
        _icon = Icon(
          Icons.call_received,
          color: Colors.grey,
          size: _iconSize,
        );
        break;
      default:
        _icon = Icon(
          Icons.call_missed,
          color: Colors.red,
          size: _iconSize,
        );
        break;
    }
    return Container(
      margin: EdgeInsets.only(right: 5),
      child: _icon,
    );
  }

  watchEvents(PhoneCall phoneCall) {
    phoneCall.eventStream.listen((PhoneCallEvent event) {
      print("Event $event");
    });
    print("Call is complete");
  }

  Stream<Iterable<CallLogEntry>> getLocalLogs() async* {
    while (true) {
      await Future.delayed(Duration(milliseconds: 500));
      yield await CallLog.get();
    }
  }

  @override
  void initState() {
    super.initState();
    phoneCallSub = getLocalLogs().listen((event) {
      phoneCallCont.add(event);
    });
  }

  @override
  void dispose() {
    print('Closing Streams');
    phoneCallCont.close();
    phoneCallSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Iterable<CallLogEntry>>(
      stream: phoneCallCont.stream,
      builder: (BuildContext context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          List<CallLogEntry> logList = snapshot.data.toList();
          return ListView.builder(
            itemCount: logList.length,
            itemBuilder: (context, index) {
              CallLogEntry _log = logList[index];
              return ListTile(
                leading: getLocalIcon(_log.callType),
                title: Text(
                  _log.name ?? _log.number,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                subtitle: Text(
                  DateFormat().format(
                      DateTime.fromMillisecondsSinceEpoch(_log.timestamp)),
                  style: TextStyle(
                    fontSize: 13,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.call),
                  onPressed: () async {
                    debugPrint('CALLING');
                    await FlutterPhoneDirectCaller.callNumber(_log.number);
                  },
                ),
              );
            },
          );
        }
        return QuietBox(isCall: true);
      },
    );
  }
}
