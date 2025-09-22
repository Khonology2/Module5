# Khono - Demy Personal Development Hub

A Flutter application designed to help users achieve their personal development goals through organization, knowledge acquisition, and mindful habits.

## Project Overview
The Personal Development Hub (PDH) is a comprehensive Flutter-based mobile application meticulously crafted to empower individuals in their journey of self-improvement. By integrating robust goal-setting tools, performance visualization, and an intelligent AI chatbot, PDH provides a holistic platform for users to define, track, and achieve their personal and professional aspirations. The app aims to foster a proactive approach to development through insightful analytics, timely nudges, and personalized AI guidance.

## Features

- **Dynamic Landing Screen**: A welcoming initial screen featuring a dynamic background image, an animated display of inspirational lines, and a clear call to action to sign in.
- **User-Friendly Sign-In & Registration**: Dedicated interfaces with modern aesthetics, blurred text fields, and clear input prompts for seamless user authentication.
- **Customizable Backgrounds**: Distinct background images for key screens to provide a unique and engaging visual experience.
- **Intuitive Navigation**: Seamless and efficient navigation between various screens and functionalities within the application.
- **Employee Portal & Dashboard**: A centralized hub offering an overview of active goals, completed tasks, earned points, and recent activity, providing quick insights into personal progress.
- **My Personal Development Plan (PDP)**: A structured section to define and manage personal development goals and milestones, categorized for clarity and actionable planning.
- **Personal Development Goal Creation**: A detailed form to create new goals, including fields for title, description, start/target dates, categories, status, SMART criteria verification, dependencies, and success metrics.
- **Progress Visuals**: Graphical representations of progress through burn-down/burn-up charts, time to due, current streaks, and individual goal progress, aiding in performance tracking.
- **Alerts & Nudges**: AI-powered smart alerts providing personalized reminders, tips, and notifications based on user habits and goals, fostering consistent engagement.
- **Badges & Points System**: A gamified approach to motivation, where users earn points and badges for achieving milestones and completing challenges, promoting continuous effort.
- **Leaderboard**: A competitive yet motivational feature displaying top performers based on points and streaks, encouraging healthy competition.
- **Repository & Audit**: An archive for completed goals with evidence and documentation, allowing for review and acknowledgment, ensuring accountability and recognition.
- **Settings & Privacy**: User-controlled settings including profile updates, password reset options, and privacy controls like leaderboard participation, giving users full autonomy.
- **AI Chatbot (KhonoPal)**:
  - **Multi-Mode Interaction**: Engage with the AI in different contexts (e.g., Dashboard Mode, Progress Visuals Mode, General Chat) to get tailored advice and insights.
  - **Persistent Chat History**: All conversations with KhonoPal are saved locally using `shared_preferences`, ensuring chat history is retained even after closing the app or logging out.
  - **Clear Chat History**: Option to clear all chat messages while preserving the initial AI greeting, allowing users to start fresh without losing the introductory context.
  - **Typewriter Effect**: AI responses are delivered with a subtle typewriter animation for a more engaging user experience.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

Ensure you have Flutter installed. If not, follow the official Flutter installation guide:

*   [Flutter Installation Guide](https://flutter.dev/docs/get-started/install)
*   **Firebase Project**: A Firebase project is required for authentication and potentially other backend services. Set up your project and link it to your Flutter app.
    - Follow the official Firebase setup guide for Flutter: [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)
    - Ensure `firebase_options.dart` is correctly configured in your project.

### Installing

1.  **Clone the repository:**

    ```bash
    git clone <repository-url>
    cd Personal-Development-Hub-Android_Build
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Ensure assets are available:**

    Make sure all necessary background images and other assets are in the `assets/` directory and listed in `pubspec.yaml`:

    ```yaml
    flutter:
      uses-material-design: true
      assets:
        - assets/landing_screen.jpg
        - assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_0e1e972b-4933-4004-94fa-23e1d21d8be7.png
        - assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_1b482d56-7423-46ca-8b2d-ea094e0e91f6.png
        - assets/videos/chat_bot_animation-vmake.mp4
        - assets/Send_Paper Plane/Send_Plane_Red Badge_White.png
        - assets/20250919_1708_Futuristic Red Tech Design_remix_01k5h86tdef65aerhqpqthxd5d.png
    ```

    (Note: `flutter pub get` should automatically pick up changes to `pubspec.yaml`, but a full restart of your IDE or `flutter clean` might be necessary if assets are not loading.)

## Running the App

To run the app on an attached device or emulator:

```bash
flutter run
```

## Technologies Used

- **Flutter**: UI Toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
- **Firebase Authentication**: For user sign-in and registration.
- **Firebase AI (Google AI)**: Powers the intelligent KhonoPal chatbot using the `gemini-2.5-flash` model.
- **Cloud Firestore**: Potentially used for storing user profiles, goals, and other application data.
- **shared_preferences**: For local data persistence, specifically chat history.
- **video_player**: For playing background videos, such as the chatbot animation.

## Future Enhancements

- Implement comprehensive backend services for real-time goal tracking and data synchronization.
- Expand AI capabilities with more personalized coaching and predictive analytics.
- Introduce community features for shared goals and challenges.
- Develop a web version of the application.

## Screenshots

### Employee Portal

![Employee Portal](flutter_01.png)

### Employee Dashboard

![Employee Dashboard](flutter_02.png)

### My Personal Development Plan

![My Personal Development Plan](flutter_03.png)

### Personal Development Goal - Goal Information

![Personal Development Goal - Goal Information](flutter_04.png)

### Personal Development Goal - SMART Criteria Verification

![Personal Development Goal - SMART Criteria Verification](flutter_05.png)

### Progress Visuals

![Progress Visuals](flutter_06.png)

### Alerts & Nudges

![Alerts & Nudges](flutter_07.png)

### Badges & Points - Overview

![Badges & Points - Overview](flutter_08.png)

### Badges & Points - Recent Celebrations and AI Smart Alerts

![Badges & Points - Recent Celebrations and AI Smart Alerts](flutter_09.png)

### Leaderboard

![Leaderboard](flutter_10.png)

### Repository & Audit - Completed Goals Archive

![Repository & Audit - Completed Goals Archive](flutter_11.png)

### Repository & Audit - Employee Portal Navigation

![Repository & Audit - Employee Portal Navigation](flutter_12.png)

### Settings - Employee Settings

![Settings - Employee Settings](flutter_13.png)

### Settings - Employee Portal Navigation

![Settings - Employee Portal Navigation](flutter_14.png)

### AI Chatbot - Initial Greeting

![AI Chatbot - Initial Greeting](flutter_15.png)

### AI Chatbot - Mode Selection

![AI Chatbot - Mode Selection](flutter_16.png)

### AI Chatbot - Proofreading Toggle

![AI Chatbot - Proofreading Toggle](flutter_17.png)