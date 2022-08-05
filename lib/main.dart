import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import 'dungeondraft_asset_files.dart';

void main() {
  runApp(const DungeonDraftAssetExplorer());
}

class DungeonDraftAssetExplorer extends StatelessWidget {
  const DungeonDraftAssetExplorer({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dungeondraft Asset Explorer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(title: 'Dungeondraft Asset Explorer'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<HomePage> createState() => _HomePageState();
}

const String emptyText = 'Select a directory to view';

class _HomePageState extends State<HomePage> {
  DungeondraftAssetDirectory? _dungeondraftAssetDirectory;
  RegExp _searchPattern = RegExp(r'');
  final FocusNode _myFocusNode = FocusNode();

  void _openAssetDirectory() async {
    const String confirmButtonText = 'Choose Dungeondraft Asset Directory';
    final String? assetFileDirectory =
        await getDirectoryPath(confirmButtonText: confirmButtonText);
    if (assetFileDirectory == null) {
      // Operation was canceled by the user.
      return;
    }
    DungeondraftAssetDirectory ddAssetDirectory =
        DungeondraftAssetDirectory(assetFileDirectory);
    await ddAssetDirectory.loadAssetDirectory();

    setState(() {
      _dungeondraftAssetDirectory = ddAssetDirectory;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Row(children: [
              Text(widget.title),
              const Spacer(flex: 1),
              Expanded(
                  flex: 10,
                  child: TextField(
                      focusNode: _myFocusNode,
                      onSubmitted: (value) {
                        setState(() {
                          _searchPattern = RegExp(value, caseSensitive: false);
                          _myFocusNode.requestFocus();
                        });
                      },
                      decoration: const InputDecoration(
                        //border: OutlineInputBorder(),
                        labelText: 'Search',
                        fillColor: Colors.white,
                        filled: true,
                      )))
            ]),
            actions: [
              FloatingActionButton(
                  onPressed: _openAssetDirectory,
                  tooltip: 'Open Dungeondraft assets directory',
                  child: const Icon(Icons.folder_open)),
            ]),
        body: Container(
            padding: const EdgeInsets.all(4.0),
            child: CustomScrollView(
              slivers: [
                SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 256.0,
                      mainAxisExtent: 256.0,
                      mainAxisSpacing: 4.0,
                      crossAxisSpacing: 4.0,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildListDelegate(_buildTiles()))
              ],
            )));
  }

  List<Widget> _buildTiles() {
    final trimLeft = RegExp(r'res://packs/[^/]*/');
    final imageExp =
        RegExp(r'\.png$|\.jpg$|\.jpeg$|\.webp$', caseSensitive: false);
    final textFileExp = RegExp(
        r'\.json$|\.txt|\.dungeondraft_tags$|'
        r'\.dungeondraft_tileset$|\.dungeondraft_wall',
        caseSensitive: false);
    if (_dungeondraftAssetDirectory == null) {
      return const <Widget>[GridTile(child: Text(emptyText))];
    }
    List<DungeondraftAssetFile> assetFiles = _dungeondraftAssetDirectory
        ?.getAssetFiles as List<DungeondraftAssetFile>;
    List<Widget> widgets = [];
    for (DungeondraftAssetFile assetFile in assetFiles) {
      for (DungeondraftAssetFileAsset asset in assetFile.getAssets) {
        if (!_searchPattern.hasMatch(asset.assetUri)) {
          continue;
        }
        if (imageExp.hasMatch(asset.assetUri)) {
          widgets.add(Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(border: Border.all()),
              child: Stack(children: [
                Image.memory(asset.parentFile.readImageFileSync(asset.assetUri),
                    width: 256.0,
                    height: 256.0,
                    semanticLabel: asset.assetUri,
                    alignment: Alignment.center),
                Text(asset.assetUri.replaceFirst(trimLeft, ''),
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.bold)),
              ])));
        } else if (textFileExp.hasMatch(asset.assetUri)) {
          /*widgets.add(
            Text(
                asset.parentFile
                    .readTextFileSync(asset.assetUri)
                    .replaceAll(RegExp(r'\t'), "  "),
                textAlign: TextAlign.left),
          );*/
          continue;
        } else {
          continue;
        }
      }
    }
    return widgets;
  }
}
