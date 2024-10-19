# CCSU Guess

CCSU Guess is an interactive geolocation-based game built with Flutter where players guess the location of images from the CCSU (Chaudhary Charan Singh University) campus. Test your knowledge of the campus while competing with other players for the highest score!

## Features

- **Interactive Gameplay**: View campus images and mark their locations on an interactive map
- **Real-time Scoring**: Earn points based on the accuracy of your guesses
- **Global Leaderboard**: Compete with other players and track your ranking
- **Time-based Challenges**: Make your guesses within a 30-second time limit
- **Progressive Difficulty**: Consecutive correct answers increase your score multiplier
- **User Authentication**: Secure login system with Firebase Authentication
- **Profile System**: Create and customize your player profile
- **Responsive Design**: Supports both portrait and landscape orientations

## Technical Stack

- **Frontend**: Flutter
- **Backend**: Firebase
  - Authentication
  - Firestore Database
  - Cloud Storage
- **Map Integration**: Flutter Map with OpenStreetMap
- **State Management**: Flutter's built-in state management
- **Additional Packages**:
  - google_fonts
  - shimmer
  - flutter_svg
  - geolocator
  - cloud_firestore
  - shared_preferences
  - flutter_map_cancellable_tile_provider

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ccsu-guess.git
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Create a new Firebase project
   - Add your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
   - Enable Authentication and Firestore in Firebase Console

4. Run the app:
```bash
flutter run
```

## Game Rules

1. Each round shows a photo from the CCSU campus
2. Players have 30 seconds to mark the location on the map
3. Points are awarded based on proximity to the actual location:
   - Within 10 meters: 1000 points
   - Within 25 meters: 750 points
   - Within 50 meters: 500 points
   - Within 100 meters: 250 points
   - Within 500 meters: 100 points
   - Beyond 500 meters: Game Over

## Project Structure

```
lib/
├── Screens/
│   ├── GameScreen.dart       # Main game interface
│   ├── home_screen.dart      # App home screen
│   ├── Leaderboard.dart      # Global rankings
│   └── login.dart            # Authentication screen
|   └── DeveloperPage.dart    # About the Developer
|   └── Signup.dart           # Register User
├── Widget/
│   └── InfoWidget.dart      # Reusable information components
└── main.dart                # App entry point
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- CCSU for providing the campus imagery
- OpenStreetMap for map data
- Flutter and Firebase teams for their excellent frameworks
- All contributors who have helped improve the game

## Contact

For questions or feedback, please open an issue in the GitHub repository or contact the development team.

---
Built with 💙 using Flutter