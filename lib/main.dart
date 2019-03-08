import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[800],
      ),
      home: ScaffoldPage(),
    );
  }
}

class ScaffoldPage extends StatefulWidget {
  ScaffoldPage({Key key}) : super(key: key);

  @override
  _ScaffoldPageState createState() => _ScaffoldPageState();
}

class _ScaffoldPageState extends State<ScaffoldPage> {
  //String textToShow = "I Like Flutter";
  static const platform = const MethodChannel('app.channel.shared.data');
  String dataShared = "No data";

  @override
  void initState() {
    super.initState();
    getSharedText();
  }

  Future ensurePermissionAllowed() async {
    Map<PermissionGroup, PermissionStatus> permissions =
        await PermissionHandler().requestPermissions([PermissionGroup.storage]);
    switch (permissions[PermissionGroup.storage]) {
      case PermissionStatus.unknown:
      case PermissionStatus.disabled:
      case PermissionStatus.denied:
        Fluttertoast.showToast(
          msg: "Please enable storage permission!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        await PermissionHandler().openAppSettings();
        SystemNavigator.pop();
        break;
    }
  }

  getSharedText() async {
    await ensurePermissionAllowed();
    var sharedData = await platform.invokeMethod("getSharedText");
    if (sharedData != null) {
      setState(() {
        dataShared = sharedData;
        if (dataShared.contains("://youtu")) {
          startDownloadFromLink(dataShared);
        } else {
          showToast('It wasn\'t a YouTube link!');
          SystemNavigator.pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("YouTube Downloader"),
        ),
        body: ListView(
          children: <Widget>[
            Card(
              child: Container(
                child: const ListTile(
                  leading: Icon(
                    Icons.code,
                    color: Colors.white,
                  ),
                  title: Text(
                    'Made by Alessandro Ampala',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Card(
              child: Container(
                child: const ListTile(
                  leading: Icon(
                    Icons.info,
                    color: Colors.red,
                  ),
                  title: Text(
                      'Share a video from the YouTube app to start a download'),
                ),
              ),
            ),
            /* Card(
            child:
                Container(
                  child: const ListTile(
                    leading: Icon(Icons.close, color: Colors.black,),
                    title: Text('If open, close the app in order to make it work properly'),
                  ),
                ),
          ), */
            Card(
              child: Container(
                child: const ListTile(
                  leading: Icon(
                    Icons.warning,
                    color: Colors.orange,
                  ),
                  title: Text(
                      'I am not responsible of the use that you do with this software'),
                ),
              ),
            ),
          ],
        ));
  }

  void startDownloadFromLink(String url) async {
    final taskId = await FlutterDownloader.enqueue(
      url: "http://www.convertmp3.io/fetch/?video=" + url,
      savedDir: '/storage/emulated/0/Download/',
      showNotification:
          true, // show download progress in status bar (for Android)
      openFileFromNotification:
          true, // click on notification to open downloaded file (for Android)
    );

    int progresso;

    FlutterDownloader.registerCallback((id, status, progress) async {
      final task = await FlutterDownloader.loadTasksWithRawQuery(
          query: "SELECT * FROM task WHERE task_id = '" + taskId + '\';');

      progresso = progress;

      //if the video has never been downloaded from www.convertmp3.io, the progress will be less than 0
      if (progress < 0) {
        FlutterDownloader.cancel(taskId: id);
        _launchURL(url);
      } else if (progress > 0) {
        if (task != null &&
            task[0].filename != null &&
            !(task[0].filename.contains('.mp3'))) {
          showToast('Redirecting...');
          FlutterDownloader.remove(taskId: id, shouldDeleteContent: true);
          _launchURL(url);
        }
        SystemNavigator.pop();
      }

      /* Use setState to refresh the state of the app (by changing values which widgets depends on)*/
      /* setState(() {

      }); */
    });

    //if the download doesn't start, wait for 10 seconds and then retry
    Timer(new Duration(seconds: 10), () {
      checkDoesntLoad(url, taskId, progresso);
    });
  }

  void cancelAndRestartDownload(String url, String id) {
    FlutterDownloader.cancel(taskId: id);
    FlutterDownloader.remove(taskId: id, shouldDeleteContent: true);
    startDownloadFromLink("http://www.convertmp3.io/fetch/?video=" + url);
  }

  void checkDoesntLoad(String url, String taskId, int progress) async {
    final task = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE task_id = '" + taskId + '\';');

    if (task[0] != null && task[0].filename == null && progress == 0) {
      cancelAndRestartDownload(url, taskId);
    }
  }

  void showToast(String text) {
    Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch('https://break.tv/widget/button/?link=' +
          url.replaceFirst('youtu.be/', 'www.youtube.com/watch?v=') +
          '&color=DA4453&text=fff');
    } else {
      throw 'Could not launch $url';
    }
  }
}
