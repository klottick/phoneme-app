import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/course/course_audio_catalog.dart';

/// Truthful per-file credits for the bundled FR-03 alpha French recordings.
///
/// Reads the pending catalogue through [courseAudioCatalogLoaderProvider] and
/// renders each reference's creator, source / audited-revision URLs, exact
/// licence and retained legal text, unchanged status and notices, plus a
/// faithful caveat where the provenance is archival. It explicitly states the
/// unverified-alpha status and keeps the app's MIT code licence separate.
///
/// Viewing credits loads only metadata and legal text from the asset bundle;
/// it never initialises or uses an audio engine.
class FrenchAudioCredits extends ConsumerStatefulWidget {
  const FrenchAudioCredits({super.key});

  @override
  ConsumerState<FrenchAudioCredits> createState() =>
      _FrenchAudioCreditsState();
}

class _FrenchAudioCreditsState extends ConsumerState<FrenchAudioCredits> {
  CourseAudioCatalog? _catalog;
  Object? _error;
  final Set<String> _showingLegal = <String>{};
  final Map<String, String> _legalText = <String, String>{};
  final Set<String> _legalError = <String>{};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _refresh();
    }
  }

  void _refresh() {
    final loader = ref.read(courseAudioCatalogLoaderProvider);
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
    loader.load().then(
      (CourseAudioCatalog catalog) {
        if (!mounted) return;
        setState(() {
          _catalog = catalog;
          _error = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _catalog = null;
          _error = error;
        });
      },
    );
  }

  void _toggleLegal(CourseAudioEntry entry) {
    final String id = entry.reference.id;
    if (_showingLegal.contains(id)) {
      setState(() {
        _showingLegal.remove(id);
      });
      return;
    }
    setState(() {
      _showingLegal.add(id);
    });
    if (_legalText.containsKey(id) || _legalError.contains(id)) return;

    final loader = ref.read(courseAudioCatalogLoaderProvider);
    loader.bundle.loadString(entry.credit.licenseTextAssetKey).then(
      (String text) {
        if (!mounted) return;
        setState(() {
          _legalText[id] = text;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _legalError.add(id);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CourseAudioCatalog? catalog = _catalog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Audio credits',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('French recordings are unverified alpha material.'),
        const SizedBox(height: 12),
        if (_error != null) ...[
          const Text('Could not load audio credits.'),
          const SizedBox(height: 8),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ] else if (catalog == null) ...[
          const Text('Loading audio credits…'),
        ] else ...catalog.entries.map(_tile),
        const SizedBox(height: 16),
        const Text('App code licence: MIT (separate from the audio credits)'),
      ],
    );
  }

  Widget _tile(CourseAudioEntry entry) {
    final CourseAudioCredit credit = entry.credit;
    final String id = entry.reference.id;
    final bool showing = _showingLegal.contains(id);

    final List<Widget> children = <Widget>[
      const SizedBox(height: 8),
      Text('Creator: ${credit.creator}'),
      const SizedBox(height: 6),
      SelectableText(credit.attribution),
      const SizedBox(height: 6),
      const Text('Source:'),
      SelectableText(credit.sourceUrl),
      const SizedBox(height: 6),
      const Text('Audited revision:'),
      SelectableText(credit.auditedRevisionUrl),
      const SizedBox(height: 6),
      Text('Licence: ${credit.licenseId}'),
      SelectableText(credit.licenseUrl),
      const SizedBox(height: 6),
      Text('Unchanged original: ${credit.unchanged ? 'yes' : 'no'}'),
      for (final String notice in credit.notices) Text('• $notice'),
      if (credit.provenanceCaveat != null) ...[
        const SizedBox(height: 6),
        Text(credit.provenanceCaveat!),
      ],
      const SizedBox(height: 8),
      if (showing) ...[
        if (_legalError.contains(id)) ...[
          const Text('Could not load licence text.'),
        ] else if (_legalText.containsKey(id)) ...[
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              child: SelectableText(_legalText[id]!),
            ),
          ),
        ] else ...[
          const Text('Loading licence text…'),
        ],
        const SizedBox(height: 8),
      ],
      TextButton(
        onPressed: () => _toggleLegal(entry),
        child: Text(showing ? 'Hide licence text' : 'View licence text'),
      ),
    ];

    return ExpansionTile(
      key: ValueKey('credit-$id'),
      initiallyExpanded: false,
      title: Text('${entry.reference.spokenText} ($id)'),
      children: children,
    );
  }
}
