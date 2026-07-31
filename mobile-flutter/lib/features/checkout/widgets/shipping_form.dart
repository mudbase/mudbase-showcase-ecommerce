import 'package:flutter/material.dart';

import '../../../models/order.dart';

class ShippingForm extends StatefulWidget {
  const ShippingForm(
      {required this.onSubmit, required this.submitting, super.key});

  final Future<void> Function(ShippingAddress address) onSubmit;
  final bool submitting;

  @override
  State<ShippingForm> createState() => _ShippingFormState();
}

class _ShippingFormState extends State<ShippingForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postalCode = TextEditingController();
  final _country = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _region.dispose();
    _postalCode.dispose();
    _country.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    return (value ?? '').trim().isEmpty ? '$label is required' : null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(
      ShippingAddress(
        fullName: _fullName.text.trim(),
        line1: _line1.text.trim(),
        line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
        city: _city.text.trim(),
        region: _region.text.trim(),
        postalCode: _postalCode.text.trim(),
        country: _country.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _fullName,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (value) => _required(value, 'Full name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _line1,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Address'),
            validator: (value) => _required(value, 'Address'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _line2,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Apartment, suite, etc. (optional)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _city,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) => _required(value, 'City'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _region,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: 'State / region'),
                  validator: (value) => _required(value, 'State / region'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _postalCode,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Postal code'),
                  validator: (value) => _required(value, 'Postal code'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _country,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'Country'),
                  validator: (value) => _required(value, 'Country'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.submitting ? null : _submit,
            child: widget.submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue to payment'),
          ),
        ],
      ),
    );
  }
}
