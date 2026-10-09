"""Check the native configuration required by recording, TTS, and backup."""

from pathlib import Path
import plistlib
import unittest
import xml.etree.ElementTree as ET


FRONTEND = Path(__file__).resolve().parents[1] / "frontend"
ANDROID_NAME = "{http://schemas.android.com/apk/res/android}name"


class MobileConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.manifest = ET.parse(
            FRONTEND / "android/app/src/main/AndroidManifest.xml"
        ).getroot()
        self.permissions = {
            node.get(ANDROID_NAME)
            for node in self.manifest.findall("uses-permission")
        }

    def test_android_can_request_microphone_access(self):
        self.assertIn("android.permission.RECORD_AUDIO", self.permissions)

    def test_android_release_can_connect_to_supabase(self):
        self.assertIn("android.permission.INTERNET", self.permissions)

    def test_android_can_discover_installed_tts_services(self):
        actions = {
            node.get(ANDROID_NAME)
            for node in self.manifest.findall("queries/intent/action")
        }
        self.assertIn("android.intent.action.TTS_SERVICE", actions)

    def test_ios_explains_microphone_access_before_requesting_it(self):
        with (FRONTEND / "ios/Runner/Info.plist").open("rb") as source:
            configuration = plistlib.load(source)
        self.assertTrue(configuration.get("NSMicrophoneUsageDescription"))


if __name__ == "__main__":
    unittest.main()
