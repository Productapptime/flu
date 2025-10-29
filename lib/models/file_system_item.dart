// lib/models/file_system_item.dart
abstract class FileSystemItem {
  final String id;
  String name;
  DateTime? lastOpened;
  bool isFavorite;
  String? parentFolderId;
  
  FileSystemItem({
    required this.id,
    required this.name,
    this.lastOpened,
    this.isFavorite = false,
    this.parentFolderId,
  });

  // ✅ Ortak metodlar
  String get displayName => name;
  DateTime get sortDate => lastOpened ?? DateTime(0);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileSystemItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
