import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

import '../../models/court_date_model.dart';

/// Dialog for adding or editing court dates
class AddCourtDateDialog extends StatefulWidget {
  final CourtDateModel? existingDate;
  final Function({
    required String description,
    required DateTime courtDate,
    required CourtDateType dateType,
    String? notes,
  })
  onSave;

  const AddCourtDateDialog({
    super.key,
    this.existingDate,
    required this.onSave,
  });

  @override
  State<AddCourtDateDialog> createState() => _AddCourtDateDialogState();
}

class _AddCourtDateDialogState extends State<AddCourtDateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  CourtDateType _selectedDateType = CourtDateType.trial;

  @override
  void initState() {
    super.initState();
    if (widget.existingDate != null) {
      _descriptionController.text = widget.existingDate!.description;
      _notesController.text = widget.existingDate!.notes ?? '';
      _selectedDate = widget.existingDate!.courtDate;
      _selectedDateType = widget.existingDate!.dateType;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingDate != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? IconlyBroken.edit : IconlyBroken.plus,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(isEditing ? 'Edit Court Date' : 'Add Court Date'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Enter court date description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(IconlyBroken.document),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Date Type Dropdown
              DropdownButtonFormField<CourtDateType>(
                initialValue: _selectedDateType,
                decoration: const InputDecoration(
                  labelText: 'Date Type *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(IconlyBroken.category),
                ),
                items: CourtDateType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(CourtDateModel.getDateTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDateType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Court Date *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(IconlyBroken.calendar),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Icon(IconlyBroken.arrow_down_2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes Field
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Additional notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(IconlyBroken.edit_square),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveCourtDate,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveCourtDate() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        description: _descriptionController.text.trim(),
        courtDate: _selectedDate,
        dateType: _selectedDateType,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      Navigator.of(context).pop();
    }
  }
}
