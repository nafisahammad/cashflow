import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../providers/tour_providers.dart';
import 'tour_dashboard_screen.dart';

class CreateTourScreen extends ConsumerStatefulWidget {
  const CreateTourScreen({super.key});

  @override
  ConsumerState<CreateTourScreen> createState() => _CreateTourScreenState();
}

class _CreateTourScreenState extends ConsumerState<CreateTourScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _creatorNameController = TextEditingController();
  final _budgetController = TextEditingController(text: '0');
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _prefillCreatorName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creatorNameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tour')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tour name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a tour name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _creatorNameController,
                decoration: const InputDecoration(
                  labelText: 'Your name',
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
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(_submitting ? 'Creating...' : 'Create Tour'),
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
      final tour = await repo.createTour(
        name: _nameController.text.trim(),
        createdBy: user.uid,
        creatorName: _creatorNameController.text.trim(),
        creatorBudget: double.parse(_budgetController.text.trim()),
      );

      ref.invalidate(joinedToursProvider(user.uid));

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tour created. Invite code: ${tour.inviteCode}'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TourDashboardScreen(tourId: tour.id),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _prefillCreatorName() async {
    final user = await ref.read(authStateProvider.future);
    if (!mounted || user == null) {
      return;
    }
    final display = user.displayName?.trim();
    final fallback = user.email?.split('@').first ?? 'Member';
    _creatorNameController.text = (display == null || display.isEmpty)
        ? fallback
        : display;
  }
}
