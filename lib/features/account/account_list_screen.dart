import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'add_account_screen.dart';
import '../dashboard/home_dashboard.dart';
import '../../main.dart'; // To access providers for now

class AccountListScreen extends ConsumerWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountDao = ref.watch(accountDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accounts),
      ),
      body: StreamBuilder(
        stream: accountDao.watchAllAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final accounts = snapshot.data ?? [];

          if (accounts.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noAccountsAdded ?? 'No accounts configured.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(account.playlistName ?? account.username),
                subtitle: Text(account.serverUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddAccountScreen(accountToEdit: account),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        accountDao.deleteAccount(account);
                        // Also wipe related DB entries for this account
                        ref.read(categoryDaoProvider).clearCategories(account.id, 'live');
                        ref.read(categoryDaoProvider).clearCategories(account.id, 'movie');
                        ref.read(streamDaoProvider).clearAllStreams(account.id);
                        ref.read(epgDaoProvider).clearPrograms(account.id);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  ref.read(activeAccountProvider.notifier).set(account);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeDashboard()),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addAccount),
      ),
    );
  }
}
