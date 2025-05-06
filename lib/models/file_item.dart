class FileItem {
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? lastModified;

  FileItem({
    required this.path,
    required this.isDirectory,
    this.size,
    this.lastModified,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final isDirectory = type == 'directory';

    return FileItem(
      path: json['path'] as String? ?? '',
      isDirectory: isDirectory,
      size: json['size'] as int?,
      lastModified: json['modified'] != null
          ? DateTime.tryParse(json['modified'] as String)
          : null,
    );
  }
}