# Open Source Phoneme Audio Resources

This document evaluates open source options for phoneme audio files suitable for a language learning app.

## Summary Table

| Resource | Type | Languages | License | Audio Format | Notes |
|----------|------|-----------|---------|--------------|-------|
| Freesound IPA Vowels | Audio | IPA symbols | WAV | CC0 | Requires login |
| Freesound IPA Pulmonic Consonants | Audio | IPA symbols | WAV | CC0 | Requires login |
| PhoneticFlashCards | Code + Audio | IPA symbols | MP3 (Wikipedia) | CC BY-SA 3.0 | Downloads from Wikipedia |
| ipa-dict | Text Data | 30+ languages | MIT | JSON/CSV/XML | IPA transcriptions only |
| neurlang/dataset | Text Data | 140+ languages | MIT/CC0 | TSV | IPA word pairs |
| pronounce.how | Text Data | English (US/UK/CA/AU) | JSON | CC BY-SA 4.0 | Regional variants |

## Detailed Evaluation

### 1. Freesound.org IPA Packs

**URLs:**
- IPA Vowels: https://freesound.org/people/ipapronunciations/packs/35567/
- IPA Pulmonic Consonants: https://freesound.org/people/ipapronunciations/packs/35572/

**Pros:**
- Individual phoneme recordings as separate .wav files
- Direct matches for IPA symbols (e.g., `[ə] - Schwa.wav`)
- Searchable and browsable

**Cons:**
- Requires Freesound account to download
- Some files may have different licenses (check per-file)

**Integration:**
- Download manually or use Freesound API
- Store in Supabase `phoneme-audio` bucket

### 2. PhoneticFlashCards

**GitHub:** https://github.com/joshstephenson/PhoneticFlashCards

**License:** Uses Wikipedia audio under CC BY-SA 3.0

**Pros:**
- Already has Python script to download IPA audio
- Uses Wikipedia's embedded IPA audio files
- Includes annotation data (manner, place, roundness)

**Files:**
- `quiz.py` - main quiz script
- `ripper.py` - downloads Wikipedia audio files

**Integration:**
```bash
git clone https://github.com/joshstephenson/PhoneticFlashCards.git
cd PhoneticFlashCards
chmod u+x quiz.py
# Run to study, or modify ripper.py to download specific languages
```

### 3. ipa-dict

**GitHub:** https://github.com/open-dict-data/ipa-dict

**License:** MIT

**Pros:**
- Large vocabulary with IPA transcriptions
- Available in JSON/CSV/XML formats
- Covers 30+ languages

**Cons:**
- Text only, no audio files
- Need to combine with TTS or external audio

**For your app:**
- Use as source of word pairs for minimal pairs
- Cross-reference with TTS for audio

### 4. neurlang/dataset

**GitHub:** https://github.com/neurlang/dataset

**License:** MIT (original languages), CC0 (generated)

**Pros:**
- 140+ languages in TSV format
- Word → IPA mappings
- Simple format easy to parse

**For your app:**
- Generate minimal pairs programmatically
- Cross-reference with TTS for pronunciations

### 5. pronounce.how

**GitHub:** https://github.com/PronounceHow/pronounce.how

**License:** CC BY-SA 4.0

**Pros:**
- 34,805 English words
- Regional variants (US, UK, CA, AU)
- ARPAbet + IPA + syllables

**For your app:**
- Best for English-specific vocabulary
- Use with TTS for audio

## Recommendation

For your MVP, the best approach:

1. **Use TTS as primary** (already wired in via `flutter_tts`)
2. **Add Wikipedia audio** via PhoneticFlashCards `ripper.py` for enrichment
3. **Use ipa-dict or neurlang** for generating word lists programmatically

### Quick Start: Download IPA Audio from Wikipedia

```bash
# Clone PhoneticFlashCards
git clone https://github.com/joshstephenson/PhoneticFlashCards.git

# Run the quiz (optional) to study
cd PhoneticFlashCards
python3 quiz.py

# Or modify ripper.py to download audio files
# See: https://github.com/joshstephenson/PhoneticFlashCards/blob/main/ripper.py
```

## Legal Considerations

- **MIT / CC0** : Safe to use, modify, and redistribute
- **CC BY-SA 3.0/4.0** : Must attribute and share alike
- **Freesound** : Check individual file licenses

For a commercial app, prefer MIT/CC0 licensed resources. The Freesound packs appear to be CC0 but verify on download. Wikipedia audio is CC BY-SA 3.0 which requires share-alike.

## Next Steps

1. Clone PhoneticFlashCards and run `ripper.py` to download Wikipedia IPA audio
2. Upload audio files to Supabase Storage bucket `phoneme-audio`
3. Update `audio_assets` table with file paths
4. Wire URLs into `AudioService` for real playback