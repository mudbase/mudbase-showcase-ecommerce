import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json_field.dart';
import '../../core/mudbase_exception.dart';
import '../../data/repository_providers.dart';
import '../../models/product.dart';
import '../auth/auth_controller.dart';
import 'seller_controllers.dart';

/// Product images are entered as plain URLs, not uploaded - Mudbase file
/// uploads require an org owner/admin/developer *system* role, and every
/// project end-user (sellers included) is permanently a `viewer` system
/// role, so a `seller` account can never satisfy that check. See README
/// "Known limitations".
class SellerProductFormScreen extends ConsumerStatefulWidget {
  const SellerProductFormScreen({this.productId, super.key});

  /// Null for "create new product"; set for editing an existing one.
  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<SellerProductFormScreen> createState() =>
      _SellerProductFormScreenState();
}

class _SellerProductFormScreenState
    extends ConsumerState<SellerProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _compareAtPriceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _galleryControllers = <TextEditingController>[];
  bool _isActive = true;
  bool _submitting = false;
  String? _errorMessage;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    _stockController.dispose();
    for (final controller in _galleryControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefill(Product product) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = (product.priceCents / 100).toStringAsFixed(2);
    _compareAtPriceController.text = product.compareAtPriceCents == null
        ? ''
        : (product.compareAtPriceCents! / 100).toStringAsFixed(2);
    _categoryController.text = product.category ?? '';
    _imageUrlController.text = product.imageUrl ?? '';
    _stockController.text = '${product.stock}';
    _isActive = product.isActive;
    for (final url in parseJsonStringList(product.galleryJson)) {
      _galleryControllers.add(TextEditingController(text: url));
    }
  }

  int? _parsePriceToCents(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final priceCents = _parsePriceToCents(_priceController.text);
    if (priceCents == null) {
      setState(() => _errorMessage = 'Enter a valid price.');
      return;
    }
    final compareAtText = _compareAtPriceController.text.trim();
    final compareAtPriceCents =
        compareAtText.isEmpty ? null : _parsePriceToCents(compareAtText);
    if (compareAtText.isNotEmpty && compareAtPriceCents == null) {
      setState(() => _errorMessage = 'Enter a valid compare-at price.');
      return;
    }
    if (compareAtPriceCents != null && compareAtPriceCents <= priceCents) {
      setState(() =>
          _errorMessage = 'Compare-at price must be higher than the price.');
      return;
    }

    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    final token = ref.read(authControllerProvider.notifier).requireToken();
    final gallery = _galleryControllers
        .map((controller) => controller.text.trim())
        .where((url) => url.isNotEmpty)
        .toList();

    final body = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'priceCents': priceCents,
      'compareAtPriceCents': compareAtPriceCents,
      'currency': 'USD',
      'imageUrl': _imageUrlController.text.trim(),
      'galleryJson': stringifyJsonField(gallery),
      'category': _categoryController.text.trim(),
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'isActive': _isActive,
      'sellerId': user.id,
    };

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final repository = ref.read(productRepositoryProvider);
      if (widget.isEditing) {
        await repository.update(
            token: token, id: widget.productId!, body: body);
      } else {
        await repository.create(
          token: token,
          body: {...body, 'slug': slugify(_nameController.text.trim())},
        );
      }
      ref.invalidate(sellerProductsProvider);
      if (widget.isEditing) {
        ref.invalidate(sellerProductByIdProvider(widget.productId!));
      }
      if (mounted) Navigator.of(context).pop();
    } on MudbaseException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefill (mutating controllers, not calling setState) must happen
    // before the form tree below is constructed - doing it afterwards would
    // add gallery-photo rows to `_galleryControllers` too late for this
    // frame's already-built widget list, only showing up a frame later.
    if (widget.productId != null) {
      final productAsync =
          ref.watch(sellerProductByIdProvider(widget.productId!));
      final product = productAsync.valueOrNull;
      if (product != null) {
        _prefill(product);
      } else if (!_prefilled) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit product')),
          body: productAsync.hasError
              ? Center(child: Text(productAsync.error.toString()))
              : const Center(child: CircularProgressIndicator()),
        );
      }
    }

    final scaffold = Scaffold(
      appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit product' : 'Add product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Price (USD)'),
                      validator: (value) =>
                          _parsePriceToCents(value ?? '') == null
                              ? 'Required'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock'),
                      validator: (value) =>
                          int.tryParse((value ?? '').trim()) == null
                              ? 'Required'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _compareAtPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Compare-at price (USD, optional)',
                  helperText: 'Set higher than price to show a discount badge.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Main image URL',
                  helperText:
                      'Paste a hosted image URL - see "Known limitations".',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Additional photos',
                      style: Theme.of(context).textTheme.titleSmall),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _galleryControllers.add(TextEditingController()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add photo'),
                  ),
                ],
              ),
              for (var i = 0; i < _galleryControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _galleryControllers[i],
                          decoration:
                              const InputDecoration(hintText: 'https://…'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _galleryControllers[i].dispose();
                          _galleryControllers.removeAt(i);
                        }),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible in the catalog'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save product'),
              ),
            ],
          ),
        ),
      ),
    );

    return scaffold;
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
