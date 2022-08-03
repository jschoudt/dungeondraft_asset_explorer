import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_treeview/flutter_treeview.dart';
// Header info from: https://github.com/Wcubed/dungeondraft-asset-tools#reading-dungeondraft-pack-files
// Classes for dungeon draft asst pack files in a directory
// - asset file
// -

class DungeondraftAssetFileAsset {
  DungeondraftAssetFile parentFile;
  String packId;
  String assetUri;
  int offset;
  int length;
  Uint8List md5;

  DungeondraftAssetFileAsset(this.parentFile, this.packId, this.assetUri,
      this.offset, this.length, this.md5);
}

class DungeondraftAssetFile {
  final String _filePath;
  String _packId = '';
  final List<DungeondraftAssetFileAsset> _assets = [];

  DungeondraftAssetFile(this._filePath);

  Future<int> _getNextInt32(RandomAccessFile file) async {
    final Uint8List bytes = await file.read(4);
    return bytes.buffer.asByteData(0, 4).getInt32(0, Endian.little);
  }

  Future<int> _getNextInt64(RandomAccessFile file) async {
    final Uint8List bytes = await file.read(8);
    return bytes.buffer.asByteData(0, 8).getInt64(0, Endian.little);
  }

  Future<List<int>> _getNextInts(RandomAccessFile file, int count) async {
    final List<int> ints = [];
    for (var i = 0; i < count; i++) {
      ints.add(await _getNextInt32(file));
    }
    return ints;
  }

  Future<String> _getString(RandomAccessFile file, int len) async {
    final Uint8List bytes = await file.read(len);
    return String.fromCharCodes(bytes);
  }

  DungeondraftAssetFileAsset _getAssetFromUri(String assetUri) {
    return _assets.firstWhere((asset) => asset.assetUri == assetUri);
  }

  Future<Uint8List> _getAssetBytes(String assetUri) async {
    DungeondraftAssetFileAsset asset = _getAssetFromUri(assetUri);
    Uri assetFileUri = Uri.parse(_filePath);
    File assetFile = File.fromUri(assetFileUri);
    final openAssetFile = await assetFile.open(mode: FileMode.read);
    await openAssetFile.setPosition(asset.offset);
    Uint8List bytes = await openAssetFile.read(asset.length);
    await openAssetFile.close();
    return bytes;
  }

  Uint8List _getAssetBytesSync(String assetUri) {
    DungeondraftAssetFileAsset asset = _getAssetFromUri(assetUri);
    Uri assetFileUri = Uri.parse(_filePath);
    File assetFile = File.fromUri(assetFileUri);
    final openAssetFile = assetFile.openSync(mode: FileMode.read);
    openAssetFile.setPositionSync(asset.offset);
    Uint8List bytes = openAssetFile.readSync(asset.length);
    openAssetFile.closeSync();
    return bytes;
  }

  List<String> getAssetUriList() {
    return _assets.map((asset) => asset.assetUri).toList();
  }

  List<DungeondraftAssetFileAsset> get getAssets {
    return _assets;
  }

  Future<String> readTextFile(String assetUri) async {
    return String.fromCharCodes(await _getAssetBytes(assetUri));
  }

  String readTextFileSync(String assetUri) {
    return String.fromCharCodes(_getAssetBytesSync(assetUri));
  }

  Future<Uint8List> readImageFile(String assetUri) async {
    return await _getAssetBytes(assetUri);
  }

  Uint8List readImageFileSync(String assetUri) {
    return _getAssetBytesSync(assetUri);
  }

  Future<void> readHeaders() async {
    Uri assetFileUri = Uri.parse(_filePath);
    File assetFile = File.fromUri(assetFileUri);
    final openAssetFile = await assetFile.open(mode: FileMode.read);
    // TODO Test the magic number to make sure this is a valid file
    final int magicNumber = await _getNextInt32(openAssetFile);
    // TODO Check that the version is one we support.
    final List<int> version = await _getNextInts(openAssetFile, 4);
    // The file format says this is just zeroes
    await _getNextInts(openAssetFile, 16);
    final int numFiles = await _getNextInt32(openAssetFile);
    int fileNum = 0;
    while (fileNum < numFiles) {
      int pathLen = await _getNextInt32(openAssetFile);
      String pathString = await _getString(openAssetFile, pathLen);
      int assetOffset = await _getNextInt64(openAssetFile);
      int assetSize = await _getNextInt64(openAssetFile);
      Uint8List md5 = await openAssetFile.read(16);
      _assets.add(DungeondraftAssetFileAsset(
          this, _packId, pathString, assetOffset, assetSize, md5));
      fileNum++;
    }
    // assumes that the pack JSON is the first file. We should check
    // this and make sure.
    String packJsonString = await readTextFile(_assets[0].assetUri);
    var packJson = jsonDecode(packJsonString);
    _packId = packJson['id'];
    await openAssetFile.close();
  }
}

class DungeondraftAssetDirectory {
  final String _assetDirectoryPath;
  final List<DungeondraftAssetFile> _assetFiles = [];

  DungeondraftAssetDirectory(this._assetDirectoryPath);

  Future<void> loadAssetDirectory() async {
    Future<DungeondraftAssetFile> loadAssetFileMetadata(File file) async {
      final DungeondraftAssetFile assetFile = DungeondraftAssetFile(file.path);
      await assetFile.readHeaders();
      return assetFile;
    }

    final dir = Directory(_assetDirectoryPath);
    final List<File> packFiles = (await dir.list(followLinks: true).toList())
        .whereType<File>()
        .where((file) => file.path.endsWith('dungeondraft_pack'))
        .toList();
    for (File file in packFiles) {
      _assetFiles.add(await loadAssetFileMetadata(file));
    }
  }

  Future<Node<DungeondraftAssetDirectory>> getTree() async {
    List<Node<DungeondraftAssetFile>> assetFileNodes = [];
    for (DungeondraftAssetFile assetFile in _assetFiles) {
      List<Node<DungeondraftAssetFileAsset>> assetNodes = [];
      for (DungeondraftAssetFileAsset asset in assetFile.getAssets) {
        assetNodes.add(Node(
            key: (asset.packId + asset.assetUri),
            label: asset.assetUri,
            data: asset));
      }
      assetFileNodes.add(Node(
          key: assetFile._packId,
          label:
              '${assetFile._filePath} (${assetFile.getAssets.length.toString()})',
          data: assetFile,
          children: assetNodes));
    }
    return Node(
        key: _assetDirectoryPath,
        label: ('$_assetDirectoryPath (${_assetFiles.length.toString()})'),
        data: this,
        expanded: true,
        children: assetFileNodes);
  }

  List<DungeondraftAssetFile> get getAssetFiles {
    return _assetFiles;
  }

  String get getAssetDirectoryPath {
    return _assetDirectoryPath;
  }
}
