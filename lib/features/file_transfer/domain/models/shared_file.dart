class SharedFile {
  final String fileId;
  final String fileName;
  final String filePath; // Path on the host device
  final int fileSize;
  final String fileType;
  final String checksum; // SHA-256
  final int uploadedAt;

  SharedFile({
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileType,
    required this.checksum,
    required this.uploadedAt,
  });

  String get category {
    final extension = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return 'Images';
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
      return 'Videos';
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'flac'].contains(extension)) {
      return 'Audio';
    } else if (['apk'].contains(extension)) {
      return 'APKs';
    } else if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(extension)) {
      return 'Documents';
    } else {
      return 'Other';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'fileType': fileType,
      'checksum': checksum,
      'uploadedAt': uploadedAt,
    };
  }

  factory SharedFile.fromMap(Map<String, dynamic> map) {
    return SharedFile(
      fileId: map['fileId'] ?? '',
      fileName: map['fileName'] ?? '',
      filePath: map['filePath'] ?? '',
      fileSize: map['fileSize']?.toInt() ?? 0,
      fileType: map['fileType'] ?? '',
      checksum: map['checksum'] ?? '',
      uploadedAt: map['uploadedAt']?.toInt() ?? 0,
    );
  }
}
