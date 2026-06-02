MindMate

Overview

MindMate is an AI-powered mental health companion mobile application developed as a capstone project. The system helps users monitor their emotional well-being through mood tracking, journal analysis, wellness recommendations, and emergency alert notifications.

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

↓

Flutter Mobile Application

↓

Supabase Edge Function

↓

AI Services

- Hugging Face Emotion Detection Model
- OpenAI GPT-4.1 Mini

↓

Emotion Analysis and Recommendations

↓

Supabase Database

↓

Mood Tracking and Emergency Notifications

Repository Structure

mindmate-capstone/
│
├── lib/
├── android/
├── assets/
├── database/
│   ├── database.txt
│   ├── credentials.txt
│   └── schema.sql
│
├── Documentation/
│   └── AI-Documentation.txt
│
├── pubspec.yaml
└── README.md

Database

Database documentation and schema files are located in the "/database" folder.

Included files:

- database.txt
- credentials.txt
- schema.sql

Installation

1. Clone the repository.
2. Run:

flutter pub get

3. Run the application:

flutter run

Test Account

See "database/credentials.txt" for testing credentials.

Developers

Developed as a Capstone Project by the MindMate Development Team

- Jayson Regulacion - Project Leader, Frontend Developer, Backend Developer, UI/UX Designer
- Miriam Bridgette Maestre - Documentation and Testing
