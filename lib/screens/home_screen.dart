import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:focused_menu/focused_menu.dart';
import 'package:focused_menu/modals.dart';
import 'package:openscan/Utilities/constants.dart';
import 'package:openscan/screens/about_screen.dart';
import 'package:openscan/screens/view_document.dart';
import 'package:path_provider/path_provider.dart';

import 'scan_document.dart';

class HomeScreen extends StatefulWidget {
  static String route = "HomeScreen";

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> imageDirectories = [];
  var imageDirPaths = [];
  var imageDirModDate = [];

  Future getDirectoryNames() async {
    Directory appDir = await getExternalStorageDirectory();
    Directory appDirPath = Directory("${appDir.path}");
    //TODO: Get other details and preview image
    appDirPath
        .list(recursive: false, followLinks: false)
        .listen((FileSystemEntity entity) {
      String path = entity.path;
      if (!imageDirPaths.contains(path) && path != '/storage/emulated/0/Android/data/com.example.openscan/files/Pictures') {
        imageDirPaths.add(path);
        getDirectoryDetails(path);
      }
      imageDirectories.sort((a,b) => a['modified'].compareTo(b['modified']));
    });
    return imageDirectories;
  }

  Future getDirectoryDetails(String path) async {
    FileStat fileStat = FileStat.statSync(path);
    imageDirectories.add({'path': path, 'modified': fileStat.modified});
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future _onRefresh() async {
    imageDirectories = [];
    imageDirectories = await getDirectoryNames();
    setState(() {});
  }

  void getData() {
    _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String folderName;
    return SafeArea(
      child: Scaffold(
        backgroundColor: primaryColor,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: primaryColor,
          title: RichText(
            text: TextSpan(
              text: 'Open',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: 'Scan', style: TextStyle(color: secondaryColor))
              ],
            ),
          ),
        ),
        drawer: Container(
          width: size.width * 0.6,
          color: primaryColor,
          child: Column(
            children: <Widget>[
              Spacer(),
              Image.asset(
                'assets/scan_g.jpeg',
                scale: 6,
              ),
              Spacer(),
              Divider(
                thickness: 0.2,
                indent: 6,
                endIndent: 6,
                color: Colors.white,
              ),
              ListTile(
                title: Center(
                  child: Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
              Divider(
                thickness: 0.2,
                indent: 6,
                endIndent: 6,
                color: Colors.white,
              ),
              ListTile(
                title: Center(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                onTap: () {},
              ),
              Divider(
                thickness: 0.2,
                indent: 6,
                endIndent: 6,
                color: Colors.white,
              ),
              ListTile(
                title: Center(
                  child: Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AboutScreen.route);
                },
              ),
              Divider(
                thickness: 0.2,
                indent: 6,
                endIndent: 6,
                color: Colors.white,
              ),
              Spacer(
                flex: 10,
              ),
              IconButton(
                icon: Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
                color: secondaryColor,
              ),
              Spacer(),
            ],
          ),
        ),
        body: RefreshIndicator(
          backgroundColor: primaryColor,
          color: secondaryColor,
          onRefresh: _onRefresh,
          child: FutureBuilder(
            future: getDirectoryNames(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              return ListView.builder(
                itemCount: imageDirectories.length,
                itemBuilder: (context, index) {
                  folderName = imageDirectories[index]['path'].substring(
                      imageDirectories[index]['path'].lastIndexOf('/') + 1,
                      imageDirectories[index]['path'].length - 1);
                  return FocusedMenuHolder(
                    onPressed: null,
                    menuWidth: size.width * 0.44,
                    child: ListTile(
                      // TODO : Add sample image
                      leading: Icon(
                        Icons.landscape,
                        size: 30,
                      ),
                      title: Text(folderName),
                      //TODO: Add date, no. of images
                      subtitle: Text('Last Modified: ${imageDirectories[index]['modified'].day}-${imageDirectories[index]['modified'].month}-${imageDirectories[index]['modified'].year}'),
                      trailing: Icon(
                        Icons.arrow_right,
                        size: 30,
                        color: secondaryColor,
                      ),
                      onTap: () async {
                        getDirectoryNames();
                        print(imageDirectories[index]);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewDocument(
                              dirPath: imageDirectories[index]['path'],
                            ),
                          ),
                        ).whenComplete(() => () {
                              print('Completed');
                            });
                      },
                    ),
                    menuItems: [
                      FocusedMenuItem(
                        title: Text('Delete'),
                        trailingIcon: Icon(Icons.delete),
                        backgroundColor: Colors.redAccent,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                title: Text('Delete'),
                                content:
                                    Text('Do you really want to delete file?'),
                                actions: <Widget>[
                                  FlatButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Cancel'),
                                  ),
                                  FlatButton(
                                    onPressed: () {
                                      Directory(imageDirectories[index]['path'])
                                          .deleteSync(recursive: true);
                                      Navigator.pop(context);
                                      getData();
                                    },
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        floatingActionButton: Builder(builder: (context) {
          return FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, ScanDocument.route);
            },
            backgroundColor: secondaryColor,
            child: Icon(
              Icons.camera,
              color: primaryColor,
            ),
          );
        }),
      ),
    );
  }
}
