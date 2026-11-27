# Changelog

## 2.2.0 - 2026-11-27
- Unified Three-Tab Kiln Ceramic Architecture:
  - Streamlined the app around Acoustic Field, Sound Library, and Kiln Atelier using cotton paper (#FBF7F0) and deep indigo night ink (#0E1326) palettes with darkened WCAG AA+ accents.
  - Added dual parallel DSP audio buses separating dry stereo L/R binaural oscillators from the chamber hall reverb bus so stereo binaural separation stays unmixed.
  - Added a real Pure Ambient Wash (No Pulse) switch inside the Wash Texture drawer for sensitive listeners who want unmodulated brown/pink sound beds.
  - Localized the entire 28-piece public-domain and original chamber archive, the 7 ceramic scale members, and all safety/legal disclosures in both Simplified Chinese and English.
  - Fixed OLED Night Lamp blind touch sweep across the full 1.5-42 Hz range, sleep-timer pause/resume state recovery, live Hum Capture waveform reactivity, and single-pass 1080x1350 static PNG card export.

## 2.1.0 - 2026-11-26
- On-Device Now Playing & Resonance Postcard Export:
  - Added offline Lock Screen and Control Center transport metadata and artwork via MPNowPlayingInfoCenter and MPRemoteCommandCenter.
  - Added 1080x1350 sRGB Resonance Postcard rendering with optional Photos add-only save and system share sheet export.
  - Updated PrivacyInfo.xcprivacy to declare only CA92.1 (UserDefaults) and 35F9.1 (SystemBootTime) with zero network traffic or tracking.

## 2.0.0 - 2026-11-26
- Offline Brainwave & Chamber Sound Engine:
  - Built 44-voice physical-modeling chamber synthesizer and lock-free stereo acoustic bed covering Delta, Theta, Alpha, and Gamma frequencies.
  - Added pure Swift + Accelerate vDSP YIN hum fundamental matching strictly in RAM without audio disk writes or network calls.
  - Added Core Haptics tactile cadence feedback synchronized with frisson charge releases and band transitions.
