import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ExportData {
  final DateTime exportedAt;
  final String version;
  final Map<String, dynamic> data;

  ExportData({required this.exportedAt, required this.version, required this.data});

  factory ExportData.fromJson(Map<String, dynamic> json) => ExportData(
        exportedAt: DateTime.parse(json['exportedAt'] as String),
        version: json['version'] as String,
        data: json['data'] as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
        'exportedAt': exportedAt.toIso8601String(),
        'version': version,
        'data': data,
      };
}

class DataExportService {
  DataExportService({bool? supportsNativeFileActions})
      : _supportsNativeFileActions = supportsNativeFileActions;

  final bool? _supportsNativeFileActions;

  bool get supportsFileActions => _supportsNativeFileActions ?? !kIsWeb;

  static const String _version = '1.0.0';

  Future<String> exportToJson() async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'srs': prefs.getString('srs_phonemes') ?? '',
      'achievements': prefs.getString('achievements') ?? '',
      'streak_current': prefs.getInt('streak_current') ?? 0,
      'streak_longest': prefs.getInt('streak_longest') ?? 0,
      'last_practice': prefs.getString('last_practice') ?? '',
      'total_attempts': prefs.getInt('total_attempts') ?? 0,
      'custom_phonemes': prefs.getString('custom_phonemes') ?? '',
      'selected_language': prefs.getString('selected_language') ?? 'en',
    };

    final export = ExportData(
      exportedAt: DateTime.now(),
      version: _version,
      data: data,
    );

    return jsonEncode(export.toJson());
  }

  Future<File?> exportToFile() async {
    if (!supportsFileActions) {
      throw UnsupportedError('File export is not available in this browser.');
    }
    final json = await exportToJson();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/linguist_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    return file;
  }

  Future<void> shareExport() async {
    if (!supportsFileActions) {
      throw UnsupportedError('File export is not available in this browser.');
    }
    final file = await exportToFile();
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], text: 'Linguist Progress Export');
    }
  }

  Future<Map<String, dynamic>?> importFromJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final export = ExportData.fromJson(decoded);
      return export.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> importFromData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (data['srs'] != null) {
        await prefs.setString('srs_phonemes', data['srs'] as String);
      }
      if (data['achievements'] != null) {
        await prefs.setString('achievements', data['achievements'] as String);
      }
      if (data['streak_current'] != null) {
        await prefs.setInt('streak_current', data['streak_current'] as int);
      }
      if (data['streak_longest'] != null) {
        await prefs.setInt('streak_longest', data['streak_longest'] as int);
      }
      if (data['total_attempts'] != null) {
        await prefs.setInt('total_attempts', data['total_attempts'] as int);
      }
      if (data['custom_phonemes'] != null) {
        await prefs.setString('custom_phonemes', data['custom_phonemes'] as String);
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

final nativeFileActionsAvailableProvider = Provider<bool>((ref) => !kIsWeb);
final dataExportServiceProvider = Provider<DataExportService>((ref) => DataExportService());

class DataExportNotifier extends StateNotifier<bool> {
  DataExportNotifier(this._service) : super(false);

  final DataExportService _service;

  Future<bool> export() async {
    if (state) return false;
    state = true;
    try {
      await _service.shareExport();
      return true;
    } catch (_) {
      return false;
    } finally {
      state = false;
    }
  }

  Future<bool> import(String jsonString) async {
    state = true;
    final data = await _service.importFromJson(jsonString);
    if (data != null) {
      final success = await _service.importFromData(data);
      state = false;
      return success;
    }
    state = false;
    return false;
  }
}

final dataExportProvider = StateNotifierProvider<DataExportNotifier, bool>((ref) {
  return DataExportNotifier(ref.watch(dataExportServiceProvider));
});

class DataExportScreen extends ConsumerWidget {
  const DataExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExporting = ref.watch(dataExportProvider);
    final fileActionsAvailable = ref.watch(nativeFileActionsAvailableProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Data Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Export Progress'),
              subtitle: Text(fileActionsAvailable
                  ? 'Save your learning data'
                  : 'Export is not available in this browser.'),
              trailing: isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : fileActionsAvailable
                      ? const Icon(Icons.chevron_right)
                      : const Icon(Icons.block),
              onTap: fileActionsAvailable && !isExporting ? () async {
                if (ref.read(dataExportProvider)) return;
                final success = await ref.read(dataExportProvider.notifier).export();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success
                        ? 'Export shared!'
                        : 'Export failed. Please try again.')),
                  );
                }
              } : null,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import Progress'),
              subtitle: const Text('Restore from backup'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showImportDialog(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Data Included:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const _ExportItem(icon: Icons.star, text: 'Spaced repetition progress'),
          const _ExportItem(icon: Icons.emoji_events, text: 'Achievements'),
          const _ExportItem(icon: Icons.local_fire_department, text: 'Practice streaks'),
          const _ExportItem(icon: Icons.add, text: 'Custom phonemes'),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste your export JSON here:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste JSON...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ref
                  .read(dataExportProvider.notifier)
                  .import(controller.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Import successful!' : 'Import failed'),
                ),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}

class _ExportItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExportItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}