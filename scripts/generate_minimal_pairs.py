#!/usr/bin/env python3
"""
Generate minimal pairs from ipa-dict data.

ipa-dict is MIT licensed: https://github.com/open-dict-data/ipa-dict

This script:
1. Downloads ipa-dict JSON for a language
2. Extracts words with IPA transcriptions
3. Generates minimal pairs (words differing by one phoneme)
4. Outputs SQL for Supabase seed
"""

import argparse
import json
import os
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

LANGUAGE_CODES = {
    'en': 'en_US',  # Default English to General American
    'en_GB': 'en_UK',  # British English
    'en_US': 'en_US',
    'en_UK': 'en_UK',
    'fr': 'fr_FR', 
    'fr_FR': 'fr_FR',
    'fr_QC': 'fr_QC',  # Quebec French
    'ja': 'ja',
    'es': 'es_ES',
    'es_ES': 'es_ES',
    'es_MX': 'es_MX',
    'de': 'de',
    'it': 'it',
    'pt': 'pt',
    'ru': 'ru',
    'zh': 'zh',
    'ko': 'ko',
}

SOURCE_URL = "https://github.com/open-dict-data/ipa-dict/releases/download/1.0/{lang}.json.zip"

def get_parser():
    parser = argparse.ArgumentParser(description='Generate minimal pairs from ipa-dict')
    parser.add_argument('--lang', default='en', help='Language code (default: en)')
    parser.add_argument('--output', default='minimal_pairs.sql', help='Output SQL file')
    parser.add_argument('--limit', type=int, default=100, help='Max pairs to generate')
    return parser

def download_ipa_dict(lang_code):
    """Download ipa-dict JSON for given language."""
    # Map lang code to actual filename
    lang_map = {
        'en': 'en_US',  # Use en_US as default for English
        'en_GB': 'en_UK',
        'fr': 'fr_FR',
        'ja': 'ja',
        'de': 'de',
    }
    filename = lang_map.get(lang_code, lang_code)
    
    # Try releases URL first (more reliable)
    url = f"https://github.com/open-dict-data/ipa-dict/raw/refs/heads/master/data/{filename}.txt"
    
    print(f"Downloading {LANGUAGE_CODES.get(lang_code, lang_code)} data from {url}...")
    
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read().decode('utf-8')
        return data
    except Exception as e:
        print(f"Error downloading: {e}")
        return None

def parse_ipa_dict(data):
    """Parse ipa-dict format: word\tIPA"""
    words = []
    for line in data.split('\n'):
        line = line.strip()
        if not line:
            continue
        parts = line.split('\t')
        if len(parts) >= 2:
            word = parts[0].strip().lower()
            ipa = parts[1].strip()
            if word and ipa.startswith('/') and ipa.endswith('/'):
                words.append((word, ipa[1:-1]))  # Remove slashes
    return words

def generate_minimal_pairs(words, max_pairs=100):
    """Generate minimal pairs - words differing by one phoneme."""
    # Group words by length
    by_length = defaultdict(list)
    for word, ipa in words:
        by_length[len(ipa)].append((word, ipa))
    
    pairs = []
    
    # For each IPA length, find words that differ by one phoneme
    for length, ipa_list in by_length.items():
        if length < 2:
            continue
            
        # Build index of IPA -> words
        ipa_to_words = defaultdict(list)
        for word, ipa in ipa_list:
            ipa_to_words[ipa].append(word)
        
        # Compare each pair of unique IPA transcriptions
        ipas = list(ipa_to_words.keys())
        
        for i, ipa_a in enumerate(ipas):
            # Check against other IPAs for minimal pair detection
            chars_a = list(ipa_a)
            
            for ipa_b in ipas[i+1:]:
                chars_b = list(ipa_b)
                
                if len(chars_a) != len(chars_b):
                    continue
                
                # Count differences
                diff_count = sum(1 for a, b in zip(chars_a, chars_b) if a != b)
                
                if diff_count == 1:
                    # Found minimal pair
                    for word_a in ipa_to_words[ipa_a]:
                        for word_b in ipa_to_words[ipa_b]:
                            if word_a != word_b:
                                pairs.append((word_a, word_b, ipa_a, ipa_b))
                                break
                        if len(pairs) >= max_pairs:
                            break
                if len(pairs) >= max_pairs:
                    break
        if len(pairs) >= max_pairs:
            break
    
    return pairs[:max_pairs]

