// Example: How to integrate GPU renderer into your app

// Before (CPU-based rendering):
/*
import 'package:d3_viewer/widgets/foam_viewer.dart';

FoamViewer(
  foamCase: myOpenFoamCase,
  fieldData: myFieldData,
  showInternalMesh: true,
)
*/

// After (GPU-accelerated rendering):
import 'package:d3_viewer/widgets/foam_viewer_gpu.dart';

// Simple replacement:
FoamViewerGPU(
  foamCase: myOpenFoamCase,
  fieldData: myFieldData,
  showInternalMesh: true,
)

// With error handling and fallback:
import 'package:d3_viewer/widgets/foam_viewer.dart';
import 'package:d3_viewer/widgets/foam_viewer_gpu.dart';

class SmartFoamViewer extends StatelessWidget {
  final OpenFOAMCase foamCase;
  final FieldData? fieldData;
  
  const SmartFoamViewer({
    super.key,
    required this.foamCase,
    this.fieldData,
  });

  @override
  Widget build(BuildContext context) {
    // Try GPU renderer first, fallback to CPU if unavailable
    try {
      return FoamViewerGPU(
        foamCase: foamCase,
        fieldData: fieldData,
        showInternalMesh: true,
      );
    } catch (e) {
      debugPrint('GPU renderer unavailable, using CPU renderer: $e');
      return FoamViewer(
        foamCase: foamCase,
        fieldData: fieldData,
        showInternalMesh: true,
      );
    }
  }
}
