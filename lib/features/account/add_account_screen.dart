import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import '../../main.dart';
import '../../core/database/app_database.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  final Account? accountToEdit;
  const AddAccountScreen({super.key, this.accountToEdit});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playlistNameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.accountToEdit != null) {
      _playlistNameController.text = widget.accountToEdit!.playlistName ?? '';
      _serverUrlController.text = widget.accountToEdit!.serverUrl;
      _usernameController.text = widget.accountToEdit!.username;
      _passwordController.text = widget.accountToEdit!.password;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final dao = ref.read(accountDaoProvider);
      if (widget.accountToEdit != null) {
        await dao.updateAccount(
          widget.accountToEdit!.copyWith(
            playlistName: drift.Value(_playlistNameController.text.trim().isEmpty ? null : _playlistNameController.text.trim()),
            serverUrl: _serverUrlController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
          )
        );
      } else {
        await dao.insertAccount(
          AccountsCompanion.insert(
            playlistName: drift.Value(_playlistNameController.text.trim().isEmpty ? null : _playlistNameController.text.trim()),
            serverUrl: _serverUrlController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.error}$e')),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountToEdit == null ? l10n.addAccount : l10n.editAccount),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _playlistNameController,
                    decoration: InputDecoration(
                      labelText: l10n.playlistName,
                      hintText: 'My IPTV',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _serverUrlController,
                    decoration: InputDecoration(
                      labelText: l10n.serverUrl,
                      hintText: 'http://example.com:8080',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text(l10n.login),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
