import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';

/// Small contact form for the primary customer workflow. Advanced tax and
/// dunning fields stay in the domain repository and can be added later.
class ContactCreatePage extends ConsumerStatefulWidget {
  const ContactCreatePage({super.key});

  @override
  ConsumerState<ContactCreatePage> createState() => _ContactCreatePageState();
}

class _ContactCreatePageState extends ConsumerState<ContactCreatePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appServicesProvider)
          .kunden
          .create(
            name: _nameController.text.trim(),
            firma: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
            strasse: _streetController.text.trim(),
            plz: _postalCodeController.text.trim(),
            ort: _cityController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          );
      ref.invalidate(routeRecordsProvider('kunden'));
      if (mounted) context.go('/contacts');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Kontakt konnte nicht gespeichert werden: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 760,
      header: AppPageHeader(
        title: 'Kontakt hinzufügen',
        leading: IconButton(
          onPressed: () => context.go('/contacts'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
        ),
        showFilterToolbar: false,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            Text('Grunddaten', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Diese Angaben erscheinen in deinen Rechnungen und Belegen.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name *', hintText: 'z. B. Anna Müller'),
              textInputAction: TextInputAction.next,
              validator: (String? value) => value == null || value.trim().isEmpty ? 'Name ist erforderlich' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'Firma', hintText: 'Optional'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _streetController,
              decoration: const InputDecoration(labelText: 'Straße und Hausnummer *'),
              textInputAction: TextInputAction.next,
              validator: (String? value) => value == null || value.trim().isEmpty ? 'Straße ist erforderlich' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(labelText: 'PLZ *'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (String? value) => value == null || value.trim().isEmpty ? 'PLZ ist erforderlich' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Ort *'),
                    textInputAction: TextInputAction.next,
                    validator: (String? value) => value == null || value.trim().isEmpty ? 'Ort ist erforderlich' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-Mail', hintText: 'Optional'),
              keyboardType: TextInputType.emailAddress,
              validator: (String? value) {
                final String email = value?.trim() ?? '';
                if (email.isEmpty || email.contains('@')) return null;
                return 'Bitte eine gültige E-Mail-Adresse eingeben';
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: _saving ? null : () => context.go('/contacts'),
                  child: const Text('Abbrechen'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(_saving ? 'Wird gespeichert…' : 'Kontakt speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
