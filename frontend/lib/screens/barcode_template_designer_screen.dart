import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' hide BarcodeElement;
import 'package:provider/provider.dart';
import '../models/barcode_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/barcode_printer_service.dart';
import '../theme/glass_theme.dart';

class BarcodeTemplateDesignerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BarcodeTemplateDesignerScreen({super.key, this.onBack});

  @override
  State<BarcodeTemplateDesignerScreen> createState() =>
      _BarcodeTemplateDesignerScreenState();
}

class _BarcodeTemplateDesignerScreenState
    extends State<BarcodeTemplateDesignerScreen> {
  final ApiService _api = ApiService();

  List<BarcodeTemplate> _templates = [];
  BarcodeTemplate? _selectedTemplate;
  String? _selectedElementId;
  bool _isLoading = true;
  bool _isSaving = false;

  // Visual Canvas Zoom
  double _zoomScale = 1.25;

  // Controllers for Template Properties
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _gapController = TextEditingController();
  final TextEditingController _marginTopController = TextEditingController();
  final TextEditingController _marginLeftController = TextEditingController();

  String _currentUnit = 'mm';
  int _labelsPerRow = 2;
  String _tagStyle = 'JEWELRY_BUTTERFLY';

  // Sample data item for real-time live preview
  late StockTaggedItem _sampleItem;

  @override
  void initState() {
    super.initState();
    _sampleItem = BarcodePrinterService.createSampleItem();
    _fetchTemplates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _gapController.dispose();
    _marginTopController.dispose();
    _marginLeftController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final res = await _api.getBarcodeTemplates(token);
    if (mounted) {
      if (res['success'] == true && res['templates'] != null) {
        final list = (res['templates'] as List)
            .map((t) => BarcodeTemplate.fromJson(t as Map<String, dynamic>))
            .toList();
        setState(() {
          _templates = list;
          if (_templates.isNotEmpty) {
            final defaultT = _templates.firstWhere(
              (t) => t.isDefault,
              orElse: () => _templates.first,
            );
            _loadTemplateIntoState(defaultT);
          } else {
            _createNewTemplate();
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadTemplateIntoState(BarcodeTemplate t) {
    _selectedTemplate = t;
    _nameController.text = t.name;
    _widthController.text = t.widthMm.toString();
    _heightController.text = t.heightMm.toString();
    _gapController.text = t.gapMm.toString();
    _marginTopController.text = t.marginTopMm.toString();
    _marginLeftController.text = t.marginLeftMm.toString();
    _currentUnit = t.unit;
    _labelsPerRow = t.labelsPerRow;
    _tagStyle = t.tagStyle;
    _selectedElementId = t.elements.isNotEmpty ? t.elements.first.id : null;
  }

  void _createNewTemplate() {
    final newT = BarcodeTemplate(
      name: 'New Custom Jewelry Tag',
      widthMm: 80.0,
      heightMm: 13.0,
      unit: 'mm',
      labelsPerRow: 2,
      gapMm: 2.0,
      marginTopMm: 1.0,
      marginLeftMm: 1.0,
      tagStyle: 'JEWELRY_BUTTERFLY',
      isDefault: false,
      elements: [
        BarcodeElement(
          id: 'elem_qr_${DateTime.now().millisecondsSinceEpoch}',
          type: 'barcode_2d',
          fieldKey: 'sku',
          xMm: 1.0,
          yMm: 1.0,
          widthMm: 10.0,
          heightMm: 10.0,
        ),
        BarcodeElement(
          id: 'elem_comp_${DateTime.now().millisecondsSinceEpoch}',
          type: 'text',
          fieldKey: 'company_name',
          xMm: 12.0,
          yMm: 1.0,
          widthMm: 25.0,
          heightMm: 3.5,
          fontSize: 7.0,
          isBold: true,
        ),
        BarcodeElement(
          id: 'elem_grs_${DateTime.now().millisecondsSinceEpoch}',
          type: 'text',
          fieldKey: 'gross_weight',
          labelPrefix: 'GRSWT: ',
          formatTemplate: 'GRSWT: {gross_weight}g',
          xMm: 40.0,
          yMm: 1.0,
          widthMm: 38.0,
          heightMm: 3.5,
          fontSize: 6.5,
          isBold: true,
        ),
      ],
    );
    setState(() {
      _loadTemplateIntoState(newT);
    });
  }

  void _applyPreset(String presetKey) {
    if (presetKey == 'butterfly_80x13') {
      _nameController.text = 'Jewelry Butterfly Tag (80x13mm, 2-Across)';
      _widthController.text = '80.0';
      _heightController.text = '13.0';
      _currentUnit = 'mm';
      _labelsPerRow = 2;
      _tagStyle = 'JEWELRY_BUTTERFLY';
      _gapController.text = '3.0';
    } else if (presetKey == 'dumbbell_70x15') {
      _nameController.text = 'Jewelry Dumbbell Tag (70x15mm, 2-Across)';
      _widthController.text = '70.0';
      _heightController.text = '15.0';
      _currentUnit = 'mm';
      _labelsPerRow = 2;
      _tagStyle = 'JEWELRY_DUMBBELL';
      _gapController.text = '2.0';
    } else if (presetKey == 'retail_50x25') {
      _nameController.text = 'Standard Retail Barcode (50x25mm, 1-Across)';
      _widthController.text = '50.0';
      _heightController.text = '25.0';
      _currentUnit = 'mm';
      _labelsPerRow = 1;
      _tagStyle = 'RECTANGLE';
      _gapController.text = '2.0';
    } else if (presetKey == 'diamond_60x12') {
      _nameController.text = 'Diamond Mini Tag (60x12mm, 2-Across)';
      _widthController.text = '60.0';
      _heightController.text = '12.0';
      _currentUnit = 'mm';
      _labelsPerRow = 2;
      _tagStyle = 'JEWELRY_BUTTERFLY';
      _gapController.text = '2.0';
    }
    _syncFormToTemplate();
  }

  void _syncFormToTemplate() {
    if (_selectedTemplate == null) return;
    setState(() {
      _selectedTemplate = _selectedTemplate!.copyWith(
        name: _nameController.text.trim(),
        widthMm: double.tryParse(_widthController.text) ?? 80.0,
        heightMm: double.tryParse(_heightController.text) ?? 13.0,
        unit: _currentUnit,
        labelsPerRow: _labelsPerRow,
        gapMm: double.tryParse(_gapController.text) ?? 2.0,
        marginTopMm: double.tryParse(_marginTopController.text) ?? 1.0,
        marginLeftMm: double.tryParse(_marginLeftController.text) ?? 1.0,
        tagStyle: _tagStyle,
      );
    });
  }

  Future<void> _saveTemplate() async {
    _syncFormToTemplate();
    if (_selectedTemplate == null) return;

    if (_selectedTemplate!.name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid template name.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    final payload = _selectedTemplate!.toJson();

    Map<String, dynamic> res;
    if (_selectedTemplate!.templateId != null &&
        _selectedTemplate!.templateId! > 0) {
      res = await _api.updateBarcodeTemplate(
        token,
        _selectedTemplate!.templateId!,
        payload,
      );
    } else {
      res = await _api.createBarcodeTemplate(token, payload);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Template saved successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _fetchTemplates();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to save template.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _setAsDefault() async {
    if (_selectedTemplate?.templateId == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    final res = await _api.setDefaultBarcodeTemplate(
      token,
      _selectedTemplate!.templateId!,
    );
    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template set as default print template!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchTemplates();
      }
    }
  }

  Future<void> _deleteTemplate() async {
    if (_selectedTemplate?.templateId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete Template',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${_selectedTemplate!.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.authToken ?? '';
      final res = await _api.deleteBarcodeTemplate(
        token,
        _selectedTemplate!.templateId!,
      );
      if (mounted && res['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Template deleted.')));
        _fetchTemplates();
      }
    }
  }

  void _addElement(BarcodeFieldDefinition def, {String type = 'text'}) {
    if (_selectedTemplate == null) return;
    final newId = 'elem_${def.key}_${DateTime.now().millisecondsSinceEpoch}';

    final elem = BarcodeElement(
      id: newId,
      type: type,
      fieldKey: def.key,
      labelPrefix:
          (type == 'text' &&
              def.key != 'custom' &&
              def.key != 'purity' &&
              def.key != 'product_name')
          ? '${def.label.split(' ').first}: '
          : '',
      formatTemplate: def.defaultFormat,
      xMm: 2.0,
      yMm: (_selectedTemplate!.elements.length * 3.5).clamp(
        1.0,
        _selectedTemplate!.heightMm - 4.0,
      ),
      widthMm: (type == 'barcode_2d' || type == 'barcode_1d') ? 12.0 : 35.0,
      heightMm: (type == 'barcode_2d' || type == 'barcode_1d') ? 10.0 : 3.5,
      fontSize: 6.5,
      isBold:
          def.key == 'gross_weight' ||
          def.key == 'purity' ||
          def.key == 'company_name',
    );

    setState(() {
      final updatedElems = List<BarcodeElement>.from(
        _selectedTemplate!.elements,
      )..add(elem);
      _selectedTemplate = _selectedTemplate!.copyWith(elements: updatedElems);
      _selectedElementId = newId;
    });
  }

  void _updateElement(BarcodeElement updated) {
    if (_selectedTemplate == null) return;
    setState(() {
      final list = _selectedTemplate!.elements
          .map<BarcodeElement>((e) => e.id == updated.id ? updated : e)
          .toList();
      _selectedTemplate = _selectedTemplate!.copyWith(elements: list);
    });
  }

  void _deleteElement(String id) {
    if (_selectedTemplate == null) return;
    setState(() {
      final list = _selectedTemplate!.elements
          .where((e) => e.id != id)
          .toList();
      _selectedTemplate = _selectedTemplate!.copyWith(elements: list);
      if (_selectedElementId == id) {
        _selectedElementId = list.isNotEmpty ? list.first.id : null;
      }
    });
  }

  void _showAddFieldDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: GlassTheme.accentAmber,
              ),
              const SizedBox(width: 8),
              const Text(
                'Add Dynamic Field Element',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            height: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Barcode / QR Code Elements:',
                    style: TextStyle(
                      color: GlassTheme.accentAmber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: GlassTheme.accentAmber.withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.cyanAccent,
                          ),
                          label: const Text(
                            '2D QR Code (SKU)',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _addElement(
                              const BarcodeFieldDefinition(
                                key: 'sku',
                                label: 'SKU QR Code',
                                sampleValue: '27A001',
                                defaultFormat: '{sku}',
                              ),
                              type: 'barcode_2d',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: GlassTheme.accentAmber.withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(
                            Icons.view_week_rounded,
                            color: Colors.amberAccent,
                          ),
                          label: const Text(
                            '1D Barcode (Code128)',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _addElement(
                              const BarcodeFieldDefinition(
                                key: 'sku',
                                label: 'SKU 1D Barcode',
                                sampleValue: '27A001',
                                defaultFormat: '{sku}',
                              ),
                              type: 'barcode_1d',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Dynamic Database Fields:',
                    style: TextStyle(
                      color: GlassTheme.accentAmber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BarcodeFieldDefinition.registry.map((def) {
                      return ActionChip(
                        backgroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Colors.white24),
                        label: Text(
                          def.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        avatar: Icon(
                          Icons.add,
                          size: 16,
                          color: GlassTheme.accentAmber,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _addElement(def, type: 'text');
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: GlassTheme.bgDark,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentElem = _selectedTemplate?.elements.firstWhere(
      (e) => e.id == _selectedElementId,
      orElse: () => _selectedTemplate!.elements.isNotEmpty
          ? _selectedTemplate!.elements.first
          : BarcodeElement(id: 'dummy', type: 'text', fieldKey: 'custom'),
    );

    return Scaffold(
      backgroundColor: GlassTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            _buildTopHeader(),

            // Main Editor Body: Left Properties, Center Live Preview, Right Inspector
            Expanded(
              child: Row(
                children: [
                  // Left Properties & Page Setup Panel
                  SizedBox(width: 320, child: _buildLeftPropertiesPanel()),

                  // Center Interactive Live Preview Canvas
                  Expanded(child: _buildCenterLivePreviewCanvas()),

                  // Right Elements & Inspector Panel
                  SizedBox(
                    width: 340,
                    child: _buildRightInspectorPanel(currentElem),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        border: Border(bottom: BorderSide(color: GlassTheme.glassBorder)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: Icon(Icons.arrow_back, color: GlassTheme.textPrimary),
              onPressed: widget.onBack,
              tooltip: 'Back to Menu',
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: GlassTheme.goldGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Barcode & RFID Label Template Designer',
                style: TextStyle(
                  color: GlassTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Dynamic multi-column label design with real-time live preview & universal printer support',
                style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),

          // Template Selector Dropdown
          if (_templates.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: GlassTheme.bgSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GlassTheme.glassBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedTemplate?.templateId,
                  dropdownColor: Colors.white,
                  hint: Text(
                    'Select Template',
                    style: TextStyle(
                      color: GlassTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  items: _templates.map((t) {
                    return DropdownMenuItem<int>(
                      value: t.templateId,
                      child: Row(
                        children: [
                          Text(
                            t.name,
                            style: TextStyle(
                              color: GlassTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          if (t.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      final found = _templates.firstWhere(
                        (t) => t.templateId == id,
                      );
                      setState(() => _loadTemplateIntoState(found));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // New Template Button
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: Color(0xFF0284C7)),
            tooltip: 'New Template',
            onPressed: _createNewTemplate,
          ),

          // Delete Template Button
          if (_selectedTemplate?.templateId != null) ...[
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              tooltip: 'Delete Template',
              onPressed: _deleteTemplate,
            ),
          ],

          // Set Default Button
          if (_selectedTemplate?.templateId != null &&
              !_selectedTemplate!.isDefault) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green.shade600),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              icon: const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.green,
              ),
              label: const Text(
                'Set Default',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
              onPressed: _setAsDefault,
            ),
            const SizedBox(width: 8),
          ],

          // Test Print Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: GlassTheme.accentAmber),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: Icon(
              Icons.print_rounded,
              size: 16,
              color: GlassTheme.accentAmber,
            ),
            label: Text(
              'Test Print',
              style: TextStyle(
                color: GlassTheme.accentAmber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              if (_selectedTemplate != null) {
                BarcodePrinterService.directPrint(
                  template: _selectedTemplate!,
                  items: [_sampleItem, _sampleItem],
                  jobName: 'Test_Print_${_selectedTemplate!.name}',
                );
              }
            },
          ),
          const SizedBox(width: 8),

          // Save Template Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentAmber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: const Text(
              'Save Template',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _isSaving ? null : _saveTemplate,
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPropertiesPanel() {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        border: Border(right: BorderSide(color: GlassTheme.glassBorder)),
      ),
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Presets Quick Selector
            Text(
              'Quick Presets / Standard Sizes',
              style: TextStyle(
                color: GlassTheme.accentAmber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetButton('Butterfly 80x13', 'butterfly_80x13'),
                _buildPresetButton('Dumbbell 70x15', 'dumbbell_70x15'),
                _buildPresetButton('Retail 50x25', 'retail_50x25'),
                _buildPresetButton('Diamond 60x12', 'diamond_60x12'),
              ],
            ),
            const Divider(color: Colors.black12, height: 24),

            // Template Name
            Text(
              'Template Name',
              style: TextStyle(
                color: GlassTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              onChanged: (_) => _syncFormToTemplate(),
              style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13),
              decoration: _inputDeco('e.g. Jewelry Butterfly Tag'),
            ),
            const SizedBox(height: 12),

            // Dimension Unit & Labels per row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _currentUnit,
                        dropdownColor: Colors.white,
                        decoration: _inputDeco(''),
                        items: const [
                          DropdownMenuItem(
                            value: 'mm',
                            child: Text(
                              'Millimeter (mm)',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'inch',
                            child: Text(
                              'Inches (inch)',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'cm',
                            child: Text(
                              'Centimeter (cm)',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _currentUnit = val);
                            _syncFormToTemplate();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Labels Per Row',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        initialValue: _labelsPerRow,
                        dropdownColor: Colors.white,
                        decoration: _inputDeco(''),
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              '1-Across (Single)',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              '2-Across (Dual)',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _labelsPerRow = val);
                            _syncFormToTemplate();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Width & Height
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Label Width ($_currentUnit)',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _widthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _syncFormToTemplate(),
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _inputDeco('80.0'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Label Height ($_currentUnit)',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _syncFormToTemplate(),
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _inputDeco('13.0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tag Shape / Visual Style
            Text(
              'Tag Physical Shape',
              style: TextStyle(
                color: GlassTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _tagStyle,
              dropdownColor: Colors.white,
              decoration: _inputDeco(''),
              items: const [
                DropdownMenuItem(
                  value: 'JEWELRY_BUTTERFLY',
                  child: Text(
                    'Jewelry Butterfly (Folded / 2-Sided)',
                    style: TextStyle(color: Color(0xFF0F172A)),
                  ),
                ),
                DropdownMenuItem(
                  value: 'JEWELRY_DUMBBELL',
                  child: Text(
                    'Jewelry Dumbbell (Tail & Head)',
                    style: TextStyle(color: Color(0xFF0F172A)),
                  ),
                ),
                DropdownMenuItem(
                  value: 'RECTANGLE',
                  child: Text(
                    'Standard Rectangular Tag',
                    style: TextStyle(color: Color(0xFF0F172A)),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _tagStyle = val);
                  _syncFormToTemplate();
                }
              },
            ),
            const SizedBox(height: 12),

            // Margins & Gap
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gap (mm)',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _gapController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _syncFormToTemplate(),
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _inputDeco('2.0'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Margin',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _marginTopController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _syncFormToTemplate(),
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _inputDeco('1.0'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Left Margin',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _marginLeftController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _syncFormToTemplate(),
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _inputDeco('1.0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.black12, height: 24),

            // Printer Compatibility Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0284C7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Universal Printing: Works automatically on TSC, Zebra, Godex, Citizen, TVS, and all Windows label printers.',
                      style: TextStyle(color: Color(0xFF0369A1), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String title, String presetKey) {
    return InkWell(
      onTap: () => _applyPreset(presetKey),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GlassTheme.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GlassTheme.glassBorder),
        ),
        child: Text(
          title,
          style: TextStyle(color: GlassTheme.textPrimary, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildCenterLivePreviewCanvas() {
    if (_selectedTemplate == null) {
      return const Center(child: Text('No Template Selected'));
    }

    final t = _selectedTemplate!;
    final widthMm = t.effectiveWidthMm;
    final heightMm = t.effectiveHeightMm;
    final gapMm = t.gapMm;
    final labelsPerRow = t.labelsPerRow;

    // Millimeter to Screen Pixels Scale factor (approx 3.78 px per mm at 100% scale)
    const baseMmToPx = 3.7795;
    final scale = baseMmToPx * _zoomScale;

    final labelWidthPx = widthMm * scale;
    final labelHeightPx = heightMm * scale;
    final gapPx = gapMm * scale;

    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Canvas Controls Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.visibility_rounded,
                  size: 16,
                  color: GlassTheme.accentAmber,
                ),
                const SizedBox(width: 6),
                Text(
                  'Interactive Live Preview (${widthMm.toStringAsFixed(1)} x ${heightMm.toStringAsFixed(1)} mm, $labelsPerRow-Across)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Zoom:',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    size: 18,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(
                    () => _zoomScale = (_zoomScale - 0.25).clamp(0.5, 3.0),
                  ),
                  tooltip: 'Zoom Out',
                ),
                Text(
                  '${(_zoomScale * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(
                    () => _zoomScale = (_zoomScale + 0.25).clamp(0.5, 3.0),
                  ),
                  tooltip: 'Zoom In',
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: () => setState(() => _zoomScale = 1.25),
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Canvas View Area
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    margin: const EdgeInsets.all(30),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Row of labels (1 or 2 across)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSingleLabelCanvas(
                              t,
                              scale,
                              labelWidthPx,
                              labelHeightPx,
                              isPrimary: true,
                            ),
                            if (labelsPerRow == 2) ...[
                              SizedBox(width: gapPx),
                              _buildSingleLabelCanvas(
                                t,
                                scale,
                                labelWidthPx,
                                labelHeightPx,
                                isPrimary: false,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLabelCanvas(
    BarcodeTemplate t,
    double scale,
    double labelWidthPx,
    double labelHeightPx, {
    required bool isPrimary,
  }) {
    return Container(
      width: labelWidthPx,
      height: labelHeightPx,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          t.tagStyle == 'JEWELRY_DUMBBELL' ? 8 : 4,
        ),
        border: Border.all(
          color: isPrimary ? Colors.blueAccent : Colors.grey.shade400,
          width: isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          t.tagStyle == 'JEWELRY_DUMBBELL' ? 8 : 4,
        ),
        child: Stack(
          children: [
            // Visual decorative fold line for Butterfly Tag
            if (t.tagStyle == 'JEWELRY_BUTTERFLY') ...[
              Positioned(
                left: (labelWidthPx / 2) - 0.5,
                top: 0,
                bottom: 0,
                child: Container(width: 1.0, color: Colors.grey.shade300),
              ),
            ],

            // Elements rendering
            ...t.elements.where((e) => e.isVisible).map((elem) {
              final isSelected = isPrimary && elem.id == _selectedElementId;
              final leftPx = elem.xMm * scale;
              final topPx = elem.yMm * scale;
              final widthPx = elem.widthMm * scale;
              final heightPx = elem.heightMm * scale;

              Widget childWidget;
              if (elem.type == 'barcode_2d') {
                childWidget = BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: _sampleItem.skuCode,
                  width: widthPx,
                  height: heightPx,
                );
              } else if (elem.type == 'barcode_1d') {
                childWidget = BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: _sampleItem.skuCode,
                  width: widthPx,
                  height: heightPx,
                  drawText: false,
                );
              } else {
                final text = BarcodePrinterService.formatElementText(
                  elem: elem,
                  item: _sampleItem,
                );
                TextAlign align = TextAlign.left;
                if (elem.alignment == 'center') align = TextAlign.center;
                if (elem.alignment == 'right') align = TextAlign.right;

                childWidget = Container(
                  width: widthPx,
                  height: heightPx,
                  alignment: elem.alignment == 'center'
                      ? Alignment.center
                      : (elem.alignment == 'right'
                            ? Alignment.centerRight
                            : Alignment.centerLeft),
                  child: Text(
                    text,
                    textAlign: align,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: elem.fontSize * (_zoomScale * 0.95),
                      fontWeight: elem.isBold
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontFamily: 'Roboto',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }

              return Positioned(
                left: leftPx,
                top: topPx,
                child: GestureDetector(
                  onTap: () {
                    if (isPrimary) {
                      setState(() => _selectedElementId = elem.id);
                    }
                  },
                  child: Container(
                    decoration: isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              color: Colors.blueAccent,
                              width: 1.5,
                            ),
                            color: Colors.blueAccent.withOpacity(0.08),
                          )
                        : null,
                    child: childWidget,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRightInspectorPanel(BarcodeElement? currentElem) {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        border: Border(left: BorderSide(color: GlassTheme.glassBorder)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elements Header with Add Button
          Row(
            children: [
              Text(
                'Template Elements (${_selectedTemplate?.elements.length ?? 0})',
                style: TextStyle(
                  color: GlassTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentAmber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(60, 30),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Field',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: _showAddFieldDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Elements List
          SizedBox(
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                color: GlassTheme.bgSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GlassTheme.glassBorder),
              ),
              child: ListView.separated(
                itemCount: _selectedTemplate?.elements.length ?? 0,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.black12, height: 1),
                itemBuilder: (ctx, idx) {
                  final elem = _selectedTemplate!.elements[idx];
                  final isSelected = elem.id == _selectedElementId;

                  IconData icon = Icons.text_fields_rounded;
                  if (elem.type == 'barcode_2d') icon = Icons.qr_code_2_rounded;
                  if (elem.type == 'barcode_1d') icon = Icons.view_week_rounded;

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    selected: isSelected,
                    selectedTileColor: Colors.blueAccent.withOpacity(0.12),
                    leading: Icon(
                      icon,
                      size: 18,
                      color: isSelected
                          ? const Color(0xFF0284C7)
                          : GlassTheme.textMuted,
                    ),
                    title: Text(
                      elem.fieldKey.toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF0284C7)
                            : GlassTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '(${elem.xMm.toStringAsFixed(1)}, ${elem.yMm.toStringAsFixed(1)} mm) - ${elem.formatTemplate.isNotEmpty ? elem.formatTemplate : elem.labelPrefix}',
                      style: TextStyle(
                        color: GlassTheme.textMuted,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            elem.isVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 16,
                            color: elem.isVisible
                                ? Colors.black87
                                : Colors.black26,
                          ),
                          onPressed: () {
                            _updateElement(
                              elem.copyWith(isVisible: !elem.isVisible),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteElement(elem.id),
                        ),
                      ],
                    ),
                    onTap: () => setState(() => _selectedElementId = elem.id),
                  );
                },
              ),
            ),
          ),
          const Divider(color: Colors.black12, height: 20),

          // Selected Element Inspector
          if (currentElem != null && currentElem.id != 'dummy') ...[
            Text(
              'Element Properties',
              style: TextStyle(
                color: GlassTheme.accentAmber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Element Type Dropdown
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Element Type',
                                style: TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: currentElem.type,
                                dropdownColor: Colors.white,
                                decoration: _inputDeco(''),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'text',
                                    child: Text(
                                      'Text Field',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'barcode_2d',
                                    child: Text(
                                      '2D QR Code',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'barcode_1d',
                                    child: Text(
                                      '1D Barcode',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    _updateElement(
                                      currentElem.copyWith(type: val),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Field Key',
                                style: TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: currentElem.fieldKey,
                                dropdownColor: Colors.white,
                                decoration: _inputDeco(''),
                                items: BarcodeFieldDefinition.registry.map((
                                  def,
                                ) {
                                  return DropdownMenuItem(
                                    value: def.key,
                                    child: Text(
                                      def.label,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final def = BarcodeFieldDefinition.registry
                                        .firstWhere(
                                          (d) => d.key == val,
                                          orElse: () => BarcodeFieldDefinition
                                              .registry
                                              .first,
                                        );
                                    _updateElement(
                                      currentElem.copyWith(
                                        fieldKey: val,
                                        formatTemplate: def.defaultFormat,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Prefix & Format String
                    if (currentElem.type == 'text') ...[
                      Text(
                        'Label Prefix (e.g. GRSWT: , S: , D: )',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        key: ValueKey('prefix_${currentElem.id}'),
                        initialValue: currentElem.labelPrefix,
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                        ),
                        decoration: _inputDeco('e.g. GRSWT: '),
                        onChanged: (val) => _updateElement(
                          currentElem.copyWith(labelPrefix: val),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'Format Template (Tokens: {gross_weight}, {stone_pcs}, etc.)',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        key: ValueKey('format_${currentElem.id}'),
                        initialValue: currentElem.formatTemplate,
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                        ),
                        decoration: _inputDeco('{gross_weight}g'),
                        onChanged: (val) => _updateElement(
                          currentElem.copyWith(formatTemplate: val),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Coordinates: X (mm) and Y (mm)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'X Position (mm)',
                                style: TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                key: ValueKey('x_${currentElem.id}'),
                                initialValue: currentElem.xMm.toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  color: GlassTheme.textPrimary,
                                  fontSize: 12,
                                ),
                                decoration: _inputDeco('0.0'),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val);
                                  if (numVal != null) {
                                    _updateElement(
                                      currentElem.copyWith(xMm: numVal),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Y Position (mm)',
                                style: TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                key: ValueKey('y_${currentElem.id}'),
                                initialValue: currentElem.yMm.toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  color: GlassTheme.textPrimary,
                                  fontSize: 12,
                                ),
                                decoration: _inputDeco('0.0'),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val);
                                  if (numVal != null) {
                                    _updateElement(
                                      currentElem.copyWith(yMm: numVal),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Dimensions: Width (mm) and Height (mm)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Width (mm)',
                                style: TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                key: ValueKey('w_${currentElem.id}'),
                                initialValue: currentElem.widthMm.toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  color: GlassTheme.textPrimary,
                                  fontSize: 12,
                                ),
                                decoration: _inputDeco('30.0'),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val);
                                  if (numVal != null) {
                                    _updateElement(
                                      currentElem.copyWith(widthMm: numVal),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Height (mm)',
                                style: TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                key: ValueKey('h_${currentElem.id}'),
                                initialValue: currentElem.heightMm.toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  color: GlassTheme.textPrimary,
                                  fontSize: 12,
                                ),
                                decoration: _inputDeco('4.0'),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val);
                                  if (numVal != null) {
                                    _updateElement(
                                      currentElem.copyWith(heightMm: numVal),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Text styling (Font Size, Bold, Alignment)
                    if (currentElem.type == 'text') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Font Size (pt)',
                                  style: TextStyle(
                                    color: GlassTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  key: ValueKey('fs_${currentElem.id}'),
                                  initialValue: currentElem.fontSize.toString(),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: TextStyle(
                                    color: GlassTheme.textPrimary,
                                    fontSize: 12,
                                  ),
                                  decoration: _inputDeco('6.5'),
                                  onChanged: (val) {
                                    final numVal = double.tryParse(val);
                                    if (numVal != null) {
                                      _updateElement(
                                        currentElem.copyWith(fontSize: numVal),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alignment',
                                  style: TextStyle(
                                    color: GlassTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: currentElem.alignment,
                                  dropdownColor: Colors.white,
                                  decoration: _inputDeco(''),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'left',
                                      child: Text(
                                        'Left',
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'center',
                                      child: Text(
                                        'Center',
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'right',
                                      child: Text(
                                        'Right',
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      _updateElement(
                                        currentElem.copyWith(alignment: val),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Bold Typography',
                          style: TextStyle(
                            color: GlassTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                        value: currentElem.isBold,
                        activeColor: GlassTheme.accentAmber,
                        checkColor: Colors.white,
                        onChanged: (val) => _updateElement(
                          currentElem.copyWith(isBold: val ?? false),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Text(
                  'Select or add an element to configure its properties.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GlassTheme.textMuted, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: GlassTheme.textMuted.withOpacity(0.5),
        fontSize: 12,
      ),
      filled: true,
      fillColor: GlassTheme.bgSurfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: GlassTheme.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: GlassTheme.accentAmber, width: 1.5),
      ),
    );
  }
}
