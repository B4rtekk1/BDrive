import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:serverapp/models/files_icons.dart';
import 'dart:io';
import 'package:serverapp/services/api_service.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:serverapp/models/file_item.dart';
import 'package:path/path.dart' as path;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

enum PopUpMenuOptions { delete, rename, copy, move }

class PopUpMenu extends StatelessWidget {
  final Function(PopUpMenuOptions) onSelected;

  const PopUpMenu({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PopUpMenuOptions>(
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<PopUpMenuOptions>>[
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.delete,
          child: Row(
            children: [
              Icon(Icons.delete),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.rename,
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.copy,
          child: Row(
            children: [Icon(Icons.copy), SizedBox(width: 8), Text('Copy')],
          ),
        ),
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.move,
          child: Row(
            children: [
              Icon(Icons.move_to_inbox),
              SizedBox(width: 8),
              Text('Move'),
            ],
          ),
        ),
      ],
    );
  }
}

class FilesExplorerPage extends StatefulWidget {
  final ApiService apiService;

  const FilesExplorerPage({super.key, required this.apiService});

  @override
  FilesExplorerPageState createState() => FilesExplorerPageState();
}

class FilesExplorerPageState extends State<FilesExplorerPage> {
  List<FileItem> files = [];
  String currentFolder = "";
  final Logger logger = Logger();
  bool isLoading = false;
  Map<String, double> downloadProgress = {};
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadFiles();
  }

  Future<void> _initializeAndLoadFiles() async {
    await widget.apiService.init();
    await _loadFiles();
  }

  bool isFolder(String path) => path.endsWith('/');

