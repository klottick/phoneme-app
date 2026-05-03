import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/phoneme.dart';
import '../../core/providers/app_providers.dart';

class PhonemeSearchQuery {
  final String query;
  final Set<String> selectedCategories;
  final Set<int> selectedDifficulties;
  final bool showBookmarkedOnly;

  const PhonemeSearchQuery({
    this.query = '',
    this.selectedCategories = const {},
    this.selectedDifficulties = const {},
    this.showBookmarkedOnly = false,
  });

  PhonemeSearchQuery copyWith({
    String? query,
    Set<String>? selectedCategories,
    Set<int>? selectedDifficulties,
    bool? showBookmarkedOnly,
  }) {
    return PhonemeSearchQuery(
      query: query ?? this.query,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedDifficulties: selectedDifficulties ?? this.selectedDifficulties,
      showBookmarkedOnly: showBookmarkedOnly ?? this.showBookmarkedOnly,
    );
  }
}

class PhonemeSearchNotifier extends StateNotifier<PhonemeSearchQuery> {
  PhonemeSearchNotifier() : super(const PhonemeSearchQuery());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void toggleCategory(String category) {
    final newCategories = Set<String>.from(state.selectedCategories);
    if (newCategories.contains(category)) {
      newCategories.remove(category);
    } else {
      newCategories.add(category);
    }
    state = state.copyWith(selectedCategories: newCategories);
  }

  void toggleDifficulty(int difficulty) {
    final newDifficulties = Set<int>.from(state.selectedDifficulties);
    if (newDifficulties.contains(difficulty)) {
      newDifficulties.remove(difficulty);
    } else {
      newDifficulties.add(difficulty);
    }
    state = state.copyWith(selectedDifficulties: newDifficulties);
  }

  void toggleBookmarkedOnly() {
    state = state.copyWith(showBookmarkedOnly: !state.showBookmarkedOnly);
  }

  void clearFilters() {
    state = const PhonemeSearchQuery();
  }

  List<Phoneme> filter(List<Phoneme> phonemes) {
    var filtered = phonemes;

    if (state.query.isNotEmpty) {
      final query = state.query.toLowerCase();
      filtered = filtered.where((p) {
        return p.ipaSymbol.toLowerCase().contains(query) ||
            p.descriptor.toLowerCase().contains(query);
      }).toList();
    }

    if (state.selectedCategories.isNotEmpty) {
      filtered = filtered.where((p) {
        final category = _getCategory(p);
        return state.selectedCategories.contains(category);
      }).toList();
    }

    if (state.selectedDifficulties.isNotEmpty) {
      filtered = filtered.where((p) {
        return state.selectedDifficulties.contains(p.difficultyLevel);
      }).toList();
    }

    return filtered;
  }

  String _getCategory(Phoneme phoneme) {
    final symbol = phoneme.ipaSymbol;
    if ('aeiouæʌəɪɛɔɑ'.contains(symbol)) {
      return 'vowel';
    }
    return 'consonant';
  }
}

final phonemeSearchProvider =
    StateNotifierProvider<PhonemeSearchNotifier, PhonemeSearchQuery>((ref) {
  return PhonemeSearchNotifier();
});

class PhonemeSearchScreen extends ConsumerWidget {
  const PhonemeSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phonemes = ref.watch(phonemesProvider);
    final searchState = ref.watch(phonemeSearchProvider);
    final searchNotifier = ref.read(phonemeSearchProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Phonemes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search phonemes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchState.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => searchNotifier.setQuery(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: searchNotifier.setQuery,
            ),
          ),
          _FilterChips(searchState: searchState, searchNotifier: searchNotifier),
          Expanded(
            child: phonemes.when(
              data: (items) {
                final filtered = searchNotifier.filter(items);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No phonemes found'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final phoneme = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(phoneme.ipaSymbol)),
                      title: Text(phoneme.descriptor),
                      subtitle: Text('Level ${phoneme.difficultyLevel}'),
                      trailing: const Icon(Icons.bookmark_border),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final PhonemeSearchQuery searchState;
  final PhonemeSearchNotifier searchNotifier;

  const _FilterChips({
    required this.searchState,
    required this.searchNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Vowels'),
            selected: searchState.selectedCategories.contains('vowel'),
            onSelected: (_) => searchNotifier.toggleCategory('vowel'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Consonants'),
            selected: searchState.selectedCategories.contains('consonant'),
            onSelected: (_) => searchNotifier.toggleCategory('consonant'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Easy'),
            selected: searchState.selectedDifficulties.contains(1),
            onSelected: (_) => searchNotifier.toggleDifficulty(1),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Medium'),
            selected: searchState.selectedDifficulties.contains(2),
            onSelected: (_) => searchNotifier.toggleDifficulty(2),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Hard'),
            selected: searchState.selectedDifficulties.contains(3),
            onSelected: (_) => searchNotifier.toggleDifficulty(3),
          ),
          const SizedBox(width: 8),
          if (searchState.query.isNotEmpty ||
              searchState.selectedCategories.isNotEmpty ||
              searchState.selectedDifficulties.isNotEmpty)
            ActionChip(
              label: const Text('Clear'),
              onPressed: searchNotifier.clearFilters,
            ),
        ],
      ),
    );
  }
}