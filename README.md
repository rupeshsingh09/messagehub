# 🚀 MessageHub – Real-time Chat Application

MessageHub is a full-stack real-time chat application built using **Flutter (Frontend)** and **Node.js + Express + MongoDB (Backend)**.
It supports real-time messaging, contact-based user discovery, and a scalable chat architecture similar to modern messaging apps.

---

## 📱 Features

* 🔐 **User Authentication**

  * Signup & Login using phone number
  * Auto-login with local storage
  * Logout functionality

* 💬 **Real-time Chat**

  * Send & receive messages instantly using Socket.IO
  * One-to-one messaging support

* 📇 **Smart Contact Sync**
* 

  * Fetch only users from your phone contacts
  * Show only registered users

* 📡 **Backend API**

  * RESTful APIs for users & messages
  * MongoDB database integration

* 🔔 **Push Notifications (Optional)**

  * Firebase Cloud Messaging (FCM) support

---

## 🛠️ Tech Stack

### 📱 Frontend (Flutter)

* Flutter (Dart)
* Provider (State Management)
* HTTP package
* Socket.IO Client
* SharedPreferences
* Contacts access

### 🌐 Backend (Node.js)

* Node.js
* Express.js
* MongoDB + Mongoose
* Socket.IO
* CORS & Middleware

---

## 📂 Project Structure

```
messagehub/
│
├── chatapp_backend/
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   ├── middleware/
│   ├── socket/
│   └── server.js
│
├── flutter_app/
│   ├── lib/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── models/
│   │   └── providers/
│
└── README.md
```

---

## ⚙️ Setup Instructions

### 🔹 Backend Setup

1. Go to backend folder:

```bash
cd chatapp_backend
```

2. Install dependencies:

```bash
npm install
```

3. Create `.env` file:

```
PORT=5000
MONGO_URI=your_mongodb_connection
```

4. Run server:

```bash
npm start
```

---

### 🔹 Frontend Setup (Flutter)

1. Go to Flutter project:

```bash
cd flutter_app
```

2. Install packages:

```bash
flutter pub get
```

3. Update API URL:

For Emulator:

```dart
http://10.0.2.2:5000
```

For Real Device:

```dart
http://192.168.X.X:5000
```

4. Run app:

```bash
flutter run
```

---

## 🔐 Authentication Flow

* **Signup** → Creates new user
* **Login** → Fetch existing user
* **No duplicate users created**

---

## 📡 API Endpoints

### User APIs

* `POST /api/users/signup`
* `POST /api/users/login`
* `GET /api/users`
* `POST /api/users/match-contacts`

### Message APIs

* `POST /api/messages/send`
* `GET /api/messages/:sender/:receiver`

---

## 🔄 Real-time Communication

* Uses **Socket.IO**
* Events:

  * `join`
  * `send_message`
  * `receive_message`

---

## 📸 Screenshots

(Add your app screenshots here)

---

## 🚧 Future Improvements

* 🔐 OTP Authentication
* 🟢 Online/Offline Status
* 🖼️ Profile Image Upload
* 📁 Media Sharing
* 🌙 Dark Mode Improvements

-
