# Running SwasthiCare Android App

Complete guide to build and run the Android app on emulator or physical device.

## Prerequisites

### Required Software

1. **Android Studio** (Already installed at `/Applications/Android Studio.app`)
2. **Java JDK** (Bundled with Android Studio)
3. **Android SDK** (Installed at `~/Library/Android/sdk`)

### Verify Installation

Check if everything is set up:

```bash
# Check Android Studio Java
/Applications/Android\ Studio.app/Contents/jbr/Contents/Home/bin/java -version

# Check ADB
~/Library/Android/sdk/platform-tools/adb --version
```

## Quick Start

### Option 1: Using Android Studio (Recommended)

1. **Open Project**
   ```bash
   open -a "Android Studio" "/Users/onwords/i do coding/i do flutter coding/swastricare-mobile-swift/android"
   ```

2. **Select Device**
   - Click device dropdown in toolbar
   - Choose emulator or connected device

3. **Run**
   - Click green play button ▶️
   - Or press: `Control + R`

### Option 2: Using Command Line

1. **Navigate to Android Directory**
   ```bash
   cd "/Users/onwords/i do coding/i do flutter coding/swastricare-mobile-swift/android"
   ```

2. **Set JAVA_HOME**
   ```bash
   export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
   ```

3. **Build the App**
   ```bash
   ./gradlew assembleDebug
   ```

4. **Install on Device**
   ```bash
   ./gradlew installDebug
   ```

5. **Launch the App**
   ```bash
   ~/Library/Android/sdk/platform-tools/adb shell am start -n com.swasthicare.mobile/com.swasthicare.mobile.MainActivity
   ```

## Running on Emulator

### Start Emulator

**Using Android Studio:**
1. Open **Tools** → **Device Manager**
2. Click ▶️ on any emulator
3. Wait for emulator to boot

**Using Command Line:**
```bash
# List available emulators
~/Library/Android/sdk/emulator/emulator -list-avds

# Start specific emulator (example)
~/Library/Android/sdk/emulator/emulator -avd Pixel_9_Pro &
```

### Check Connected Devices

```bash
~/Library/Android/sdk/platform-tools/adb devices
```

Should show:
```
List of devices attached
emulator-5554	device
```

### Install and Run

```bash
cd "/Users/onwords/i do coding/i do flutter coding/swastricare-mobile-swift/android"
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

# Build and install
./gradlew installDebug

# Launch
~/Library/Android/sdk/platform-tools/adb shell am start -n com.swasthicare.mobile/com.swasthicare.mobile.MainActivity
```

## Running on Physical Device

### Enable Developer Mode

**On Android Device:**

1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. Go back to **Settings** → **System** → **Developer Options**
4. Enable **USB Debugging**

### Connect Device

1. **Connect via USB** to your Mac
2. **Accept Prompt** on device: "Allow USB debugging?"
3. **Verify Connection**
   ```bash
   ~/Library/Android/sdk/platform-tools/adb devices
   ```

Should show your device:
```
List of devices attached
1234567890ABCDEF	device
```

### Install and Run

Same commands as emulator - ADB will automatically detect the connected device.

## Build Variants

### Debug Build (Development)

```bash
./gradlew assembleDebug
```

**Output**: `app/build/outputs/apk/debug/app-debug.apk`

**Features:**
- Debuggable
- Not optimized
- Can inspect with Chrome DevTools

### Release Build (Production)

```bash
./gradlew assembleRelease
```

**Output**: `app/build/outputs/apk/release/app-release.apk`

**Features:**
- Optimized
- Minified
- Requires signing key

## Useful Commands

### View Logs

**Real-time logs:**
```bash
~/Library/Android/sdk/platform-tools/adb logcat
```

**Filter by app:**
```bash
~/Library/Android/sdk/platform-tools/adb logcat | grep "swasthi"
```

**Clear logs:**
```bash
~/Library/Android/sdk/platform-tools/adb logcat -c
```

### App Management

**Uninstall:**
```bash
~/Library/Android/sdk/platform-tools/adb uninstall com.swasthicare.mobile
```

**Clear app data:**
```bash
~/Library/Android/sdk/platform-tools/adb shell pm clear com.swasthicare.mobile
```

