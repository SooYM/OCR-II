
# Medical Report Digitization App

## Overview
This project is a cross-platform application built using Flutter that allows users to digitize medical health reports. Users can either capture images of reports or upload PDF documents. The app extracts structured medical data using OCR and stores it in a cloud-based database.

## Features
- Capture medical reports via camera
- Upload PDF documents
- Optical Character Recognition (OCR)
- Structured data extraction
- Cloud storage integration with BigQuery
- User verification and editing of extracted data

## Architecture
The system follows a client-server architecture:

Frontend (Flutter App)
- Handles UI and user interaction
- Captures images and uploads PDFs
- Sends data to backend

Backend
- Processes files using OCR
- Extracts structured data
- Sends processed data to BigQuery

Database
- Google BigQuery for storing structured medical data

## Installation

### Prerequisites
- Flutter SDK installed
- Node.js or Python backend environment
- Google Cloud account

### Steps
1. Clone the repository
2. Install dependencies:
   flutter pub get
3. Run the app:
   flutter run

## Backend Setup
1. Set up Google Cloud project
2. Enable Vision API and BigQuery
3. Configure service account credentials
4. Deploy backend API

## Usage
1. Open the app
2. Upload or capture a medical report
3. Wait for OCR processing
4. Review extracted data
5. Submit to cloud storage

## Future Enhancements
- AI-based medical insights
- Integration with personal health dashboards
- Multi-language OCR support

## License
MIT License
