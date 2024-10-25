import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_scanner_cropper/flutter_scanner_cropper.dart';
import 'package:open_filex/open_filex.dart';
import '../Utilities/Classes.dart';
import '../Utilities/constants.dart';
import '../Utilities/database_helper.dart';
import '../Utilities/file_operations.dart';
import '../Widgets/FAB.dart';
import '../Widgets/Image_Card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reorderables/reorderables.dart';
import 'package:share_extend/share_extend.dart';

bool enableSelect = false;
bool enableReorder = false;
bool showImage = false;
List<bool> selectedImageIndex = [];

class ViewDocument extends StatefulWidget {
  static String route = "ViewDocument";
  final DirectoryOS directoryOS;
  final bool quickScan;
  final bool fromGallery;

  ViewDocument({
    this.quickScan = false,
    required this.directoryOS,
    this.fromGallery = false,
  });

  @override
  _ViewDocumentState createState() => _ViewDocumentState();
}

class _ViewDocumentState extends State<ViewDocument>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  TransformationController _controller = TransformationController();
  DatabaseHelper database = DatabaseHelper();
  List<String> imageFilesPath = [];
  List<Widget> imageCards = [];
  FileOperations fileOperations = FileOperations();
  late List<Map<String, dynamic>> directoryData;
  List<ImageOS> directoryImages = [];
  List<ImageOS> initDirectoryImages = [];
  bool enableSelectionIcons = false;
  bool resetReorder = false;
  late ImageOS displayImage;
  int imageQuality = 2;
  late TapDownDetails doubleTapDetails;

  void getDirectoryData({
    bool updateFirstImage = false,
    bool updateIndex = false,
  }) async {
    directoryImages = [];
    initDirectoryImages = [];
    imageFilesPath = [];
    selectedImageIndex = [];
    int index = 1;
    directoryData = await database.getDirectoryData(widget.directoryOS.dirName!);
    for (var image in directoryData) {
      /// Updating first image path after delete
      if (updateFirstImage) {
        database.updateFirstImagePath(
            imagePath: image['img_path'], dirPath: widget.directoryOS.dirPath!);
        updateFirstImage = false;
      }
      var i = image['idx'];

      /// Updating index of images after delete
      if (updateIndex) {
        i = index;
        database.updateImageIndex(
          image: ImageOS(
            idx: i,
            imgPath: image['img_path'],
          ),
          tableName: widget.directoryOS.dirName!,
        );
      }

      ImageOS tempImageOS = ImageOS(
        idx: i,
        imgPath: image['img_path'],
      );
      directoryImages.add(
        tempImageOS,
      );
      initDirectoryImages.add(
        tempImageOS,
      );

      imageCards.add(
        ImageCard(
          imageOS: tempImageOS,
          directoryOS: widget.directoryOS,
          fileEditCallback: () {
            fileEditCallback(imageOS: tempImageOS);
          },
          selectCallback: () {
            selectionCallback(imageOS: tempImageOS);
          },
          imageViewerCallback: () {
            imageViewerCallback(imageOS: tempImageOS);
          },
        ),
      );

      imageFilesPath.add(image['img_path']);
      selectedImageIndex.add(false);
      index += 1;
    }
    setState(() {});
  }

  Future<void> createDirectoryPath() async {
    Directory? appDir = await getExternalStorageDirectory();
    String dirPath = "${appDir?.path}/OpenScan ${DateTime.now()}";
    String fileName = dirPath.substring(dirPath.lastIndexOf("/") + 1);
    widget.directoryOS.dirPath = dirPath;
    widget.directoryOS.dirName = fileName;
    widget.directoryOS.newName = fileName;
    // print('New Directory => ${widget.directoryOS.dirName}');
  }

  Future<dynamic> createImage({
    required bool quickScan,
    bool fromGallery = false,
  }) async {
    File? image;
    List<File>? galleryImages;
    if (fromGallery) {
      galleryImages = await fileOperations.openGallery();
    } else {
      image = await fileOperations.openCamera();
    }
    String? imageFilePath;
    Directory cacheDir = await getTemporaryDirectory();
    if (image != null || galleryImages != null) {
      if (!(quickScan || fromGallery)) {
        imageFilePath = await FlutterScannerCropper.openCrop(
          src: image!.path,
          dest: cacheDir.path,
          shouldCompress: true,
        );
      }

      if (fromGallery) {
        int dirImageLen = directoryImages.length;
        for (File galleryImage in galleryImages!) {
          if (galleryImage.existsSync()) {
            await fileOperations.saveImage(
              image: galleryImage,
              index: dirImageLen + 1,
              dirPath: widget.directoryOS.dirPath!,
            );
          }
          dirImageLen++;
        }
      } else {
        File imageFile = File(imageFilePath ?? image!.path);
        await fileOperations.saveImage(
          image: imageFile,
          index: directoryImages.length + 1,
          dirPath: widget.directoryOS.dirPath!,
        );

        await fileOperations.deleteTemporaryFiles();
        if (quickScan) {
          getDirectoryData();
          return createImage(quickScan: quickScan);
        }
        imageFilePath = null;
      }
      setState(() {});
      getDirectoryData();
    }
  }

  selectionCallback({required ImageOS imageOS}) {
    if (selectedImageIndex.contains(true)) {
      setState(() {
        enableSelectionIcons = true;
      });
    } else {
      setState(() {
        enableSelectionIcons = false;
      });
    }
  }

  void fileEditCallback({required ImageOS imageOS}) {
    bool isFirstImage = false;
    if (imageOS.imgPath == widget.directoryOS.firstImgPath) {
      isFirstImage = true;
    }
    getDirectoryData(
      updateFirstImage: isFirstImage,
      updateIndex: true,
    );
  }

  imageViewerCallback({required ImageOS imageOS}) {
    setState(() {
      displayImage = imageOS;
      showImage = true;
    });
  }

  void handleClick(String value) {
    switch (value) {
      case 'Reorder':
        setState(() {
          enableReorder = true;
        });
        break;
      case 'Select':
        setState(() {
          enableSelect = true;
        });
        break;
      case 'Share':
        showModalBottomSheet(
          context: context,
          builder: _buildBottomSheet,
        );
        break;
    }
  }

  removeSelection() {
    setState(() {
      selectedImageIndex = selectedImageIndex.map((e) => false).toList();
      enableSelect = false;
    });
  }

  deleteMultipleImages() {
    bool isFirstImage = false;
    for (var i = 0; i < directoryImages.length; i++) {
      if (selectedImageIndex[i]) {
        // print('${directoryImages[i].idx}: ${directoryImages[i].imgPath}');
        if (directoryImages[i].imgPath == widget.directoryOS.firstImgPath) {
          isFirstImage = true;
        }

        File(directoryImages[i].imgPath).deleteSync();
        database.deleteImage(
          imgPath: directoryImages[i].imgPath,
          tableName: widget.directoryOS.dirName!,
        );
      }
    }
    database.updateImageCount(
      tableName: widget.directoryOS.dirName!,
    );
    try {
      Directory(widget.directoryOS.dirPath!).deleteSync(recursive: false);
      database.deleteDirectory(dirPath: widget.directoryOS.dirPath!);
    } catch (e) {
      getDirectoryData(
        updateFirstImage: isFirstImage,
        updateIndex: true,
      );
    }
    removeSelection();
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    if (widget.directoryOS.dirPath != null) {
      getDirectoryData();
    } else {
      createDirectoryPath();
      if (widget.fromGallery) {
        createImage(
          quickScan: false,
          fromGallery: true,
        );
      } else {
        createImage(quickScan: widget.quickScan);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: WillPopScope(
        onWillPop: () {
          if (enableSelect || enableReorder || showImage) {
            setState(() {
              enableSelect = false;
              removeSelection();
              enableReorder = false;
              showImage = false;
            });
          } else {
            Navigator.pop(context);
          }
          return Future.value(false);
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: primaryColor,
              key: scaffoldKey,
              appBar: AppBar(
                elevation: 0,
                backgroundColor: primaryColor,
                leading: (enableSelect || enableReorder)
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 30,
                        ),
                        onPressed: (enableSelect)
                            ? () {
                                removeSelection();
                              }
                            : () {
                                setState(() {
                                  directoryImages = [];
                                  for (var image in initDirectoryImages) {
                                    directoryImages.add(image);
                                  }
                                  enableReorder = false;
                                });
                              },
                      )
                    : IconButton(
                        icon: Icon(Icons.arrow_back_ios),
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                      ),
                title: Text(
                  widget.directoryOS.newName ?? "",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                actions: (enableReorder)
                    ? [
                        GestureDetector(
                          onTap: () {
                            for (var i = 1; i <= directoryImages.length; i++) {
                              directoryImages[i - 1].idx = i;
                              if (i == 1) {
                                database.updateFirstImagePath(
                                  dirPath: widget.directoryOS.dirPath!,
                                  imagePath: directoryImages[i - 1].imgPath,
                                );
                                widget.directoryOS.firstImgPath =
                                    directoryImages[i - 1].imgPath;
                              }
                              database.updateImagePath(
                                image: directoryImages[i - 1],
                                tableName: widget.directoryOS.dirName!,
                              );
                              // print('$i: ${directoryImages[i - 1].imgPath}');
                            }
                            setState(() {
                              enableReorder = false;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.only(right: 25),
                            alignment: Alignment.center,
                            child: Text(
                              'Done',
                              style: TextStyle(color: secondaryColor),
                            ),
                          ),
                        ),
                      ]
                    : [
                        (enableSelect)
                            ? IconButton(
                                icon: Icon(
                                  Icons.share,
                                  color: (enableSelectionIcons)
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                                onPressed: (enableSelectionIcons)
                                    ? () {
                                        showModalBottomSheet(
                                          context: context,
                                          builder: _buildBottomSheet,
                                        );
                                      }
                                    : () {},
                              )
                            : IconButton(
                                icon: Icon(Icons.picture_as_pdf),
                                onPressed: () async {
                                  await fileOperations.saveToAppDirectory(
                                    fileName: widget.directoryOS.newName!,
                                    images: directoryImages,
                                  );
                                  Directory storedDirectory =
                                      await getApplicationDocumentsDirectory();
                                  final result = await OpenFilex.open(
                                      '${storedDirectory.path}/${widget.directoryOS.newName!}.pdf');
                                  setState(() {
                                    // String _openResult =
                                    //     "type=${result.type}  message=${result.message}";
                                    // print(_openResult);
                                  });
                                },
                              ),
                        (enableSelect)
                            ? IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: (enableSelectionIcons)
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                onPressed: (enableSelectionIcons)
                                    ? () {
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
                                              content: Text(
                                                  'Do you really want to delete this file?'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      deleteMultipleImages,
                                                  child: Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.redAccent),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    : () {},
                              )
                            : PopupMenuButton<String>(
                                onSelected: handleClick,
                                color: primaryColor.withOpacity(0.95),
                                elevation: 30,
                                offset: Offset.fromDirection(20, 50),
                                icon: Icon(Icons.more_vert),
                                itemBuilder: (context) {
                                  return [
                                    PopupMenuItem(
                                      value: 'Select',
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Select'),
                                          SizedBox(width: 10),
                                          Icon(
                                            Icons.select_all,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Reorder',
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Reorder'),
                                          SizedBox(width: 10),
                                          Icon(
                                            Icons.reorder,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Share',
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Export'),
                                          SizedBox(width: 10),
                                          Icon(
                                            Icons.share,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ];
                                },
                              ),
                      ],
              ),
              body: RefreshIndicator(
                backgroundColor: primaryColor,
                color: secondaryColor,
                onRefresh: () async {
                  getDirectoryData();
                },
                child: Padding(
                  padding: EdgeInsets.all(size.width * 0.01),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.fromSwatch()
                            .copyWith(secondary: primaryColor)),
                    child: ListView(
                      children: [
                        ReorderableWrap(
                          spacing: 10,
                          runSpacing: 10,
                          minMainAxisCount: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: directoryImages.map((image) {
                            return ImageCard(
                              imageOS: image,
                              directoryOS: widget.directoryOS,
                              fileEditCallback: () {
                                fileEditCallback(imageOS: image);
                              },
                              selectCallback: () {
                                selectionCallback(imageOS: image);
                              },
                              imageViewerCallback: () {
                                imageViewerCallback(imageOS: image);
                              },
                            );
                          }).toList(),
                          onReorder: (int oldIndex, int newIndex) {
                            Widget image = imageCards.removeAt(oldIndex);
                            imageCards.insert(newIndex, image);
                            ImageOS image1 = directoryImages.removeAt(oldIndex);
                            directoryImages.insert(newIndex, image1);
                            setState(() {});
                          },
                          onNoReorder: (int index) {
                            debugPrint(
                                '${DateTime.now().toString().substring(5, 22)} reorder cancelled. index:$index');
                          },
                          onReorderStarted: (int index) {
                            debugPrint(
                                '${DateTime.now().toString().substring(5, 22)} reorder started: index:$index');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              floatingActionButton: FAB(
                normalScanOnPressed: () {
                  createImage(quickScan: false);
                },
                quickScanOnPressed: () {
                  createImage(quickScan: true);
                },
                galleryOnPressed: () {
                  createImage(quickScan: false, fromGallery: true);
                },
              ),
            ),
            (showImage)
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        showImage = false;
                      });
                    },
                    child: Container(
                      width: size.width,
                      height: size.height,
                      padding: EdgeInsets.all(20),
                      color: primaryColor.withOpacity(0.8),
                      child: GestureDetector(
                        onDoubleTapDown: (details) {
                          doubleTapDetails = details;
                        },
                        onDoubleTap: () {
                          if (_controller.value != Matrix4.identity()) {
                            _controller.value = Matrix4.identity();
                          } else {
                            final position = doubleTapDetails.localPosition;
                            _controller.value = Matrix4.identity()
                              ..translate(-position.dx, -position.dy)
                              ..scale(2.0);
                          }
                        },
                        child: InteractiveViewer(
                          transformationController: _controller,
                          maxScale: 10,
                          child: GestureDetector(
                            child: Image.file(
                              File(displayImage.imgPath),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    FileOperations fileOperations = FileOperations();
    late String selectedFileName;

    updateSelectedFileName() {
      int selectedCount = 0;
      for (bool i in selectedImageIndex) {
        selectedCount += (i) ? 1 : 0;
      }
      selectedFileName = widget.directoryOS.newName! + ' $selectedCount';
      // print(selectedFileName);
    }

    return Container(
      color: primaryColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(25, 20, 25, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.directoryOS.newName!,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) {
                        int imageQualityTemp = imageQuality;
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(10),
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          content: StatefulBuilder(
                            builder: (BuildContext context,
                                void Function(void Function()) setState) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Export Quality',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Select export quality:'),
                                  ),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (imageQualityTemp != 1) {
                                            imageQualityTemp = 1;
                                            setState(() {});
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(5),
                                              bottomLeft: Radius.circular(5),
                                            ),
                                            border: Border.all(
                                                color: secondaryColor
                                                    .withOpacity(0.5)),
                                            color: (imageQualityTemp == 1)
                                                ? secondaryColor
                                                : primaryColor,
                                          ),
                                          height: 35,
                                          width: 70,
                                          child: Text(
                                            'Low',
                                            style: TextStyle(
                                                color: (imageQualityTemp == 1)
                                                    ? primaryColor
                                                    : secondaryColor),
                                          ),
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 1,
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (imageQualityTemp != 2) {
                                            imageQualityTemp = 2;
                                            setState(() {});
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: (imageQualityTemp == 2)
                                                ? secondaryColor
                                                : primaryColor,
                                            border: Border.all(
                                              color: secondaryColor
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                          height: 35,
                                          width: 70,
                                          child: Text(
                                            'Medium',
                                            style: TextStyle(
                                                color: (imageQualityTemp == 2)
                                                    ? primaryColor
                                                    : secondaryColor),
                                          ),
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 1,
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (imageQualityTemp != 3) {
                                            imageQualityTemp = 3;
                                            setState(() {});
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.only(
                                              topRight: Radius.circular(5),
                                              bottomRight: Radius.circular(5),
                                            ),
                                            border: Border.all(
                                                color: secondaryColor
                                                    .withOpacity(0.5)),
                                            color: (imageQualityTemp == 3)
                                                ? secondaryColor
                                                : primaryColor,
                                          ),
                                          height: 35,
                                          width: 70,
                                          child: Text(
                                            'High',
                                            style: TextStyle(
                                                color: (imageQualityTemp == 3)
                                                    ? primaryColor
                                                    : secondaryColor),
                                          ),
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          imageQuality = imageQualityTemp;
                                          print(
                                              'Selected Image Quality: $imageQuality');
                                          Navigator.pop(context);
                                          showModalBottomSheet(
                                            context: context,
                                            builder: _buildBottomSheet,
                                          );
                                        },
                                        child: Text(
                                          'Done',
                                          style:
                                              TextStyle(color: secondaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    child: Text('Quality'),
                    padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            thickness: 0.2,
            indent: 8,
            endIndent: 8,
            color: Colors.white,
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf),
            title: Text('Share PDF'),
            onTap: () async {
              if (enableSelect) {
                updateSelectedFileName();
              }
              List<ImageOS> selectedImages = [];
              for (var image in directoryImages) {
                if (selectedImageIndex.elementAt(image.idx - 1)) {
                  selectedImages.add(image);
                }
              }
              await fileOperations.saveToAppDirectory(
                fileName: (enableSelect)
                    ? selectedFileName
                    : widget.directoryOS.newName!,
                images: (enableSelect) ? selectedImages : directoryImages,
              );
              Directory storedDirectory =
                  await getApplicationDocumentsDirectory();
              ShareExtend.share(
                  '${storedDirectory.path}/${(enableSelect) ? selectedFileName : widget.directoryOS.newName!}.pdf',
                  'file');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.phone_android),
            title: Text('Save to device'),
            onTap: () async {
              if (enableSelect) {
                updateSelectedFileName();
              }
              List<ImageOS> selectedImages = [];
              for (var image in directoryImages) {
                if (selectedImageIndex.elementAt(image.idx - 1)) {
                  selectedImages.add(image);
                }
              }
              String? savedDirectory = await fileOperations.saveToDevice(
                context: context,
                fileName: (enableSelect)
                    ? selectedFileName
                    : widget.directoryOS.newName!,
                images: (enableSelect) ? selectedImages : directoryImages,
                quality: imageQuality,
              );
              Navigator.pop(context);
              String displayText;
              (savedDirectory != null)
                  ? displayText = "PDF Saved at\n$savedDirectory"
                  : displayText = "Failed to generate pdf. Try Again.";
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                    contentPadding: EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 5.0),
                    content: StatefulBuilder(
                      builder: (BuildContext context,
                          void Function(void Function()) setState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Saved to Device',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 20),
                              child: Text(
                                displayText,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Done',
                                    style: TextStyle(color: secondaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.image),
            title: Text('Share images'),
            onTap: () {
              List<String> selectedImagesPath = [];
              for (var image in directoryImages) {
                if (selectedImageIndex.elementAt(image.idx - 1)) {
                  selectedImagesPath.add(image.imgPath);
                }
              }
              ShareExtend.shareMultiple(
                  (enableSelect) ? selectedImagesPath : imageFilesPath, 'file');
              Navigator.pop(context);
            },
          ),
          // (enableSelect)
          //     ? Container()
          //     : ListTile(
          //         leading: Icon(
          //           Icons.delete,
          //           color: Colors.redAccent,
          //         ),
          //         title: Text(
          //           'Delete All',
          //           style: TextStyle(color: Colors.redAccent),
          //         ),
          //         onTap: () {
          //           Navigator.pop(context);
          //           showDialog(
          //             context: context,
          //             builder: (context) {
          //               return AlertDialog(
          //                 shape: RoundedRectangleBorder(
          //                   borderRadius: BorderRadius.all(
          //                     Radius.circular(10),
          //                   ),
          //                 ),
          //                 title: Text('Delete'),
          //                 content:
          //                     Text('Do you really want to delete this file?'),
          //                 actions: <Widget>[
          //                   TextButton(
          //                     onPressed: () => Navigator.pop(context),
          //                     child: Text('Cancel'),
          //                   ),
          //                   TextButton(
          //                     onPressed: () {
          //                       Directory(dirPath).deleteSync(recursive: true);
          //                       DatabaseHelper()
          //                         ..deleteDirectory(dirPath: dirPath);
          //                       Navigator.popUntil(
          //                         context,
          //                         ModalRoute.withName(HomeScreen.route),
          //                       );
          //                     },
          //                     child: Text(
          //                       'Delete',
          //                       style: TextStyle(color: Colors.redAccent),
          //                     ),
          //                   ),
          //                 ],
          //               );
          //             },
          //           );
          //         },
          //       ),
        ],
      ),
    );
  }
}
