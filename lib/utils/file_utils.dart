// lib/utils/file_utils.dart

import 'dart:io';
import 'dart:convert';

/// Utility class for reading OpenFOAM files that may be compressed with gzip
class FileUtils {
  /// Reads a file that may exist as either 'filename' or 'filename.gz'
  /// Returns the file content as bytes
  static Future<List<int>> readFileBytes(String path) async {
    File file = File(path);
    
    // First try to read the file as-is
    if (await file.exists()) {
      print('Reading file: $path');
      final bytes = await file.readAsBytes();
      
      // Check if it's already gzipped (even without .gz extension)
      if (_isGzipped(bytes)) {
        print('  → Detected gzip compression, decompressing...');
        return gzip.decode(bytes);
      }
      
      return bytes;
    }
    
    // If file doesn't exist, try with .gz extension
    final gzPath = '$path.gz';
    file = File(gzPath);
    
    if (await file.exists()) {
      print('Reading compressed file: $gzPath');
      final compressedBytes = await file.readAsBytes();
      
      // Decompress the gzipped file
      print('  → Decompressing gzip file...');
      return gzip.decode(compressedBytes);
    }
    
    // Neither file exists
    throw FileSystemException(
      'File not found: $path (also tried $gzPath)',
      path,
    );
  }
  
  /// Reads a file as a string (decompresses if needed)
  static Future<String> readFileAsString(String path) async {
    final bytes = await readFileBytes(path);
    return utf8.decode(bytes, allowMalformed: true);
  }
  
  /// Checks if a file exists (including checking for .gz variant)
  static Future<bool> fileExists(String path) async {
    if (await File(path).exists()) {
      return true;
    }
    return await File('$path.gz').exists();
  }
  
  /// Gets the actual file path (returns .gz path if that's what exists)
  static Future<String?> getActualFilePath(String path) async {
    if (await File(path).exists()) {
      return path;
    }
    
    final gzPath = '$path.gz';
    if (await File(gzPath).exists()) {
      return gzPath;
    }
    
    return null;
  }
  
  /// Checks if bytes represent gzip-compressed data
  /// Gzip files start with magic bytes: 0x1f 0x8b
  static bool _isGzipped(List<int> bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0x1f && bytes[1] == 0x8b;
  }
  
  /// Lists all files in a directory, automatically handling .gz files
  /// Returns the base filenames (without .gz extension)
  static Future<List<String>> listFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    
    if (!await directory.exists()) {
      return [];
    }
    
    final files = <String>{};
    
    await for (final entity in directory.list()) {
      if (entity is File) {
        String name = entity.path.split(Platform.pathSeparator).last;
        
        // If it's a .gz file, store without the .gz extension
        if (name.endsWith('.gz')) {
          name = name.substring(0, name.length - 3);
        }
        
        files.add(name);
      }
    }
    
    return files.toList()..sort();
  }
}
