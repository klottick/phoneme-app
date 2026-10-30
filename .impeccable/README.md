# Impeccable project context

[PRODUCT.md](../PRODUCT.md) contains the confirmed product record. Space exploration
is the correct overarching identity, reaffirmed by the user on 2026-10-30.
Refinements must extend that identity rather than replacing it. Existing visual
authority is linked from the product record; init does not create DESIGN.md.

The user chose image composition first for future landing pages and showcase
surfaces (`buildPath: comp`). App screens and documents remain code first. Web and
native iOS/Android have equal priority.

The app uses Flutter. Impeccable's HTML/CSS live variants and DOM detector do not
fully inspect or edit the canvas-rendered Dart UI. Use rendered screenshots,
source, Flutter semantics/widget tests and real-device checks as appropriate.
A zero-findings DOM scan is not a clean bill of health for this interface. No
HTML live-editing configuration or production-page injection is installed by init.