  Future<void> _loadFiles({String folderPath = ""}) async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final fileList = await widget.apiService.getFiles(folderPath: folderPath);
      if (!mounted) return;
      setState(() {
        files = fileList;
        currentFolder = folderPath;
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);

      setState(() {
        _uploadProgress = 0.0;
      });

      try {
        final message = await widget.apiService.uploadFile(
          file,
          currentFolder,
          onSendProgress: (sent, total) {
            if (mounted) {
              setState(() {
                _uploadProgress = sent / total;
              });
            }
          },
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Błąd wysyłania: $e")));
        }
      } finally {
        if (mounted) {
          setState(() {
            _uploadProgress = null;
          });
        }
      }

      await _loadFiles(folderPath: currentFolder);
    }
  }

  Future<String> _getDownloadsDirectoryPath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception("Nie można uzyskać folderu Pobrane");
      }
      return directory.path;
    } else if (Platform.isWindows) {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsPath = path.join(
        Platform.environment['USERPROFILE'] ?? directory.path,
        'Downloads',
      );
      return downloadsPath;
    } else {
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  void _downloadFile(String filename) async {
    setState(() => downloadProgress[filename] = 0.0);

    try {
      String fileName = filename.split('/').last;
      String extension = path.extension(fileName).toLowerCase();

      if (extension.isEmpty) {
        final inferred = await _inferExtension(filename);
        extension = inferred['extension'] ?? '';
        if (extension.isNotEmpty) {
          fileName = '$fileName$extension';
        }
      }

      if (Platform.isAndroid && !await _requestStoragePermissions()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Brak uprawnień do zapisu pliku. Przyznaj uprawnienia w ustawieniach."),
              action: SnackBarAction(
                label: 'Ustawienia',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final response = await widget.apiService.downloadFileAsBytes(
        filename,
        onProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => downloadProgress[filename] = received / total);
          }
        },
      );

      final downloadsPath = await _getDownloadsDirectoryPath();
      final savePath = path.join(downloadsPath, fileName);

      final directory = Directory(downloadsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File(savePath);
      await file.writeAsBytes(response);

      if (await file.exists() && await file.length() > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Pobrano: $fileName do folderu Pobrane")),
        );
        final openResult = await OpenFile.open(savePath);
        if (openResult.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Nie można otworzyć pliku: ${openResult.message}")),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Plik $fileName nie został zapisany lub jest pusty")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Błąd pobierania: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => downloadProgress.remove(filename));
    }
  }

  Future<Map<String, String>> _inferExtension(String filename) async {
    try {
      final baseUrl = dotenv.env["BASE_URL"] ?? "";
      if (baseUrl.isEmpty) {
        logger.e("BASE_URL nie jest zdefiniowane w pliku .env");
        return {'extension': '', 'mimeType': ''};
      }

      final response = await widget.apiService.dio.head("$baseUrl/download/$filename");
      final contentType = response.headers.value('content-type')?.toLowerCase();

      const mimeToExtension = {
        'application/pdf': {'extension': '.pdf', 'mimeType': 'application/pdf'},
        'image/jpeg': {'extension': '.jpg', 'mimeType': 'image/jpeg'},
        'image/png': {'extension': '.png', 'mimeType': 'image/png'},
        'image/gif': {'extension': '.gif', 'mimeType': 'image/gif'},
        'text/plain': {'extension': '.txt', 'mimeType': 'text/plain'},
        'application/msword': {'extension': '.doc', 'mimeType': 'application/msword'},
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document': {
          'extension': '.docx',
          'mimeType': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        },
        'application/json': {'extension': '.json', 'mimeType': 'application/json'},
        'application/zip': {'extension': '.zip', 'mimeType': 'application/zip'},
        'video/mp4': {'extension': '.mp4', 'mimeType': 'video/mp4'},
        'audio/mpeg': {'extension': '.mp3', 'mimeType': 'audio/mpeg'},
        'application/octet-stream': {'extension': '', 'mimeType': 'application/octet-stream'},
      };

      final mimeData = mimeToExtension[contentType];
      if (mimeData != null && mimeData['extension']!.isNotEmpty) {
        return mimeData;
      }

      final fileExtension = path.extension(filename).toLowerCase();
      if (fileExtension.isNotEmpty) {
        final matchingMime = mimeToExtension.entries.firstWhere(
          (entry) => entry.value['extension'] == fileExtension,
          orElse: () => MapEntry('application/octet-stream', {'extension': fileExtension, 'mimeType': 'application/octet-stream'}),
        );
        return matchingMime.value;
      }

      return {'extension': '', 'mimeType': 'application/octet-stream'};
    } catch (e) {
      logger.e("Błąd podczas wnioskowania rozszerzenia: $e");
      return {'extension': '', 'mimeType': 'application/octet-stream'};
    }
  }

  Future<bool> _requestStoragePermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Wymagane jest uprawnienie do zarządzania pamięcią zewnętrzną."),
                action: SnackBarAction(
                  label: 'Ustawienia',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return false;
        }
        return true;
      } else {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Wymagane jest uprawnienie do pamięci."),
                action: SnackBarAction(
                  label: 'Ustawienia',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return false;
        }
        return true;
      }
    }
    return true;
  }

  void _dowFile(String path) {
    if (!isFolder(path)) _downloadFile(path);
  }

  void _handleTap(String path) {
    if (isFolder(path)) {
      _loadFiles(folderPath: path);
    } else {
      _dowFile(path);
    }
  }

  void _handleMenuSelection(String path, PopUpMenuOptions option) async {
    switch (option) {
      case PopUpMenuOptions.delete:
        try {
          final message = await widget.apiService.deleteFile(path);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          await _loadFiles(folderPath: currentFolder);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Błąd usuwania: $e")),
          );
        }
        break;
      case PopUpMenuOptions.rename:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rename $path - nie zaimplementowane")),
        );
        break;
      case PopUpMenuOptions.copy:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Copy $path - nie zaimplementowane")),
        );
        break;
      case PopUpMenuOptions.move:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Move $path - nie zaimplementowane")),
        );
        break;
    }
  }

  Widget _getIcon(String path, [bool isImage = false, bool fullSize = false]) {
    final double size = fullSize ? 64 : 24;
    if (isFolder(path)) return Filesicons.getIconForExtension("folder", size);

    final extension = path.split('.').last.toLowerCase();
    if (isImage && ["jpg", "jpeg", "png", "gif"].contains(extension)) {
      final baseUrl = dotenv.env["BASE_URL"] ?? "";
      final imageUrl = "$baseUrl/download/$path";
      final token = widget.apiService.dio.options.headers["Authorization"] as String? ?? "";
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        headers: {
          "X-Api-Key": widget.apiService.apiKey,
          "X-Device-Id": widget.apiService.dio.options.headers["X-Device-Id"] as String? ?? "",
          "Authorization": token,
        },
        loadingBuilder: (context, child, loadingProgress) {
          return loadingProgress == null
              ? child
              : const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          logger.e("Błąd ładowania obrazu: $error");
          return Filesicons.getIconForExtension(extension, size);
        },
      );
    }
    return Filesicons.getIconForExtension(extension, size);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (currentFolder.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      final parentFolder = currentFolder.endsWith('/')
                          ? currentFolder
                              .substring(0, currentFolder.length - 1)
                              .split('/')
                              .reversed
                              .skip(1)
                              .toList()
                              .reversed
                              .join('/')
                          : currentFolder
                              .split('/')
                              .reversed
                              .skip(1)
                              .toList()
                              .reversed
                              .join('/');
                      _loadFiles(folderPath: parentFolder);
                    },
                  ),
                Expanded(
                  child: Text(
                    currentFolder.isEmpty ? "My drive" : currentFolder,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _uploadFile,
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          String normalizedPath = file.path.replaceAll('\\', '/');
                          String displayName = normalizedPath.endsWith('/')
                              ? normalizedPath
                                  .substring(0, normalizedPath.length - 1)
                                  .split('/')
                                  .last
                              : normalizedPath.split("/").last;

                          return GestureDetector(
                            onTap: () => _handleTap(file.path),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Card(
                                elevation: 2,
                                child: Stack(
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4.0,
                                                left: 4.0,
                                                top: 4.0,
                                              ),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: _getIcon(file.path),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4.0,
                                                ),
                                                child: Text(
                                                  displayName,
                                                  textAlign: TextAlign.left,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            PopUpMenu(
                                              onSelected: (option) =>
                                                  _handleMenuSelection(
                                                file.path,
                                                option,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child: _getIcon(file.path, true, true),
                                            ),
                                          ),
                                        ),
                                        if (downloadProgress.containsKey(file.path))
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Column(
                                              children: [
                                                LinearProgressIndicator(
                                                  value: downloadProgress[file.path],
                                                  minHeight: 4,
                                                  backgroundColor: Colors.grey[300],
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                              Color>(
                                                          Colors.blue),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${(downloadProgress[file.path]! * 100).toStringAsFixed(1)}%',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_uploadProgress != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Uploading: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(_uploadProgress! * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}