def generate_sql(pairs, lang_code, lang_name):
    """Generate SQL INSERT statements."""
    sql_lines = [
        f"-- Generated minimal pairs for {lang_name}",
        f"-- Source: ipa-dict (MIT licensed)",
        "",
    ]
    
    for word_a, word_b, ipa_a, ipa_b in pairs:
        # Escape single quotes
        word_a_escaped = word_a.replace("'", "''")
        word_b_escaped = word_b.replace("'", "''")
        
        sql = f"INSERT INTO public.minimal_pairs (language_id, phoneme_a_id, phoneme_b_id, word_a, word_b) VALUES ("
        
        # Note: phoneme_a_id and phoneme_b_id need to be looked up
        # This is a template - you'll need to customize
        sql += f"(SELECT id FROM public.languages WHERE code = '{lang_code}'), "
        sql += f"(SELECT id FROM public.phonemes WHERE ipa_symbol = '{ipa_a}' LIMIT 1), "
        sql += f"(SELECT id FROM public.phonemes WHERE ipa_symbol = '{ipa_b}' LIMIT 1), "
        sql += f"'{word_a_escaped}', '{word_b_escaped}'"
        sql += ");"
        
        sql_lines.append(sql)
    
    return '\n'.join(sql_lines)

def find_phoneme_id_sql(pairs):
    """Generate SQL to find/create phonemes if they don't exist."""
    sql_lines = [
        "-- Ensure phonemes exist (or create them)",
        "",
    ]
    
    all_ipas = set()
    for word_a, word_b, ipa_a, ipa_b in pairs:
        all_ipas.add(ipa_a)
        all_ipas.add(ipa_b)
    
    for ipa in sorted(all_ipas):
        sql = f"""-- Phoneme {ipa}
INSERT INTO public.phonemes (language_id, ipa_symbol, descriptor, difficulty_level)
SELECT id, '{ipa}', 'auto-generated from ipa-dict', 1
FROM public.languages 
WHERE code = 'en'
AND NOT EXISTS (SELECT 1 FROM public.phonemes WHERE ipa_symbol = '{ipa}');"""
        sql_lines.append(sql)
    
    return '\n'.join(sql_lines)

def main():
    args = get_parser().parse_args()
    
    # Download data
    data = download_ipa_dict(args.lang)
    if not data:
        print("Failed to download ipa-dict data")
        sys.exit(1)
    
    # Parse
    print(f"Parsing {args.lang} word list...")
    words = parse_ipa_dict(data)
    print(f"Found {len(words)} words with IPA")
    
    if not words:
        print("No words found in data")
        sys.exit(1)
    
    # Generate minimal pairs
    print(f"Generating minimal pairs (max {args.limit})...")
    pairs = generate_minimal_pairs(words, args.limit)
    print(f"Generated {len(pairs)} minimal pairs")
    
    if not pairs:
        print("No minimal pairs generated - try different language")
        sys.exit(1)
    
    # Output SQL
    lang_name = LANGUAGE_CODES.get(args.lang, args.lang)
    
    sql = generate_sql(pairs, args.lang, lang_name)
    find_sql = find_phoneme_id_sql(pairs)
    
    output = f"""-- Auto-generated from ipa-dict
-- License: MIT
-- Language: {lang_name}

{find_sql}

{sql}
"""
    
    with open(args.output, 'w') as f:
        f.write(output)
    
    print(f"Wrote SQL to {args.output}")
    print(f"Sample pairs:")
    for word_a, word_b, ipa_a, ipa_b in pairs[:5]:
        print(f"  {word_a} ({ipa_a}) vs {word_b} ({ipa_b})")

if __name__ == '__main__':
    main()