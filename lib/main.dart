// lib/main.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'readers/case_reader.dart';
import 'models/openfoam_case.dart';
import 'widgets/foam_viewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenFOAM Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const OpenFOAMViewerPage(),
    );
  }
}

class OpenFOAMViewerPage extends StatefulWidget {
  const OpenFOAMViewerPage({super.key});

  @override
  State<OpenFOAMViewerPage> createState() => _OpenFOAMViewerPageState();
}

class _OpenFOAMViewerPageState extends State<OpenFOAMViewerPage> {
  OpenFOAMCase? _foamCase;
  bool _isLoading = false;
  String? _error;
  Map<String, String> _fileFormats = {};
  String? _selectedTimeStep;
  String? _selectedField;
  List<String> _availableFields = [];
  FieldData? _currentFieldData;
  String? _casePath;

  // Visibility controls
  bool _showInternalMesh = true;
  Map<String, bool> _boundaryVisibility = {};

  @override
  void initState() {
    super.initState();
    // Don't auto-load, wait for user to pick folder
  }

  Future<void> _pickCaseFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      _casePath = selectedDirectory;
      await _loadCase();
    }
  }

  Future<void> _loadCase() async {
    if (_casePath == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get file formats first
      final formats = await CaseReader.getFileFormats(_casePath!);

      // Try to find .foam file or use case path directly
      String foamFilePath = '$_casePath/para.foam';
      // Read the case
      final foamCase = await CaseReader.readCase(foamFilePath);

      print('=== OpenFOAM Case Loaded ===');
      print('Case path: ${foamCase.casePath}');
      print('Points: ${foamCase.mesh.points.length}');
      print('Faces: ${foamCase.mesh.faces.length}');
      print('Owner: ${foamCase.mesh.owner.length}');
      print('Neighbour: ${foamCase.mesh.neighbour.length}');
      print('Boundaries: ${foamCase.mesh.boundaries.keys}');
      print('Boundary details:');
      foamCase.mesh.boundaries.forEach((name, boundary) {
        print(
          '  $name: type=${boundary.type}, nFaces=${boundary.nFaces}, startFace=${boundary.startFace}',
        );
      });

      // Set default time step
      String? initialTime;
      if (foamCase.timeDirectories.isNotEmpty) {
        initialTime = foamCase.timeDirectories.first;
      }

      // Load fields for the first time step
      List<String> fields = [];
      if (initialTime != null) {
        fields = await CaseReader.getAvailableFields(
          foamCase.casePath,
          initialTime,
        );
        print('Available fields in $initialTime: $fields');
      }

      setState(() {
        _foamCase = foamCase;
        _fileFormats = formats;
        _selectedTimeStep = initialTime;
        _availableFields = fields;
        _selectedField = fields.isNotEmpty ? fields.first : null;
        _isLoading = false;

        // Initialize boundary visibility - all visible by default
        _boundaryVisibility = {
          for (var boundary in foamCase.mesh.boundaries.keys) boundary: true,
        };
      });

      // Load the first field data
      if (_selectedField != null && initialTime != null) {
        await _loadFieldData();
      }
    } catch (e, stackTrace) {
      print('Error reading OpenFOAM case: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onTimeStepChanged(String? newTimeStep) async {
    if (newTimeStep == null || _foamCase == null) return;

    setState(() => _selectedTimeStep = newTimeStep);

    // Load fields for the new time step
    final fields = await CaseReader.getAvailableFields(
      _foamCase!.casePath,
      newTimeStep,
    );

    setState(() {
      _availableFields = fields;
      _selectedField = fields.isNotEmpty ? fields.first : null;
    });

    // Load the first field data
    if (_selectedField != null) {
      await _loadFieldData();
    }
  }

  Future<void> _onFieldChanged(String? newField) async {
    setState(() => _selectedField = newField);
    if (newField != null) {
      await _loadFieldData();
    }
  }

  Future<void> _loadFieldData() async {
    if (_foamCase == null ||
        _selectedTimeStep == null ||
        _selectedField == null) {
      return;
    }

    final fieldData = await CaseReader.loadFieldData(
      _foamCase!.casePath,
      _selectedTimeStep!,
      _selectedField!,
      _foamCase!.mesh,
    );

    setState(() {
      _currentFieldData = fieldData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('OpenFOAM PolyMesh Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open OpenFOAM Case',
            onPressed: _pickCaseFolder,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading OpenFOAM case...'),
          ],
        ),
      );
    }

    if (_error != null) {
      final isBinaryError = _error!.contains('Binary mesh files');

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBinaryError ? Icons.warning : Icons.error,
                color: isBinaryError ? Colors.orange : Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                isBinaryError
                    ? 'Binary Format Detected'
                    : 'Error loading case:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: isBinaryError ? Colors.orange.shade800 : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              if (isBinaryError) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'How to Convert to ASCII:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Open terminal in your case directory\n'
                        '2. Run: foamFormatConvert\n'
                        '3. Reload the case in this viewer',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickCaseFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Another Case'),
              ),
            ],
          ),
        ),
      );
    }

    if (_foamCase == null) {
      // Welcome screen
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 100,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to OpenFOAM Viewer',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Click the folder icon above or the button below\nto select an OpenFOAM case directory',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickCaseFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open OpenFOAM Case'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Supported Features:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• ASCII and gzip compressed (.gz) mesh files\n'
                    '• PolyMesh visualization (points, faces, boundaries)\n'
                    '• Scalar field data visualization\n'
                    '• Multiple time steps support\n'
                    '• GPU-accelerated rendering\n'
                    '• Preset camera views (top, front, isometric, etc.)',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Info panel
        Container(
          width: 250,
          color: Colors.grey[200],
          child: _buildInfoPanel(),
        ),
        // 3D viewer
        Expanded(
          child: FoamViewer(
            foamCase: _foamCase!,
            fieldData: _currentFieldData,
            showInternalMesh: _showInternalMesh,
            boundaryVisibility: _boundaryVisibility,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    if (_foamCase == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Case Path
        const Text(
          'Case Directory',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _casePath ?? _foamCase!.casePath,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // Time Step Dropdown
        const Text(
          'Time Step',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_foamCase!.timeDirectories.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: _selectedTimeStep,
              isExpanded: true,
              underline: const SizedBox(),
              items: _foamCase!.timeDirectories.map((time) {
                return DropdownMenuItem(value: time, child: Text(time));
              }).toList(),
              onChanged: _onTimeStepChanged,
            ),
          )
        else
          const Text(
            'No time directories found',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),

        const SizedBox(height: 16),

        // Field Dropdown
        const Text(
          'Scalar Field',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_availableFields.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: _selectedField,
              isExpanded: true,
              underline: const SizedBox(),
              items: _availableFields.map((field) {
                return DropdownMenuItem(value: field, child: Text(field));
              }).toList(),
              onChanged: _onFieldChanged,
            ),
          )
        else
          const Text(
            'No fields found',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        const Text(
          'File Formats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_fileFormats.isNotEmpty) ...[
          ..._fileFormats.entries.map((entry) {
            final isAscii = entry.value.toLowerCase() == 'ascii';
            final isBinary = entry.value.toLowerCase() == 'binary';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${entry.key}:', style: const TextStyle(fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isAscii
                          ? Colors.green.shade100
                          : isBinary
                          ? Colors.orange.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.value.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAscii
                            ? Colors.green.shade800
                            : isBinary
                            ? Colors.orange.shade800
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        const Text(
          'Mesh Info',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Points', _foamCase!.mesh.points.length.toString()),
        _buildInfoRow('Faces', _foamCase!.mesh.faces.length.toString()),
        _buildInfoRow('Owner', _foamCase!.mesh.owner.length.toString()),
        _buildInfoRow('Neighbour', _foamCase!.mesh.neighbour.length.toString()),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // Visibility Controls
        const Text(
          'Visibility',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Internal Mesh checkbox
        CheckboxListTile(
          title: const Text(
            'Internal Mesh',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          value: _showInternalMesh,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _showInternalMesh = value ?? true;
            });
          },
        ),
        const SizedBox(height: 8),

        // Boundary patches checkboxes
        const Text(
          'Boundary Patches',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._foamCase!.mesh.boundaries.entries.map((entry) {
          return CheckboxListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${entry.value.nFaces} faces',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            value: _boundaryVisibility[entry.key] ?? true,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _boundaryVisibility[entry.key] = value ?? true;
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
