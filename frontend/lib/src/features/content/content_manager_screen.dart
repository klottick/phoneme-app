import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';


class CustomPhoneme {
  final String id;
  final String ipaSymbol;
  final String name;
  final String? description;
  final String? audioUrl;
  final DateTime createdAt;

  const CustomPhoneme({
    required this.id,
    required this.ipaSymbol,
    required this.name,
    this.description,
    this.audioUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ipaSymbol': ipaSymbol,
        'name': name,
        'description': description,
        'audioUrl': audioUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomPhoneme.fromJson(Map<String, dynamic> json) => CustomPhoneme(
        id: json['id'],
        ipaSymbol: json['ipaSymbol'],
        name: json['name'],
        description: json['description'],
        audioUrl: json['audioUrl'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class ContentManagerNotifier extends StateNotifier<List<CustomPhoneme>> {
  static const String _storageKey = 'custom_phonemes';

  ContentManagerNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        state = decoded.map((e) => CustomPhoneme.fromJson(e)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> addPhoneme(CustomPhoneme phoneme) async {
    state = [...state, phoneme];
    await save();
  }

  Future<void> removePhoneme(String id) async {
    state = state.where((p) => p.id != id).toList();
    await save();
  }
}

final contentManagerProvider =
    StateNotifierProvider<ContentManagerNotifier, List<CustomPhoneme>>((ref) {
  return ContentManagerNotifier();
});

class ContentManagerScreen extends ConsumerStatefulWidget {
  const ContentManagerScreen({super.key});

  @override
  ConsumerState<ContentManagerScreen> createState() => _ContentManagerScreenState();
}

class _ContentManagerScreenState extends ConsumerState<ContentManagerScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(contentManagerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final customPhonemes = ref.watch(contentManagerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Phonemes')),
      body: customPhonemes.isEmpty
          ? const Center(
              child: Text(
                'No custom phonemes added yet.\nTap + to add your first one.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: customPhonemes.length,
              itemBuilder: (context, index) {
                final phoneme = customPhonemes[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(phoneme.ipaSymbol)),
                  title: Text(phoneme.name),
                  subtitle: phoneme.description != null ? Text(phoneme.description!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deletePhoneme(phoneme.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    final ipaController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Phoneme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipaController,
              decoration: const InputDecoration(labelText: 'IPA Symbol', hintText: 'e.g., æ'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g., near-open front'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ipaController.text.isNotEmpty && nameController.text.isNotEmpty) {
                final phoneme = CustomPhoneme(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  ipaSymbol: ipaController.text,
                  name: nameController.text,
                  description: descController.text.isEmpty ? null : descController.text,
                  audioUrl: null,
                  createdAt: DateTime.now(),
                );
                ref.read(contentManagerProvider.notifier).addPhoneme(phoneme);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deletePhoneme(String id) {
    ref.read(contentManagerProvider.notifier).removePhoneme(id);
  }
}