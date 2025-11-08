// test/file_utils_test.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:d3_viewer/utils/file_utils.dart';

void main() {
  late Directory testDir;

  setUp(() async {
    // Create a temporary test directory
    testDir = await Directory.systemTemp.createTemp('foam_test_');
  });

  tearDown(() async {
    // Clean up test directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('FileUtils', () {
    test('readFileBytes - reads normal file', () async {
      // Create a normal text file
      final testFile = File('${testDir.path}/test.txt');
      await testFile.writeAsString('Hello OpenFOAM');

      // Read it
      final bytes = await FileUtils.readFileBytes(testFile.path);
      final content = utf8.decode(bytes);

      expect(content, equals('Hello OpenFOAM'));
    });

    test('readFileBytes - reads .gz file', () async {
      // Create a compressed file
      final originalContent = 'This is compressed OpenFOAM data';
      final compressed = gzip.encode(utf8.encode(originalContent));
      
      final testFile = File('${testDir.path}/test.txt.gz');
      await testFile.writeAsBytes(compressed);

      // Read it (should automatically decompress)
      final bytes = await FileUtils.readFileBytes('${testDir.path}/test.txt');
      final content = utf8.decode(bytes);

      expect(content, equals(originalContent));
    });

    test('readFileBytes - reads file without .gz extension but is compressed', () async {
      // Create a compressed file WITHOUT .gz extension
      final originalContent = 'Compressed but no extension';
      final compressed = gzip.encode(utf8.encode(originalContent));
      
      final testFile = File('${testDir.path}/compressed_no_ext');
      await testFile.writeAsBytes(compressed);

      // Read it (should detect and decompress)
      final bytes = await FileUtils.readFileBytes(testFile.path);
      final content = utf8.decode(bytes);

      expect(content, equals(originalContent));
    });

    test('readFileBytes - throws error when file not found', () async {
      expect(
        () => FileUtils.readFileBytes('${testDir.path}/nonexistent.txt'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('readFileAsString - reads normal file as string', () async {
      final testFile = File('${testDir.path}/string_test.txt');
      await testFile.writeAsString('OpenFOAM string content');

      final content = await FileUtils.readFileAsString(testFile.path);

      expect(content, equals('OpenFOAM string content'));
    });

    test('readFileAsString - reads .gz file as string', () async {
      final originalContent = 'Compressed string content';
      final compressed = gzip.encode(utf8.encode(originalContent));
      
      final testFile = File('${testDir.path}/string_test.txt.gz');
      await testFile.writeAsBytes(compressed);

      final content = await FileUtils.readFileAsString('${testDir.path}/string_test.txt');

      expect(content, equals(originalContent));
    });

    test('fileExists - returns true for normal file', () async {
      final testFile = File('${testDir.path}/exists_test.txt');
      await testFile.writeAsString('test');

      final exists = await FileUtils.fileExists(testFile.path);

      expect(exists, isTrue);
    });

    test('fileExists - returns true for .gz file', () async {
      final testFile = File('${testDir.path}/exists_test.txt.gz');
      await testFile.writeAsString('test');

      final exists = await FileUtils.fileExists('${testDir.path}/exists_test.txt');

      expect(exists, isTrue);
    });

    test('fileExists - returns false when neither exists', () async {
      final exists = await FileUtils.fileExists('${testDir.path}/nonexistent.txt');

      expect(exists, isFalse);
    });

    test('getActualFilePath - returns normal file path', () async {
      final testFile = File('${testDir.path}/actual_test.txt');
      await testFile.writeAsString('test');

      final actualPath = await FileUtils.getActualFilePath(testFile.path);

      expect(actualPath, equals(testFile.path));
    });

    test('getActualFilePath - returns .gz file path', () async {
      final gzFile = File('${testDir.path}/actual_test.txt.gz');
      await gzFile.writeAsString('test');

      final actualPath = await FileUtils.getActualFilePath('${testDir.path}/actual_test.txt');

      expect(actualPath, equals(gzFile.path));
    });

    test('getActualFilePath - returns null when neither exists', () async {
      final actualPath = await FileUtils.getActualFilePath('${testDir.path}/nonexistent.txt');

      expect(actualPath, isNull);
    });

    test('listFiles - lists normal files', () async {
      await File('${testDir.path}/file1.txt').writeAsString('1');
      await File('${testDir.path}/file2.txt').writeAsString('2');
      await File('${testDir.path}/file3.txt').writeAsString('3');

      final files = await FileUtils.listFiles(testDir.path);

      expect(files.length, equals(3));
      expect(files, contains('file1.txt'));
      expect(files, contains('file2.txt'));
      expect(files, contains('file3.txt'));
    });

    test('listFiles - lists .gz files without extension', () async {
      await File('${testDir.path}/file1.gz').writeAsString('1');
      await File('${testDir.path}/file2.gz').writeAsString('2');
      await File('${testDir.path}/file3.gz').writeAsString('3');

      final files = await FileUtils.listFiles(testDir.path);

      expect(files.length, equals(3));
      expect(files, contains('file1'));
      expect(files, contains('file2'));
      expect(files, contains('file3'));
      expect(files, isNot(contains('file1.gz')));
    });

    test('listFiles - handles mixed normal and .gz files', () async {
      await File('${testDir.path}/normal.txt').writeAsString('n');
      await File('${testDir.path}/compressed.gz').writeAsString('c');
      await File('${testDir.path}/another.dat').writeAsString('a');

      final files = await FileUtils.listFiles(testDir.path);

      expect(files.length, equals(3));
      expect(files, contains('normal.txt'));
      expect(files, contains('compressed')); // without .gz
      expect(files, contains('another.dat'));
    });

    test('listFiles - returns empty list for non-existent directory', () async {
      final files = await FileUtils.listFiles('${testDir.path}/nonexistent');

      expect(files, isEmpty);
    });

    test('listFiles - returns sorted list', () async {
      await File('${testDir.path}/zebra.txt').writeAsString('z');
      await File('${testDir.path}/apple.txt').writeAsString('a');
      await File('${testDir.path}/banana.txt').writeAsString('b');

      final files = await FileUtils.listFiles(testDir.path);

      expect(files[0], equals('apple.txt'));
      expect(files[1], equals('banana.txt'));
      expect(files[2], equals('zebra.txt'));
    });

    test('Simulated OpenFOAM mesh reading - compressed points', () async {
      // Simulate OpenFOAM points file content
      final foamContent = '''
FoamFile
{
    version     2.0;
    format      ascii;
    class       vectorField;
    object      points;
}

3
(
(0 0 0)
(1 0 0)
(0 1 0)
)
''';

      // Create compressed points.gz file
      final compressed = gzip.encode(utf8.encode(foamContent));
      await File('${testDir.path}/points.gz').writeAsBytes(compressed);

      // Read it as if it's a normal file
      final content = await FileUtils.readFileAsString('${testDir.path}/points');

      expect(content, contains('FoamFile'));
      expect(content, contains('vectorField'));
      expect(content, contains('(0 0 0)'));
    });

    test('Simulated OpenFOAM field reading - compressed U field', () async {
      // Simulate OpenFOAM velocity field
      final fieldContent = '''
FoamFile
{
    version     2.0;
    format      ascii;
    class       volVectorField;
    object      U;
}

dimensions [0 1 -1 0 0 0 0];

internalField uniform (1 0 0);
''';

      // Create compressed U.gz file
      final compressed = gzip.encode(utf8.encode(fieldContent));
      await File('${testDir.path}/U.gz').writeAsBytes(compressed);

      // Read it
      final content = await FileUtils.readFileAsString('${testDir.path}/U');

      expect(content, contains('volVectorField'));
      expect(content, contains('uniform (1 0 0)'));
    });

    test('Mixed case - some files compressed, some not', () async {
      // Normal points file
      await File('${testDir.path}/points').writeAsString('points content');
      
      // Compressed faces file
      final facesCompressed = gzip.encode(utf8.encode('faces content'));
      await File('${testDir.path}/faces.gz').writeAsBytes(facesCompressed);
      
      // Normal owner file
      await File('${testDir.path}/owner').writeAsString('owner content');

      // Read all files
      final pointsContent = await FileUtils.readFileAsString('${testDir.path}/points');
      final facesContent = await FileUtils.readFileAsString('${testDir.path}/faces');
      final ownerContent = await FileUtils.readFileAsString('${testDir.path}/owner');

      expect(pointsContent, equals('points content'));
      expect(facesContent, equals('faces content'));
      expect(ownerContent, equals('owner content'));
    });
  });
}