**Force stop:**
```bash
~/Library/Android/sdk/platform-tools/adb shell am force-stop com.swasthicare.mobile
```

### Build Commands

**Clean build:**
```bash
./gradlew clean assembleDebug
```

**Build with logs:**
```bash
./gradlew assembleDebug --info
```

**Check dependencies:**
```bash
./gradlew app:dependencies
```

**Generate signing report (for SHA-1):**
```bash
./gradlew signingReport
```

## Troubleshooting

### Java Runtime Not Found

**Error:** "Unable to locate a Java Runtime"

**Fix:**
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

Or add to `~/.zshrc`:
```bash
echo 'export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"' >> ~/.zshrc
source ~/.zshrc
```

### ADB Not Found

**Fix:**
```bash
# Add to PATH
echo 'export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"' >> ~/.zshrc
source ~/.zshrc
```

### Device Not Detected

**Fixes:**
1. Disconnect and reconnect USB cable
2. Revoke USB debugging authorizations:
   - Settings → Developer Options → Revoke USB debugging authorizations
3. Restart ADB:
   ```bash
   ~/Library/Android/sdk/platform-tools/adb kill-server
   ~/Library/Android/sdk/platform-tools/adb start-server
   ```

### Build Failed

**Check Gradle daemon:**
```bash
./gradlew --stop
./gradlew clean
./gradlew assembleDebug
```

### App Crashes on Launch

**View crash logs:**
```bash
~/Library/Android/sdk/platform-tools/adb logcat -d | grep -E "AndroidRuntime|FATAL"
```

### Emulator Won't Start

1. **Check if HAXM/Hypervisor is enabled**
2. **Restart Android Studio**
3. **Create new emulator**:
   - Tools → Device Manager → Create Device

### Space Issues

**Clean build cache:**
```bash
./gradlew clean
rm -rf ~/.gradle/caches/
```

## IDE Shortcuts

### Android Studio

- **Run**: `Control + R`
- **Debug**: `Control + D`
- **Stop**: `Command + F2`
- **Build**: `Command + F9`
- **Clean Project**: Menu → Build → Clean Project
- **Sync Gradle**: Menu → File → Sync Project with Gradle Files

## Performance Tips

### Faster Builds

1. **Enable Gradle daemon**
   - Already enabled by default

2. **Increase Gradle memory**
   - Edit `gradle.properties`:
     ```properties
     org.gradle.jvmargs=-Xmx4096m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
     ```

3. **Use build cache**
   ```properties
   org.gradle.caching=true
   ```

### Faster Emulator

1. Use **ARM64 images** for Mac M1/M2/M3
2. Allocate more **RAM**: 2048MB minimum
3. Enable **Cold Boot** for faster startup

## Project Structure

```
android/
├── app/
│   ├── build.gradle.kts          # App dependencies
│   ├── src/
│   │   └── main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/
│   │       │   └── com/swasthicare/mobile/
│   │       │       ├── MainActivity.kt
│   │       │       ├── ui/          # UI components
│   │       │       ├── data/        # Data layer
│   │       │       └── di/          # Dependency injection
│   │       └── res/                 # Resources
├── build.gradle.kts              # Root build file
├── settings.gradle.kts
└── gradle/                       # Gradle wrapper
```

## Environment Variables

Create `~/.zshrc` or `~/.bash_profile` with:

```bash
# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/tools"

# Java for Android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```

Apply changes:
```bash
source ~/.zshrc
```

## CI/CD Build Command

For automated builds:

```bash
#!/bin/bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
cd "/Users/onwords/i do coding/i do flutter coding/swastricare-mobile-swift/android"
./gradlew clean assembleRelease --no-daemon --stacktrace
```

## Next Steps

1. **Configure Google Sign-In**: See `GOOGLE_SIGNIN_SETUP.md`
2. **Test on Physical Device**: Better performance testing
3. **Generate Release Build**: For production deployment
4. **Sign APK**: Required for Play Store

## Support

- **Android Documentation**: https://developer.android.com/
- **Gradle Documentation**: https://docs.gradle.org/
- **Kotlin Documentation**: https://kotlinlang.org/docs/

---

**Last Updated**: January 11, 2026  
**App Version**: 1.0.0  
**Package**: com.swasthicare.mobile
