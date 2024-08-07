# FirebaseChat

**FirebaseChat** is a SwiftUI application that allows users to chat with each other with functionalities including login with email/password. It integrates Firebase for authentication and data storage.

## Features

- **Email/Password Authentication**: Users can register and log in using their email and password.
- **Chat**: Users can chat with each other

## Requirements

- Xcode 13 or later
- iOS 13.0 or later
- Swift Package Manager for dependency management

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/mpaliichuk/Firebase_Chat.git
cd Firebase_Chat
```

### 2. Set Up Firebase

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Create a new project or use an existing one.
3. Add an iOS app to your Firebase project and follow the instructions to download `GoogleService-Info.plist`.
4. Add the `GoogleService-Info.plist` to your Xcode project.

Here's the updated `README.md` for installing dependencies using Swift Package Manager:

---

### 3. Install Swift Package Manager Dependencies

1. **Open your Xcode project**.

2. **Navigate to the Swift Package Manager integration:**
   
   - In Xcode, select your project in the Project Navigator.
   - Choose the project target.
   - Go to the "Package Dependencies" tab.
   - Click the "+" button to add a new package.

3. **Add Firebase SDK dependencies:**

   - For Firebase, enter the following URL:
     ```plaintext
     https://github.com/firebase/firebase-ios-sdk
     ```
   - Choose the required packages:
     - **Firestore**
     - **FirebaseAuth**
     - **FirebaseStorage**

   - Click "Add Package".

4. **Add SDWebImageSwiftUI:**

   - For SDWebImageSwiftUI, enter the following URL:
     ```plaintext
     https://github.com/SDWebImage/SDWebImageSwiftUI
     ```
   - Click "Add Package".

5. **Configure your project:**

   - Ensure that the added packages are listed in the "Package Dependencies" section of your project settings.

6. **Build your project:**

   - Xcode will fetch and integrate the packages into your project. Build your project to ensure everything is set up correctly.

## Usage

### Running the App

1. Open `Firebase_Chat.xcodeproj` in Xcode.
2. Select the target device or simulator.
3. Press the `Run` button (or `Cmd + R`) to build and run the app.

### Authentication

- **Email/Password Register**: Enter your email, password, choose profile picture after pressing on image, and press Create Account to register.
- **Email/Password Login**: Enter your email and password to log in.


### Using the app
- **Chat**: Press button "+ new message", choose existing user to start chat
