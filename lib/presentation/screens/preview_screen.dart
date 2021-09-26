import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openscan/core/theme/appTheme.dart';
import 'package:openscan/logic/cubit/directory_cubit.dart';
import 'package:openscan/presentation/Widgets/delete_dialog.dart';

class PreviewScreen extends StatefulWidget {
  final int initialIndex;

  const PreviewScreen({this.initialIndex});

  @override
  _PreviewScreenState createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  PageController _pageController;
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
          title: BlocConsumer<DirectoryCubit, DirectoryState>(
            listener: (context, state) {},
            builder: (context, state) {
              return RichText(
                text: TextSpan(
                  text: state.dirName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: Container(
          child: BlocConsumer<DirectoryCubit, DirectoryState>(
            listener: (context, state) {},
            builder: (context, state) {
              return PageView.builder(
                controller: _pageController,
                itemCount: state.imageCount,
                itemBuilder: (context, index) {
                  return Container(
                    child: Center(
                      child: Image.file(File(state.images[index].imgPath)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: AppTheme.primaryColor.withOpacity(0.3),
          elevation: 0,
          child: BlocConsumer<DirectoryCubit, DirectoryState>(
            listener: (context, state) {},
            builder: (context, state) {
              return Container(
                height: 56.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Icon(
                      Icons.edit,
                    ),
                    IconButton(
                      icon: Icon(Icons.crop),
                      onPressed: () {
                        BlocProvider.of<DirectoryCubit>(context).cropImage(
                          context,
                          state.images[_pageController.page.toInt()],
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) {
                            return DeleteDialog(
                              deleteOnPressed: () {
                                BlocProvider.of<DirectoryCubit>(context)
                                    .deleteImage(
                                  context,
                                  imageToDelete: state
                                      .images[_pageController.page.toInt()],
                                );
                                Navigator.pop(context);
                              },
                              cancelOnPressed: () => Navigator.pop(context),
                            );
                          },
                        );
                      },
                    ),
                    Icon(
                      Icons.more_vert,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
