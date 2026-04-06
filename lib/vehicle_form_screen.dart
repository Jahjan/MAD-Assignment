import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class VehicleFormScreen extends StatefulWidget {
  final Map<String, dynamic>? vehicle; // null = add mode, non-null = edit mode

  const VehicleFormScreen({super.key, this.vehicle});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  final _mileageController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'Car';
  String _selectedStatus = 'Active';
  DateTime? _lastServiceDate;
  File? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool get _isEditing => widget.vehicle != null;

  final _types = ['Car', 'Van', 'Truck', 'Bus', 'Motorcycle', 'Other'];
  final _statuses = ['Active', 'In Service', 'Inactive', 'Retired'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final v = widget.vehicle!;
      _plateController.text = v['number_plate'] ?? '';
      _modelController.text = v['model'] ?? '';
      _colorController.text = v['color'] ?? '';
      _yearController.text = v['year']?.toString() ?? '';
      _mileageController.text = v['mileage']?.toString() ?? '';
      _notesController.text = v['notes'] ?? '';
      _selectedType = v['type'] ?? 'Car';
      _selectedStatus = v['status'] ?? 'Active';
      _existingImageUrl = v['image_url'];
      if (v['last_service_date'] != null) {
        _lastServiceDate = DateTime.tryParse(v['last_service_date']);
      }
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String vehicleId) async {
    if (_selectedImage == null) return _existingImageUrl;
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final ext = _selectedImage!.path.split('.').last;
      final path = 'vehicles/$vehicleId.$ext';
      await supabase.storage
          .from('vehicle-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return supabase.storage.from('vehicle-images').getPublicUrl(path);
    } catch (_) {
      return _existingImageUrl;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'number_plate': _plateController.text.trim().toUpperCase(),
        'model': _modelController.text.trim(),
        'color': _colorController.text.trim(),
        'type': _selectedType,
        'status': _selectedStatus,
        'year': int.tryParse(_yearController.text.trim()),
        'mileage': int.tryParse(_mileageController.text.trim()),
        'notes': _notesController.text.trim(),
        'last_service_date': _lastServiceDate?.toIso8601String().split('T')[0],
      };

      if (_isEditing) {
        final id = widget.vehicle!['id'].toString();
        final imageUrl = await _uploadImage(id);
        data['image_url'] = imageUrl;
        await supabase.from('vehicles').update(data).eq('id', id);
      } else {
        final result = await supabase
            .from('vehicles')
            .insert(data)
            .select()
            .single();
        final id = result['id'].toString();
        final imageUrl = await _uploadImage(id);
        if (imageUrl != null) {
          await supabase
              .from('vehicles')
              .update({'image_url': imageUrl})
              .eq('id', id);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on PostgrestException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            surface: Color(0xFF161B2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _lastServiceDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Vehicle' : 'Add Vehicle',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isLoading ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              _buildImagePicker(),
              const SizedBox(height: 24),

              _buildSectionTitle('Vehicle Identity'),
              const SizedBox(height: 12),
              _buildField(
                controller: _plateController,
                label: 'Number Plate *',
                hint: 'e.g. ABC-1234',
                icon: Icons.pin_rounded,
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Number plate is required' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _modelController,
                label: 'Vehicle Model *',
                hint: 'e.g. Toyota HiAce',
                icon: Icons.directions_car_rounded,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Model is required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _colorController,
                      label: 'Color',
                      hint: 'e.g. White',
                      icon: Icons.palette_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _yearController,
                      label: 'Year',
                      hint: 'e.g. 2020',
                      icon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Classification'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      'Type',
                      _types,
                      _selectedType,
                      (v) => setState(() => _selectedType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      'Status',
                      _statuses,
                      _selectedStatus,
                      (v) => setState(() => _selectedStatus = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Service Info'),
              const SizedBox(height: 12),
              _buildField(
                controller: _mileageController,
                label: 'Current Mileage (km)',
                hint: 'e.g. 45000',
                icon: Icons.speed_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        color: Colors.white.withOpacity(0.4),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _lastServiceDate != null
                            ? 'Last Service: ${_lastServiceDate!.toIso8601String().split('T')[0]}'
                            : 'Last Service Date (tap to pick)',
                        style: TextStyle(
                          color: _lastServiceDate != null
                              ? Colors.white
                              : Colors.white.withOpacity(0.25),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.3),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Notes'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Additional notes about the vehicle...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedImage != null
                ? const Color(0xFF3B82F6).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: _selectedImage != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedImage!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : _existingImageUrl != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _existingImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : _imagePlaceholder(),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            color: Color(0xFF3B82F6),
            size: 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tap to add vehicle photo',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF3B82F6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.2),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.35), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1E2538),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(color: Colors.white)),
            ),
          )
          .toList(),
    );
  }
}
