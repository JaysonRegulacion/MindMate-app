MindMate

Overview

MindMate is an AI-powered mental health companion mobile application developed as a capstone project. The system helps users monitor their emotional well-being through mood tracking, journal analysis, personalized wellness recommendations, and emergency alert notifications.

Features

- User Authentication using Supabase Auth
- AI-powered Emotion Detection
- Journal Entry Management
- Mood Tracking and History
- Personalized Wellness Recommendations
- Emergency Contact Alert System
- SMS Notification Integration
- User Profile Management

Technologies Used

Frontend

- Flutter
- Dart

Backend & Database

- Supabase
- Supabase Auth
- Supabase Storage
- Supabase Edge Functions

Artificial Intelligence

Emotion Detection

- Provider: Hugging Face Inference API
- Model: j-hartmann/emotion-english-distilroberta-base

Conversational AI and Wellness Recommendations

- Provider: OpenAI
- Model: GPT-4.1 Mini

Notifications

- SMS API Integration

AI Architecture

User Journal Entry / Chat Message
          │
          ▼
Flutter Mobile Application
          │
          ▼
Supabase Edge Functions
          │
          ├── Hugging Face Emotion Detection
          │
          └── OpenAI GPT-4.1 Mini
          │
          ▼
Emotion Analysis & AI Response
          │
          ▼
Supabase Database
          │
          ▼
Mood Tracking & Emergency Notifications

Documentation

Project documentation is located in the "documentation/" folder.

Included files:

- MindMate_User_Manual.pdf
- AI_Setup_Guide.md

The AI Setup Guide contains:

- OpenAI API configuration
- Hugging Face API configuration
- Supabase Secret setup
- Edge Function deployment
- AI integration and rebuilding instructions

Database

Database files are located in the "database/" folder.

Included files:

- database.txt
- credentials.txt
- schema.sql

Releases

The compiled Android application (APK) is available in the repository's Releases section.

Current Release:

- v1.0.0 – Initial APK Release
- Asset: MindMate.apk

Repository Structure

MindMate-app/
│
├── lib/
├── android/
├── assets/
│
├── database/
│   ├── database.txt
│   ├── credentials.txt
│   └── schema.sql
│
├── documentation/
│   ├── MindMate-User Manual.pdf
│   └── AI_Setup_Guide.md
│
├── pubspec.yaml
└── README.md

Installation

1. Clone the repository.

git clone <repository-url>

2. Install dependencies.

flutter pub get

3. Configure Supabase credentials.

4. Configure AI credentials following:

documentation/AI_Setup_Guide.md

5. Run the application.

flutter run

Test Account

See:

database/credentials.txt

for testing credentials.

Developers

Developed as a Capstone Project by the MindMate Development Team.

Name| Role
Jayson Regulacion| Project Leader, Frontend Developer, Backend Developer, UI/UX Designer
Miriam Bridgette Maestre| Documentation and Testing
