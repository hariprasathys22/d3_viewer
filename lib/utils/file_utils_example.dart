// Example: How the gzip support works internally
// 
// This is a reference showing how the FileUtils class handles different scenarios.
// You don't need to use this file directly - it's just for documentation.

import 'dart:io';
import 'package:d3_viewer/utils/file_utils.dart';

void main() async {
  // Example 1: Reading a file that might be compressed
  // ===================================================
  // FileUtils automatically tries both normal and .gz versions
  
  try {
    // This will work if either 'points' or 'points.gz' exists
    final bytes = await FileUtils.readFileBytes('path/to/polyMesh/points');
    print('Successfully read ${bytes.length} bytes');
    
    // FileUtils handles these scenarios automatically:
    // 1. If 'points' exists and is not compressed → returns raw bytes
    // 2. If 'points' exists and IS compressed → detects magic bytes and decompresses
    // 3. If 'points' doesn't exist but 'points.gz' exists → decompresses
    // 4. If neither exists → throws FileSystemException
    
  } catch (e) {
    print('Error reading file: $e');
  }
  
  // Example 2: Reading a file as string
  // ====================================
  try {
    final content = await FileUtils.readFileAsString('path/to/polyMesh/boundary');
    print('Boundary file content length: ${content.length}');
    
    // Works for both 'boundary' and 'boundary.gz'
    
  } catch (e) {
    print('Error: $e');
  }
  
  // Example 3: Checking if file exists
  // ===================================
  final exists = await FileUtils.fileExists('path/to/polyMesh/points');
  if (exists) {
    print('Points file exists (either normal or .gz)');
  }
  
  // Example 4: Getting actual file path
  // ====================================
  final actualPath = await FileUtils.getActualFilePath('path/to/polyMesh/points');
  if (actualPath != null) {
    print('Actual file path: $actualPath');
    // Will be either 'path/to/polyMesh/points' or 'path/to/polyMesh/points.gz'
  }
  
  // Example 5: Listing files in a directory
  // ========================================
  final fields = await FileUtils.listFiles('path/to/case/0');
  print('Available fields: $fields');
  // Output: [U, p, T, k, omega, nut]
  // Even if actual files are U.gz, p.gz, T.gz, k.gz, omega.gz, nut.gz
  
  // Example 6: How it works in mesh reading
  // ========================================
  // Before (without gzip support):
  // final pointsFile = File('path/points');
  // final bytes = await pointsFile.readAsBytes();
  
  // After (with gzip support):
  // final bytes = await FileUtils.readFileBytes('path/points');
  // ✓ Works for both 'path/points' and 'path/points.gz'
  
  // Example 7: Mixed compression scenario
  // ======================================
  // Your case can have:
  // - points.gz (compressed)
  // - faces (normal)
  // - owner.gz (compressed)
  // - neighbour (normal)
  // All will be read correctly!
}

// Example showing magic byte detection
void demonstrateMagicByteDetection() {
  // Gzip files always start with these two bytes
  final gzipMagicBytes = [0x1f, 0x8b];
  
  // Example gzipped file bytes
  final compressedData = [0x1f, 0x8b, 0x08, 0x00, /* ... more bytes ... */];
  
  // FileUtils._isGzipped() checks for these magic bytes
  final isGzipped = compressedData[0] == 0x1f && compressedData[1] == 0x8b;
  print('Is gzipped: $isGzipped'); // true
  
  // This allows detection even if file doesn't have .gz extension
}

// Example showing the complete flow
void completeFlowExample() async {
  // When you read a mesh:
  // 
  // 1. MeshReader.readMesh() is called
  // 2. It uses FileUtils.readFileBytes('path/points')
  // 3. FileUtils checks:
  //    a. Does 'path/points' exist?
  //       - Yes: Read it, check magic bytes, decompress if needed
  //       - No: Try step b
  //    b. Does 'path/points.gz' exist?
  //       - Yes: Read and decompress
  //       - No: Throw error
  // 4. Return decompressed bytes
  // 5. MeshReader parses the bytes (same as before)
  //
  // Result: Transparent gzip support with zero code changes in MeshReader!
}

// Error handling example
void errorHandlingExample() async {
  try {
    await FileUtils.readFileBytes('path/to/nonexistent/file');
  } on FileSystemException catch (e) {
    print('Error message: ${e.message}');
    // Output: File not found: path/to/nonexistent/file (also tried path/to/nonexistent/file.gz)
    print('Path: ${e.path}');
    // Output: path/to/nonexistent/file
  }
}
