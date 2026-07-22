import 'package:dialwave_core/dialwave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../l10n/app_localizations.dart';
import '../state/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import 'now_playing_screen.dart';

enum _SearchMode { voice, keyboard }

/// Full-screen search (not a tiny AppBar search field) — typing a station
/// name while driving is impractical, so voice is the default mode and a
/// keyboard is one tap away as a fallback, not the other way around.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _speech = stt.SpeechToText();
  final _textController = TextEditingController();
  _SearchMode _mode = _SearchMode.voice;
  bool _speechAvailable = false;
  bool _isListening = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
      // No microphone / speech engine on this device — go straight to the
      // keyboard instead of showing a dead mic button.
      if (!available) _mode = _SearchMode.keyboard;
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) => setState(() => _query = result.recognizedWords),
    );
  }

  void _setMode(_SearchMode mode) {
    if (_isListening) _toggleListening();
    setState(() => _mode = mode);
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(radioCatalogProvider).valueOrNull;
    final trimmedQuery = _query.trim();
    final results = trimmedQuery.isEmpty || catalog == null
        ? const <RadioStation>[]
        : catalog.stations.where((s) => _matches(s.name, trimmedQuery)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.searchTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_speechAvailable)
                    TextButton.icon(
                      onPressed: () => _setMode(
                        _mode == _SearchMode.voice
                            ? _SearchMode.keyboard
                            : _SearchMode.voice,
                      ),
                      icon: Icon(
                        _mode == _SearchMode.voice
                            ? Icons.keyboard_alt_outlined
                            : Icons.mic_none_rounded,
                        color: Colors.white70,
                      ),
                      label: Text(
                        _mode == _SearchMode.voice
                            ? l10n.searchKeyboardToggle
                            : l10n.searchVoiceToggle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
            if (_mode == _SearchMode.keyboard)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 22, color: Colors.white),
                  cursorColor: AppColors.accent,
                  decoration: InputDecoration(
                    hintText: l10n.searchHintTyping,
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _speechAvailable ? _toggleListening : null,
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? AppColors.accent
                              : AppColors.surfaceRaised,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isListening
                          ? l10n.searchListening
                          : (_speechAvailable
                              ? l10n.searchTapMic
                              : l10n.searchUnavailable),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    if (trimmedQuery.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          '"$trimmedQuery"',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const Divider(height: 1, color: AppColors.surfaceRaised),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        trimmedQuery.isEmpty
                            ? l10n.searchPromptEmpty
                            : l10n.searchNoResults,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final station = results[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: station.favicon.isNotEmpty
                                ? Image.network(
                                    station.favicon,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _ResultFallback(name: station.name),
                                  )
                                : _ResultFallback(name: station.name),
                          ),
                          title: Text(station.name),
                          subtitle: Text(station.countryCode),
                          onTap: () {
                            ref.read(audioHandlerProvider).playStation(station);
                            // Replace Search with Now Playing rather than
                            // pop-then-push: back from the player should
                            // return to Home, not flash Search again.
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const NowPlayingScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matches(String name, String query) =>
      _normalize(name).contains(_normalize(query));

  /// Turkish-aware casefold: strips dotted/dotless-I and other Turkish
  /// diacritics *before* any generic lowercasing, so voice recognition
  /// output, typed text, and station names all compare equal regardless
  /// of "İzmir" vs "izmir" vs "IZMIR" quirks. Dart's plain toLowerCase()
  /// turns 'İ' into a two-character "i̇" sequence, which would otherwise
  /// break substring matching.
  String _normalize(String input) {
    const charMap = {
      'İ': 'i', 'I': 'i', 'ı': 'i',
      'Ş': 's', 'ş': 's',
      'Ğ': 'g', 'ğ': 'g',
      'Ü': 'u', 'ü': 'u',
      'Ö': 'o', 'ö': 'o',
      'Ç': 'c', 'ç': 'c',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(charMap[char] ?? char.toLowerCase());
    }
    return buffer.toString();
  }
}

class _ResultFallback extends StatelessWidget {
  const _ResultFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.accent,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
