# MedGemma 1.5 Integration Guide

## Overview

This guide covers integrating Google's MedGemma medical AI models into Swastricare iOS app.

## Models Used

- **MedGemma 27B**: Text-only model for medical conversations and health analysis
- **MedGemma 4B**: Multimodal model for medical image analysis (X-rays, prescriptions, lab reports)

## Google Cloud Setup

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Note your Project ID

### Step 2: Enable Vertex AI API

1. Go to APIs & Services > Library
2. Search for "Vertex AI API"
3. Click Enable
4. Wait for activation (may take a few minutes)

### Step 3: Enable Model Garden

1. Go to Vertex AI > Model Garden
2. Search for "MedGemma"
3. Enable both models:
   - MedGemma 27B (text)
   - MedGemma 4B (multimodal)
4. Accept terms of service for medical AI models

### Step 4: Create Service Account

1. Go to IAM & Admin > Service Accounts
2. Click "Create Service Account"
3. Name: `swastricare-medgemma`
4. Grant roles:
   - Vertex AI User
   - Vertex AI Service Agent
5. Create and download JSON key file

### Step 5: Get API Credentials

Option A: API Key (simpler)
1. Go to APIs & Services > Credentials
2. Create API Key
3. Restrict to Vertex AI API

Option B: Service Account (more secure)
1. Use the JSON key file from Step 4
2. Set up authentication in Supabase Edge Functions

### Step 6: Configure Supabase Secrets

Add these secrets in Supabase Dashboard > Settings > Edge Functions:

```
GOOGLE_VERTEX_AI_PROJECT_ID=your-project-id
GOOGLE_VERTEX_AI_LOCATION=us-central1
MEDGEMMA_API_KEY=your-api-key
```

## API Endpoints

### MedGemma 27B (Text)
```
POST https://{LOCATION}-aiplatform.googleapis.com/v1/projects/{PROJECT_ID}/locations/{LOCATION}/publishers/google/models/medgemma-27b:generateContent
```

### MedGemma 4B (Multimodal)
```
POST https://{LOCATION}-aiplatform.googleapis.com/v1/projects/{PROJECT_ID}/locations/{LOCATION}/publishers/google/models/medgemma-4b:generateContent
```

## Supabase Functions

### ai-router
Routes requests to appropriate AI model:
- General questions → Gemini 3 Flash
- Medical questions → MedGemma 27B
- Image analysis → MedGemma 4B

### medgemma-chat
Handles MedGemma 27B text conversations for:
- Symptom analysis
- Medication questions
- Health condition queries
- Medical term explanations

### medgemma-vision
Handles MedGemma 4B image analysis for:
- Prescription reading
- Lab report interpretation
- Medical document OCR
- X-ray/scan analysis (basic)

## iOS Integration

### AIService Methods
- `sendMedicalQuery()`: Routes medical questions to MedGemma
- `analyzeMedicalImage()`: Sends images to MedGemma 4B
- `analyzeHealth()`: Uses MedGemma for comprehensive analysis

### Message Classification
Keywords that trigger MedGemma:
- symptoms, pain, ache, hurt
- medication, medicine, drug, prescription
- diagnosis, condition, disease, illness
- treatment, therapy, doctor, hospital
- blood pressure, heart rate, glucose, cholesterol

## Safety Features

### Medical Disclaimers
- All MedGemma responses include disclaimer
- "This is not medical advice. Consult a healthcare professional."
- User must acknowledge on first use

### Emergency Detection
Triggers immediate emergency prompt for:
- Chest pain
- Difficulty breathing
- Stroke symptoms (FAST)
- Severe bleeding
- Loss of consciousness

### Content Filtering
- No specific drug dosages without prescription context
- No dangerous self-treatment advice
- Redirects to emergency services when appropriate

## Testing Checklist

### Backend Setup
- [ ] Google Cloud Project created
- [ ] Vertex AI API enabled
- [ ] MedGemma 27B and 4B models enabled in Model Garden
- [ ] API key/service account created
- [ ] Supabase secrets configured:
  - [ ] GOOGLE_VERTEX_AI_PROJECT_ID
  - [ ] GOOGLE_VERTEX_AI_LOCATION
  - [ ] MEDGEMMA_API_KEY

### Supabase Functions
- [ ] ai-router deployed and responding
- [ ] medgemma-chat deployed and responding
- [ ] medgemma-vision deployed and responding
- [ ] Fallback to Gemini working when MedGemma unavailable

### iOS Integration
- [ ] AIService sendSmartMessage() working
- [ ] AIService sendMedicalQuery() working
- [ ] AIService analyzeMedicalImage() working
- [ ] Medical keyword detection working
- [ ] Emergency keyword detection working

### UI Components
- [ ] Medical AI badge showing in toolbar
- [ ] Medical disclaimer banner showing after medical response
- [ ] Image upload button working
- [ ] Image type selection sheet working
- [ ] Medical disclaimer sheet showing on first medical query
- [ ] Emergency alert sheet showing for emergency keywords

### Safety Features
- [ ] Emergency detection triggers alert
- [ ] 911 call button working
- [ ] Medical disclaimers appearing on all medical responses
- [ ] Content filtering for dangerous requests

### Database
- [ ] ai_medical_interactions table created
- [ ] ai_medical_consent table created
- [ ] Medical interactions being logged
- [ ] RLS policies working

## Test Scenarios

### Test 1: General Chat (Should use Gemini)
Query: "What's the weather like today?"
Expected: Routes to Gemini, no medical badge

### Test 2: Medical Question (Should use MedGemma)
Query: "I have a headache and fever, what could it be?"
Expected: Routes to MedGemma 27B, medical badge shows, disclaimer appears

### Test 3: Emergency Detection
Query: "I'm having severe chest pain"
Expected: Emergency alert shows, 911 button available

### Test 4: Image Analysis
Action: Upload prescription image
Expected: Routes to MedGemma 4B, extracts medication info

### Test 5: Fallback Scenario
Action: Disable MedGemma API key, send medical query
Expected: Falls back to Gemini with medical prompt, note shown

### Test 6: First-Time Medical Query
Action: Clear app data, send medical query
Expected: Medical disclaimer sheet appears before processing

## Cost Estimates

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| Gemini 3 Flash | $0.075 | $0.30 |
| MedGemma 27B | Check Vertex AI pricing | Check Vertex AI pricing |
| MedGemma 4B | Check Vertex AI pricing | Check Vertex AI pricing |

Note: MedGemma may have free tier for development. Check current pricing at:
https://cloud.google.com/vertex-ai/pricing

## Troubleshooting

### "Model not found" error
- Ensure MedGemma is enabled in Model Garden
- Check region matches (us-central1 recommended)

### "Permission denied" error
- Verify service account has correct roles
- Check API key restrictions

### Slow response times
- MedGemma 27B is larger, expect 3-5s response
- Consider using 4B for simpler queries

### Image analysis fails
- Ensure base64 encoding is correct
- Check image size limits (max 20MB)
- Supported formats: JPEG, PNG, WebP
