# StayLit

StayLit is a cross-platform (Windows/macOS) application built with Flutter that prevents your device from going to sleep, making it appear as if you're still active on communication platforms like Microsoft Teams and Zoom.

## Features

- **Keep Screen Awake**: Prevents your screen from turning off automatically
- **Simple Interface**: Easy-to-use controls for enabling/disabling the wakelock feature
- **Status Display**: Clear visual indicator of current app status

## How It Works

StayLit uses the `wakelock_plus` Flutter plugin to prevent your device's screen from turning off. By keeping the screen on, your device will not enter sleep mode, which helps maintain your "active" status in communication applications.

## Installation

Download the latest release for your platform from the Releases page.

## Building from Source

1. Make sure you have [Flutter](https://flutter.dev/docs/get-started/install) installed
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter build windows` for Windows or `flutter build macos` for macOS

## Legal Note

This app is for educational and personal use only. Using this software to misrepresent your availability status at work may violate your organization's policies. Use responsibly.
