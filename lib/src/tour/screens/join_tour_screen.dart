import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../providers/tour_providers.dart';
import 'tour_dashboard_screen.dart';

class JoinTourScreen extends ConsumerStatefulWidget {
  const JoinTourScreen({super.key});

  @override
  ConsumerState<JoinTourScreen> createState() => _JoinTourScreenState();
}

class _JoinTourScreenState extends ConsumerState<JoinTourScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController(text: '0');
  bool _submitting = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Tour')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _inviteCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter invite code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your name in tour',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Your budget',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid budget';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.group_add_rounded),
                label: Text(_submitting ? 'Joining...' : 'Join Tour'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);

    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) {
        throw StateError('User not signed in.');
      }

      final repo = ref.read(tourRepositoryProvider);
      final tour = await repo.joinTourByCode(
        inviteCode: _inviteCodeController.text.trim(),
        userId: user.uid,
        name: _nameController.text.trim(),
        budget: double.parse(_budgetController.text.trim()),
      );

      ref.invalidate(joinedToursProvider(user.uid));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TourDashboardScreen(tourId: tour.id),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is FirebaseException
          ? '[${error.code}] ${error.message ?? 'Join failed'}'
          : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
