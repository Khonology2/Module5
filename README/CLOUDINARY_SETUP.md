# Cloudinary Setup Guide

## 🚀 Quick Setup (5 minutes)

### 1. Create Cloudinary Account
1. Go to [cloudinary.com](https://cloudinary.com)
2. Sign up for a **FREE** account
3. Verify your email

### 2. Get Your Credentials
1. Go to your [Cloudinary Dashboard](https://console.cloudinary.com)
2. Copy these values from the dashboard:
   - **Cloud Name** (e.g., `my-cloud-name`)
   - **API Key** (e.g., `123456789012345`)
   - **API Secret** (e.g., `abcdefghijklmnopqrstuvwxyz123456`)

### 3. Create Upload Preset
1. In your Cloudinary dashboard, go to **Settings** → **Upload**
2. Scroll down to **Upload presets**
3. Click **Add upload preset**
4. Set these values:
   - **Preset name**: `evidence_upload` (or any name you prefer)
   - **Signing Mode**: `Unsigned` (this allows uploads without API secret)
   - **Folder**: `evidence` (optional, for organization)
   - **Tags**: `evidence,goal` (optional, for organization)
5. Click **Save**

### 4. Update Your Code
Open `lib/services/cloudinary_service.dart` and replace these values:

```dart
static const String _cloudName = 'your_cloud_name'; // Replace with your cloud name
static const String _apiKey = 'your_api_key'; // Replace with your API key  
static const String _apiSecret = 'your_api_secret'; // Replace with your API secret
static const String _uploadPreset = 'your_upload_preset'; // Replace with your upload preset name
```

**Example:**
```dart
static const String _cloudName = 'my-company-pdh';
static const String _apiKey = '123456789012345';
static const String _apiSecret = 'abcdefghijklmnopqrstuvwxyz123456';
static const String _uploadPreset = 'evidence_upload';
```

## 🎯 What You Get

### ✅ Free Tier Benefits:
- **25 GB storage**
- **25 GB bandwidth per month**
- **25,000 transformations per month**
- **Unlimited uploads**
- **Global CDN delivery**

### 🔒 Security Features:
- **Signed uploads** (optional)
- **Access control**
- **File type restrictions**
- **Size limits**

### 📱 Perfect for Your App:
- **File uploads** for evidence
- **Image optimization** (automatic)
- **PDF storage** (perfect for your use case)
- **Direct URLs** for easy access

## 🧪 Test Your Setup

1. **Update the credentials** in `cloudinary_service.dart`
2. **Run your app**: `flutter run -d chrome`
3. **Go to PDP screen** and try uploading a file
4. **Check the console** for upload success messages
5. **Verify in Cloudinary dashboard** that files appear

## 🔧 Troubleshooting

### Common Issues:

**"Upload failed: 401"**
- Check your API key and secret
- Make sure upload preset is set to "Unsigned"

**"Upload failed: 400"**
- Check your cloud name
- Verify upload preset name matches exactly

**"File not appearing"**
- Check the folder structure in Cloudinary dashboard
- Verify the public_id format

### Need Help?
- [Cloudinary Documentation](https://cloudinary.com/documentation)
- [Flutter Integration Guide](https://cloudinary.com/documentation/flutter_integration)
- [Upload Presets Guide](https://cloudinary.com/documentation/upload_presets)

## 🎉 You're Done!

Once configured, your app will:
- ✅ Upload files to Cloudinary
- ✅ Store file URLs in your database
- ✅ Display evidence in the UI
- ✅ Work without Firebase Storage upgrade

**No more Firebase Storage upgrade needed!** 🚀
