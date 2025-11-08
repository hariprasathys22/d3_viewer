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
        // Professional dark theme like Blender/SolidWorks
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF64B5F6),
          surface: const Color(0xFF2D2D2D),
          background: const Color(0xFF1E1E1E),
          error: const Color(0xFFEF5350),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF252525),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF2D2D2D),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFB0B0B0),
          size: 20,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
          bodySmall: TextStyle(color: Color(0xFFB0B0B0)),
          titleMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerColor: const Color(0xFF404040),
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.view_in_ar, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('OpenFOAM Viewer'),
            const SizedBox(width: 12),
            if (_foamCase != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF404040)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    Text(
                      '${_foamCase!.mesh.points.length} vertices',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          // Toolbar buttons
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Case Directory',
            onPressed: _pickCaseFolder,
          ),
          if (_foamCase != null) ...[
            const VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload Case',
              onPressed: _loadCase,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                // TODO: Add settings dialog
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF64B5F6)),
            const SizedBox(height: 16),
            const Text(
              'Loading OpenFOAM case...',
              style: TextStyle(color: Color(0xFFB0B0B0)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      final isBinaryError = _error!.contains('Binary mesh files');

      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32.0),
          margin: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isBinaryError ? const Color(0xFFFF9800) : const Color(0xFFEF5350),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBinaryError ? Icons.warning_amber : Icons.error_outline,
                color: isBinaryError ? const Color(0xFFFF9800) : const Color(0xFFEF5350),
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                isBinaryError ? 'Binary Format Detected' : 'Error Loading Case',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: isBinaryError ? const Color(0xFFFFB74D) : const Color(0xFFEF5350),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isBinaryError) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A52),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2196F3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF64B5F6), size: 20),
                          const SizedBox(width: 12),
                          const Text(
                            'How to Convert to ASCII',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '1. Open terminal in your case directory\n'
                        '2. Run: foamFormatConvert\n'
                        '3. Reload the case in this viewer',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFB0B0B0),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickCaseFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Another Case'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_foamCase == null) {
      // Welcome screen
      return SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2196F3).withOpacity(0.2),
                        const Color(0xFF64B5F6).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.view_in_ar,
                    size: 80,
                    color: Color(0xFF64B5F6),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'OpenFOAM 3D Viewer',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Professional CFD mesh visualization and analysis',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF808080),
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: _pickCaseFolder,
                  icon: const Icon(Icons.folder_open, size: 24),
                  label: const Text('Open OpenFOAM Case', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF404040)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Features',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureItem(Icons.compress, 'ASCII & gzip compressed files (.gz)'),
                      _buildFeatureItem(Icons.grid_on, 'PolyMesh visualization'),
                      _buildFeatureItem(Icons.gradient, 'Scalar field data'),
                      _buildFeatureItem(Icons.access_time, 'Multiple time steps'),
                      _buildFeatureItem(Icons.speed, 'GPU-accelerated rendering'),
                      _buildFeatureItem(Icons.threed_rotation, 'Preset camera views'),
                    ],
                  ),
                ),
                const SizedBox(height: 32), // Add bottom padding
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        // Left panel - Properties
        Container(
          width: 280,
          decoration: const BoxDecoration(
            color: Color(0xFF252525),
            border: Border(
              right: BorderSide(color: Color(0xFF404040), width: 1),
            ),
          ),
          child: _buildInfoPanel(),
        ),
        // 3D viewport
        Expanded(
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: FoamViewer(
              foamCase: _foamCase!,
              fieldData: _currentFieldData,
              showInternalMesh: _showInternalMesh,
              boundaryVisibility: _boundaryVisibility,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    if (_foamCase == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        // Case Path Section
        _buildPanelSection(
          title: 'CASE',
          icon: Icons.folder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF404040)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 14, color: Color(0xFF64B5F6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _casePath ?? _foamCase!.casePath,
                        style: const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Time Step Section
        _buildPanelSection(
          title: 'TIME STEP',
          icon: Icons.access_time,
          child: _foamCase!.timeDirectories.isNotEmpty
              ? _buildStyledDropdown<String>(
                  value: _selectedTimeStep,
                  items: _foamCase!.timeDirectories.map((time) {
                    return DropdownMenuItem(value: time, child: Text(time));
                  }).toList(),
                  onChanged: _onTimeStepChanged,
                  hint: 'Select time',
                )
              : const Text(
                  'No time directories',
                  style: TextStyle(fontSize: 11, color: Color(0xFF808080)),
                ),
        ),

        // Scalar Field Section
        _buildPanelSection(
          title: 'SCALAR FIELD',
          icon: Icons.gradient,
          child: _availableFields.isNotEmpty
              ? _buildStyledDropdown<String>(
                  value: _selectedField,
                  items: _availableFields.map((field) {
                    return DropdownMenuItem(value: field, child: Text(field));
                  }).toList(),
                  onChanged: _onFieldChanged,
                  hint: 'Select field',
                )
              : const Text(
                  'No fields available',
                  style: TextStyle(fontSize: 11, color: Color(0xFF808080)),
                ),
        ),

        // Mesh Statistics Section
        _buildPanelSection(
          title: 'MESH INFO',
          icon: Icons.grid_on,
          child: Column(
            children: [
              _buildStatRow('Points', _foamCase!.mesh.points.length, Icons.blur_on),
              const SizedBox(height: 6),
              _buildStatRow('Faces', _foamCase!.mesh.faces.length, Icons.crop_square),
              const SizedBox(height: 6),
              _buildStatRow('Cells', _foamCase!.mesh.owner.length, Icons.view_in_ar),
              const SizedBox(height: 6),
              _buildStatRow('Boundaries', _foamCase!.mesh.boundaries.length, Icons.border_outer),
            ],
          ),
        ),

        // File Formats Section
        if (_fileFormats.isNotEmpty)
          _buildPanelSection(
            title: 'FILE FORMATS',
            icon: Icons.description,
            child: Column(
              children: _fileFormats.entries.map((entry) {
                final isAscii = entry.value.toLowerCase() == 'ascii';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAscii ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          entry.value.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // Visibility Controls Section
        _buildPanelSection(
          title: 'VISIBILITY',
          icon: Icons.visibility,
          child: Column(
            children: [
              // Internal Mesh Toggle
              _buildToggleItem(
                'Internal Mesh',
                _showInternalMesh,
                (value) => setState(() => _showInternalMesh = value ?? true),
                Icons.grid_4x4,
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFF404040)),
              const SizedBox(height: 8),
              // Boundary Patches
              const Text(
                'BOUNDARY PATCHES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF808080),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              ..._foamCase!.mesh.boundaries.entries.map((entry) {
                return _buildToggleItem(
                  entry.key,
                  _boundaryVisibility[entry.key] ?? true,
                  (value) => setState(() => _boundaryVisibility[entry.key] = value ?? true),
                  Icons.layers,
                  subtitle: '${entry.value.nFaces} faces',
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(icon, size: 16, color: const Color(0xFF64B5F6)),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE0E0E0),
              letterSpacing: 0.5,
            ),
          ),
          iconColor: const Color(0xFF808080),
          collapsedIconColor: const Color(0xFF808080),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF2D2D2D),
        style: const TextStyle(fontSize: 12, color: Color(0xFFE0E0E0)),
        icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF808080)),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStatRow(String label, int value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64B5F6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64B5F6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
    IconData icon, {
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: value ? const Color(0xFF1E3A52) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? const Color(0xFF2196F3) : const Color(0xFF404040),
          width: 1,
        ),
      ),
      child: CheckboxListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        secondary: Icon(icon, size: 14, color: value ? const Color(0xFF64B5F6) : const Color(0xFF808080)),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: value ? const Color(0xFFE0E0E0) : const Color(0xFF808080),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 9, color: Color(0xFF808080)),
              )
            : null,
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2196F3),
        checkColor: Colors.white,
        side: const BorderSide(color: Colors.transparent),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64B5F6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB0B0B0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
