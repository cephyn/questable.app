# Questable.app

Questable is an application designed to manage and explore RPG Adventures ("Quests"). This README provides instructions on how to build, deploy, and contribute to the project.

## Table of Contents

- [Build Steps](#build-steps)
- [Getting Started](#getting-started)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Assets](#assets)
- [Project Structure](#project-structure)
- [Localization](#localization)
- [Testing](#testing)
- [Contributing](#contributing)
- [Contact / Issues](#contact--issues)
- [License](#license)

## Build Steps

To build and deploy the project, follow these steps:

### Terminal

```sh
# Build the web app for production
flutter build web --no-tree-shake-icons

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Local Development

```sh
# Run the app locally with hot reload
flutter run -d chrome
```

## Getting Started

1. **Prerequisites**
   - Install [Flutter](https://flutter.dev/docs/get-started/install)
   - Install [Firebase CLI](https://firebase.google.com/docs/cli)
   - Obtain Firebase configuration files

2. **Setup**
   ```sh
   # Clone the repository
   git clone https://github.com/your-username/quest_cards.git
   
   # Install dependencies
   flutter pub get
   
   # Configure Firebase (ensure you have firebase_options.dart configured)
   firebase login
   firebase use your-project-id # Replace with your actual Firebase project ID
   ```

## Features

- **Quest Card Management**: Upload, analyze, and catalog RPG adventures
- **Firebase Integration**: Cloud storage, authentication, and Firestore database
- **AI-powered Analysis**: Automatic categorization and extraction of quest data
- **Multi-platform Support**: Web, iOS, and Android compatibility

## Technology Stack

Questable is built using the following technologies:

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Authentication, Firestore, Cloud Storage, Cloud Functions)
- **Cloud Functions Language**: Python
- **Analysis Scripts**: JavaScript (Node.js)

## Assets

The `assets` folder contains:
- Icons for different RPG systems
- App logos and images
- Theme configuration files

## Project Structure

The project is organized into the following main directories:

- `lib/`: Contains the main Flutter application code (Dart).
- `functions/`: Contains Firebase Cloud Functions code (Python).
- `analysis_scripts/`: Holds scripts for data analysis (JavaScript).
- `assets/`: Stores static assets like icons and images.
- `test/`: Contains application tests.
- `ios/`, `android/`, `web/`, `linux/`, `macos/`, `windows/`: Platform-specific code.
- `public/`: Web-specific static files like `index.html`.

## Localization

The application supports localization. To add or modify translations:

1. Update the localization files in the `lib/l10n` directory
2. Run the following command to generate the necessary files:
   ```sh
   flutter gen-l10n
   ```

## Testing

To run the automated tests:

```sh
flutter test
```

## Contributing

We welcome contributions to Questable. To contribute, follow these steps:

1. Fork the repository.
2. Create a new branch:
   ```sh
   git checkout -b feature/your-feature-name
   ```
3. Make your changes and commit them:
   ```sh
   git commit -m 'Add some feature'
   ```
4. Push to the branch:
   ```sh
   git push origin feature/your-feature-name
   ```
5. Create a pull request.

We recommend using Firebase Local Emulator Suite for local development:
https://firebase.google.com/docs/emulator-suite

### Local Emulator Setup

```sh
# Install Firebase Emulators
firebase init emulators

# Start the emulators
firebase emulators:start
```

## Contact / Issues

Please report any issues or suggest features via the [GitHub Issues](https://github.com/cephyn/quest_cards/issues) page. (Remember to replace the URL if your repository location is different).

## License

This project is licensed under the BSD-3 License - see the LICENSE file for details.