import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../providers/tour_providers.dart';
import 'create_tour_screen.dart';
import 'join_tour_screen.dart';
import 'tour_dashboard_screen.dart';

class TourListScreen extends ConsumerWidget {
  const TourListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Mode'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const JoinTourScreen()),
            ),
            icon: const Icon(Icons.group_add_rounded),
            tooltip: 'Join',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CreateTourScreen()),
            ),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create',
          ),
        ],
      ),
      body: userState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Sign in to use Tour Mode.'));
          }

          final toursState = ref.watch(joinedToursProvider(user.uid));
          return toursState.when(
            data: (tours) {
              if (tours.isEmpty) {
                return const Center(
                  child: Text(
                    'No tours yet. Create a tour or join by invite code.',
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tours.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final tour = tours[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          tour.name.trim().isEmpty
                              ? 'T'
                              : tour.name.trim()[0].toUpperCase(),
                        ),
                      ),
                      title: Text(tour.name),
                      subtitle: Text(
                        'Members: ${tour.members.length} - Code: ${tour.inviteCode}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TourDashboardScreen(tourId: tour.id),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text(error.toString())),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CreateTourScreen()),
        ),
        icon: const Icon(Icons.travel_explore_rounded),
        label: const Text('Create Tour'),
      ),
    );
  }
}
