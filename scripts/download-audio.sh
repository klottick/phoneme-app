#!/bin/bash
# Audio downloader script for phoneme resources
# Run from the project root directory

set -e

AUDIO_DIR="frontend/assets/audio"
mkdir -p "$AUDIO_DIR"

echo "=== Phoneme Audio Downloader ==="
echo ""
echo "Options:"
echo "1. Download Wikipedia IPA audio (via PhoneticFlashCards)"
echo "2. Skip - use TTS only"
echo ""
read -p "Select option [1-2]: " choice

case $choice in
    1)
        echo "Cloning PhoneticFlashCards..."
        if [ ! -d "PhoneticFlashCards" ]; then
            git clone https://github.com/joshstephenson/PhoneticFlashCards.git
        fi
        
        cd PhoneticFlashCards
        echo "Downloading IPA audio files..."
        # The ripper.py script downloads Wikipedia audio
        # Run it to get audio files
        chmod +x ripper.py quiz.py
        echo "Note: Modify ripper.py to download specific languages"
        echo "Audio files will be stored in audio/ subdirectory"
        ;;
    2)
        echo "Skipping audio download. Using TTS fallback."
        ;;
esac

echo ""
echo "Done! Audio assets should be placed in: $AUDIO_DIR"
echo ""
echo "To integrate with Supabase:"
echo "1. Upload audio files to Supabase Storage bucket 'phoneme-audio'"
echo "2. Add entries to audio_assets table"
echo "3. Update audio_service.dart to use Supabase URLs"