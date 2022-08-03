import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_treeview/flutter_treeview.dart';

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
      home: const HomePage(title: 'Dungeondraft Asset Explorer'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

const String emptyTreeText = 'Select a directory to view';

class _HomePageState extends State<HomePage> {
  TreeViewController _treeViewController = TreeViewController(
      children: [const Node(key: emptyTreeText, label: emptyTreeText)],
      selectedKey: emptyTreeText);

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
    Node<DungeondraftAssetDirectory> rootNode =
        await ddAssetDirectory.getTree();

    setState(() {
      _treeViewController =
          TreeViewController(children: [rootNode], selectedKey: rootNode.key);
    });
  }

  void _expandAll() {
    setState(() {
      _treeViewController = _treeViewController.copyWith(
          children: _treeViewController.expandAll());
    });
  }

  void _collapseAll() {
    _treeViewController.collapseAll();
  }

  Widget treeNodeBuilder(BuildContext context, Node node) {
    const TextStyle boldStyle = TextStyle(fontWeight: FontWeight.bold);
    if (node.data is DungeondraftAssetFileAsset) {
      DungeondraftAssetFileAsset asset =
          node.data as DungeondraftAssetFileAsset;
      RegExp imageExp =
          RegExp(r'\.png$|\.jpg$|\.jpeg$|\.webp$', caseSensitive: false);
      RegExp textFileExp = RegExp(
          r'\.json$|\.txt|\.dungeondraft_tags$|\.dungeondraft_tileset$|\.dungeondraft_wall',
          caseSensitive: false);
      if (imageExp.hasMatch(asset.assetUri)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.label, textAlign: TextAlign.left, style: boldStyle),
            Image.memory(asset.parentFile.readImageFileSync(asset.assetUri),
                width: 256.0,
                height: 256.0,
                semanticLabel: asset.assetUri,
                alignment: Alignment.centerLeft),
          ],
        );
      } else if (textFileExp.hasMatch(asset.assetUri)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.label, textAlign: TextAlign.left, style: boldStyle),
            Text(
                asset.parentFile
                    .readTextFileSync(asset.assetUri)
                    .replaceAll(RegExp(r'\t'), "  "),
                textAlign: TextAlign.left),
          ],
        );
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(node.label, textAlign: TextAlign.left, style: boldStyle)
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final TreeViewTheme treeViewTheme = TreeViewTheme(
      dense: false,
      expanderTheme: const ExpanderThemeData(size: 20, color: Colors.blue),
      labelStyle: const TextStyle(
        fontSize: 16,
        letterSpacing: 0.3,
      ),
      parentLabelStyle: TextStyle(
        fontSize: 16,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w800,
        color: Colors.blue.shade700,
      ),
      iconTheme: IconThemeData(
        size: 18,
        color: Colors.grey.shade800,
      ),
      colorScheme: Theme.of(context).colorScheme,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        FloatingActionButton(
            onPressed: _openAssetDirectory,
            tooltip: 'Open Dungeondraft assets directory',
            child: const Icon(Icons.add)),
        FloatingActionButton(
            onPressed: _expandAll,
            tooltip: 'Expand the whole asset tree',
            child: const Icon(Icons.expand)),
        FloatingActionButton(
            onPressed: _collapseAll,
            tooltip: 'Collapse the whole asset tree',
            child: const Icon(Icons.expand_less)),
      ]),
      body: Align(
          alignment: Alignment.centerLeft,
          child: TreeView(
            controller: _treeViewController,
            nodeBuilder: treeNodeBuilder,
            theme: treeViewTheme,
          )),
    );
  }
}
