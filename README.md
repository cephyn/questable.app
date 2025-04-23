# Questable.app

Questable is an application designed to manage and explore RPG Adventures ("Quests"). This README provides instructions on how to build, deploy, and contribute to the project.

## Table of Contents

- [Build Steps](#build-steps)
- [Getting Started](#getting-started)
- [Features](#features)
- [Assets](#assets)
- [Localization](#localization)
- [Contributing](#contributing)
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
   
   # Configure Firebase
   firebase login
   firebase use your-project-id
   ```

## Features

- **Quest Card Management**: Upload, analyze, and catalog RPG adventures
- **Firebase Integration**: Cloud storage, authentication, and Firestore database
- **AI-powered Analysis**: Automatic categorization and extraction of quest data
- **Multi-platform Support**: Web, iOS, and Android compatibility

## Assets

The `assets` folder contains:
- Icons for different RPG systems
- App logos and images
- Theme configuration files

## Localization

The application supports localization. To add or modify translations:

1. Update the localization files in the `lib/l10n` directory
2. Run the following command to generate the necessary files:
   ```sh
   flutter gen-l10n
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

## License

This project is licensed under the BSD-3 License - see the LICENSE file for details.