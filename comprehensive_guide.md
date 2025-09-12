# HabitHearts - Flutter Migration Project

## Project Context

The original HabitHearts application was built using **React Native with TypeScript**. Your task is to recreate this exact same application using **Flutter with Dart**.

## Objective

Create a Flutter version of the HabitHearts app that maintains **100% feature parity** with the original React Native version, including:

1. **All UI components** and visual design
2. **Complete functionality** and user workflows
3. **Animations and transitions**
4. **Backend integration** with Firebase
5. **Real-time data synchronization**
6. **Theme customization** and color system
7. **Performance optimizations**

## Key Requirements

### Functional Requirements
- Google Sign-In authentication
- Habit/task tracking with time scheduling
- Calendar view with day/week/month modes
- Goal setting with progress visualization
- Partner linking with unique codes
- Shared data between linked users
- Real-time updates across all features
- Theme customization with vibrant color palette

### Technical Requirements
- Flutter SDK (latest stable version)
- Firebase integration (Authentication, Firestore, Storage)
- Provider or BLoC for state management
- Custom animations and transitions
- Responsive design for all screen sizes
- Offline capability where appropriate

## Available Resources

1. **summary.txt** - Complete analysis of the React Native app structure
2. **flutter_implementation_guide.md** - Step-by-step implementation plan with:
   - Progress tracking sections
   - Detailed data models
   - Firebase security rules
   - Environment configuration
   - Implementation priority order

## Success Criteria

The final Flutter app should be **indistinguishable** from the React Native version in terms of:
- User interface and experience
- Feature set and functionality
- Performance and responsiveness
- Visual design and animations

Follow the implementation guide step-by-step, checking off completed items in the progress tracking sections as you go.

---

# HabitHearts App - React Native to Flutter Migration Guide

## Overview
HabitHearts is a habit tracking and relationship app built with React Native that allows couples to track their habits together, manage events, and maintain shared goals. The app uses Firebase for backend services and implements a vibrant, colorful UI with theme customization.

## Tech Stack
- **Frontend**: React Native with TypeScript
- **Backend**: Firebase (Authentication, Firestore)
- **Navigation**: React Navigation (Stack + Bottom Tabs)
- **State Management**: Context API + React Query
- **UI Components**: Reanimated for animations, Vector Icons, FlashList for performance

## App Structure & Navigation Flow

### Authentication Flow
**File**: `src/screens/LoginScreen.tsx`
**Features**:
- Google Sign-In integration
- Animated slideshow component
- Custom UI with heart logo and app title
- Loading states and error handling

### Main App Flow
**Files**: 
- `App.tsx` (Entry point)
- `src/navigation/AppNavigator.tsx` (Stack navigator)
- `src/navigation/BottomTabNavigator.tsx` (Tab navigator)

**Navigation Structure**:
1. **Home Tab** (`src/screens/MainHomeScreen.tsx`)
2. **Calendar Tab** (`src/screens/CalendarScreen.tsx`)
3. **Goals Tab** (`src/screens/GoalsScreen.tsx`)
4. **Testing Tab** (`src/screens/TestingScreen.tsx`)
5. **Profile Tab** (`src/screens/ProfileScreen.tsx`)

## Feature Breakdown

### 1. Home Screen (`src/screens/MainHomeScreen.tsx` + `src/components/home/ComplexHomeScreen.tsx`)
**UI Components**:
- Animated header with fade effect
- Date carousel for selecting days
- Task list with swipeable items
- Progress heatmaps for goals
- Custom time pickers with scroll snapping
- Emoji selection for tasks
- Loading states and skeleton UI

**Animations**:
- Header fade on scroll
- Today's date pulse animation
- Smooth transitions between screens

**Functionality**:
- View tasks for selected date
- Add/Edit/Delete tasks
- Mark tasks as complete
- View goal progress with heatmaps
- Time selection for tasks

### 2. Calendar Screen (`src/screens/CalendarScreen.tsx`)
**UI Components**:
- Month/Week/Day view selector
- Calendar grid with event indicators
- Event list for selected period
- Custom time pickers
- Emoji selection for events

**Functionality**:
- View calendar events
- Add/Edit/Delete events
- Navigate between dates/weeks/months
- Time selection for events

### 3. Goals Screen (`src/screens/GoalsScreen.tsx`)
**UI Components**:
- Goal cards with progress bars
- Progress percentage indicators
- Edit/Add goal modals
- Empty state illustrations

**Functionality**:
- View all goals (personal and shared)
- Add/Edit/Delete goals
- Mark goals as complete
- View progress percentage

### 4. Profile Screen (`src/screens/ProfileScreen.tsx`)
**UI Components**:
- User profile information
- Theme color selection
- Unique code display
- Partner linking interface
- Linked partners list

**Functionality**:
- View user profile
- Change app theme
- Link with partner using unique code
- View linked partners
- Sign out

## Data Models & Services

### Task Model (`src/services/taskService.ts`)
```typescript
interface Task {
  id: string;
  text: string;
  description?: string;
  dueDate?: Timestamp;
  completed: boolean;
  createdBy: string;
  creatorName: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  status: string;
  emoji?: string;
  startTime?: string;
  endTime?: string;
}
```

### Goal Model (`src/services/goalService.ts`)
```typescript
interface Goal {
  id: string;
  text: string;
  completed: boolean;
  createdBy: string;
  creatorName: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  status: string;
}
```

### Goal Progress Model (`src/services/goalProgressService.ts`)
```typescript
interface GoalProgress {
  id: string;
  goalId: string;
  date: string; // YYYY-MM-DD format
  completed: boolean;
  userId: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### User Model (`src/services/userService.ts`)
```typescript
interface User {
  uid: string;
  email?: string;
  displayName?: string;
  photoURL?: string;
  uniqueCode: string;
  linkedUsers: string[];
  createdAt: Date;
  updatedAt: Date;
  status: string;
}
```

### Calendar Event Model (`src/services/calendarService.ts`)
```typescript
interface CalendarEvent {
  id: string;
  title: string;
  date: Date | { seconds: number } | string;
  endDate?: Date | { seconds: number } | string;
  startTime?: string;
  endTime?: string;
  completed?: boolean;
  createdBy: string;
  creatorName: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  status: string;
  emoji?: string;
}
```

## Backend Services

### Firebase Setup (`firebaseConfig.js`)
- Firebase Authentication (Google Sign-In)
- Firestore Database
- React Native Persistence

### Services
1. **Task Service** (`src/services/taskService.ts`)
   - Create, update, delete, toggle tasks
   - Real-time listener for user and linked users' tasks

2. **Goal Service** (`src/services/goalService.ts`)
   - Create, update, delete, toggle goals
   - Real-time listener for user and linked users' goals

3. **Goal Progress Service** (`src/services/goalProgressService.ts`)
   - Track daily goal completion
   - Get progress for individual goals or multiple goals

4. **User Service** (`src/services/userService.ts`)
   - User document creation/update
   - User linking/unlinking
   - Unique code generation
   - Linked users retrieval

5. **Calendar Service** (`src/services/calendarService.ts`)
   - Create, update, delete calendar events
   - Real-time listener for user and linked users' events

6. **Notification Service** (`src/services/notificationService.ts`)
   - Event emitter for data changes
   - Broadcasts for task, calendar, and user changes

## State Management

### Context Providers
1. **Auth Context** (`src/context/AuthContext.tsx`)
   - User authentication state
   - Login/logout functions

2. **Status Bar Context** (`src/context/StatusBarContext.tsx`)
   - Theme-based status bar management
   - Background color and text color calculations

3. **Theme Context** (`src/context/ThemeContext.tsx`)
   - Theme color selection and persistence

4. **Home Data Context** (`src/context/HomeDataContext.tsx`)
   - Centralized data management for home screen
   - Tasks, goals, progress data
   - Real-time listeners

## UI Components

### Custom Components
1. **AnimatedTabIcon** (`src/components/AnimatedTabIcon.tsx`)
   - Tab icons with animation on focus

2. **EnhancedTaskItem** (`src/components/home/EnhancedTaskItem.tsx`)
   - Swipeable task items with actions

3. **EnhancedEventItem** (`src/components/home/EnhancedEventItem.tsx`)
   - Swipeable event items with actions

4. **SafeStatusBar** (`src/components/SafeStatusBar.tsx`)
   - Status bar with safe area handling

5. **SnappingCarousel** (`src/components/SnappingCarousel.tsx`)
   - Carousel with snapping behavior

6. **Slideshow** (`src/components/Slideshow.tsx`)
   - Image slideshow for login screen

### Animations
1. **Screen Transitions** (`src/navigation/ScreenTransitions.tsx`)
   - Fade and slide transitions between screens

2. **Reanimated Components**
   - Scroll-driven header animations
   - Time picker scroll snapping
   - Date selection animations

## Theming System

### Color Palette (`src/theme/colors.ts`)
- Primary colors: Electric Blue, Hot Pink, Electric Green, etc.
- Light and dark variations for each color
- Glass effect colors (semi-transparent)
- Status colors (success, error, warning, info)

### Utilities
1. **Theme Utils** (`src/utils/themeUtils.ts`)
   - Color shade generation
   - Theme palette creation

2. **Color Utils** (`src/utils/colorUtils.ts`)
   - Color lightening/darkening
   - Text color contrast calculation
   - Hex to RGB conversion

3. **Button Utils** (`src/utils/buttonUtils.ts`)
   - Button color generation based on theme

4. **Responsive Utils** (`src/utils/responsive.ts`)
   - Responsive sizing functions

## Flutter Implementation Checklist

### Phase 1: Project Setup
- [ ] Create new Flutter project
- [ ] Set up Firebase integration (Authentication, Firestore)
- [ ] Configure Google Sign-In
- [ ] Set up project dependencies (provider, cloud_firestore, firebase_auth, etc.)

### Phase 2: Core Architecture
- [ ] Implement authentication flow
- [ ] Set up navigation structure (BottomNavigationBar)
- [ ] Create state management solution (Provider/BLoC)
- [ ] Implement theme system with color palette
- [ ] Set up responsive design utilities

### Phase 3: Authentication & Profile
- [ ] Implement LoginScreen with Google Sign-In
- [ ] Create ProfileScreen with user info
- [ ] Add theme selection functionality
- [ ] Implement user linking with unique codes
- [ ] Add sign out functionality

### Phase 4: Home Screen
- [ ] Create MainHomeScreen with date carousel
- [ ] Implement task list with swipeable items
- [ ] Add task creation/editing with time pickers
- [ ] Implement goal progress heatmaps
- [ ] Add animations for header and date selection

### Phase 5: Calendar Screen
- [ ] Create CalendarScreen with view selector
- [ ] Implement calendar grid with event indicators
- [ ] Add event creation/editing with time pickers
- [ ] Create event list for selected period

### Phase 6: Goals Screen
- [ ] Create GoalsScreen with goal cards
- [ ] Implement goal creation/editing
- [ ] Add progress tracking with percentage indicators
- [ ] Implement goal completion toggle

### Phase 7: UI Components & Polish
- [ ] Create custom tab icons with animations
- [ ] Implement swipeable list items
- [ ] Add screen transition animations
- [ ] Create custom time pickers
- [ ] Implement emoji selection components
- [ ] Add empty state illustrations
- [ ] Polish UI with consistent styling

### Phase 8: Backend Integration
- [ ] Connect all screens to Firebase services
- [ ] Implement real-time listeners for data updates
- [ ] Add offline support where appropriate
- [ ] Implement error handling and loading states

### Phase 9: Testing & Optimization
- [ ] Test all functionality on different device sizes
- [ ] Optimize performance (list rendering, animations)
- [ ] Fix any UI inconsistencies
- [ ] Ensure all edge cases are handled

## Key Features to Recreate
1. Google Sign-In authentication
2. Theme customization with color palette
3. User linking with unique codes
4. Task management with time selection
5. Calendar with multiple view modes
6. Goal tracking with progress visualization
7. Shared data between linked users
8. Real-time updates
9. Custom animations and transitions
10. Responsive design for all screen sizes

## Assets Needed
1. Heart logo (`assets/images/heartlogo.png`)
2. App title logo (`assets/images/logo2.png`)
3. Google logo (`assets/images/google-logo.png`)
4. Placeholder images for slideshow (if used)

This document provides a complete blueprint for recreating the HabitHearts app in Flutter, maintaining all core functionality and UI features.

---

# HabitHearts App - Flutter Implementation Guide

## Project Progress Status
### Completed Tasks
- [x] Project analysis and documentation
- [x] Feature breakdown and requirements gathering
- [x] Data model identification
- [x] UI component cataloging
- [x] Backend service documentation
- [x] Implementation checklist creation

### Current Focus
- [ ] Flutter project setup
- [ ] Firebase integration
- [ ] Authentication implementation
- [ ] Core architecture establishment

### Upcoming Tasks
- [ ] Navigation structure implementation
- [ ] Theme system creation
- [ ] UI component development
- [ ] Screen-by-screen implementation
- [ ] Backend service integration
- [ ] Testing and optimization

## Overview
HabitHearts is a habit tracking and relationship app that allows couples to track their habits together, manage events, and maintain shared goals. This guide provides a detailed, step-by-step approach to recreate the app in Flutter while maintaining all core functionality and UI features.

## Tech Stack Requirements for Flutter Implementation
### Core Dependencies
- **Flutter SDK**: Latest stable version
- **Firebase**: 
  - firebase_core
  - firebase_auth
  - cloud_firestore
  - firebase_storage
- **State Management**: provider or bloc
- **Navigation**: flutter_native_splash, go_router or auto_route
- **UI Components**: 
  - cached_network_image
  - flutter_svg
  - font_awesome_flutter
  - animations
- **Animations**: flutter_animate or built-in AnimationController
- **Date/Time**: intl, table_calendar
- **Persistence**: shared_preferences
- **Google Sign-In**: google_sign_in

## Phase 1: Project Setup
### Step 1: Create Flutter Project
```bash
flutter create habit_hearts
cd habit_hearts
```

### Step 2: Firebase Integration
1. Create Firebase project at https://console.firebase.google.com/
2. Register Android and iOS apps with package name: `com.habithearts.app`
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place files in respective directories:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

### Step 3: Add Firebase Dependencies
**pubspec.yaml**:
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.15.0
  firebase_auth: ^4.9.0
  cloud_firestore: ^4.8.0
  firebase_storage: ^11.2.0
  google_sign_in: ^5.4.0
  provider: ^6.1.0
  cached_network_image: ^3.3.0
  flutter_svg: ^2.0.0
  font_awesome_flutter: ^10.5.0
  intl: ^0.18.0
  table_calendar: ^3.0.0
  shared_preferences: ^2.2.0
  animations: ^2.0.0
```

### Step 4: Configure Firebase in Code
**lib/main.dart**:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

## Phase 2: Core Architecture
### Step 1: State Management Setup
Create a provider-based state management system:
```
lib/
├── providers/
│   ├── auth_provider.dart
│   ├── theme_provider.dart
│   └── home_data_provider.dart
```

### Step 2: Navigation Structure
Implement a bottom navigation bar with 5 tabs:
1. Home
2. Calendar
3. Goals
4. Testing
5. Profile

### Step 3: Theme System
Create a theme service with color palette:
- Electric Blue: #00D4FF
- Hot Pink: #FF2B9D
- Electric Green: #00FF9D
- Vibrant Orange: #FF6B00
- Bright Purple: #9D4AFF
- Sunny Yellow: #FFD400
- Bright Red: #FF2B2B
- Mint: #2BFFD4

## Phase 3: Authentication & Profile
### Step 1: Authentication Flow
Implement Google Sign-In with Firebase Auth:
1. Configure Google Sign-In in Firebase Console
2. Add SHA-1 fingerprint for Android
3. Implement sign-in functionality

### Step 2: Profile Management
Create user document in Firestore:
```dart
class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String uniqueCode;
  final List<String> linkedUsers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
}
```

### Step 3: User Linking
Implement unique code generation and linking functionality:
- Generate 8-character unique codes
- Link/unlink users functionality
- Display linked partners

## Phase 4: Home Screen Implementation
### Step 1: UI Components
Create:
- Animated header with fade effect
- Date carousel for selecting days
- Task list with swipeable items
- Progress heatmaps for goals
- Custom time pickers
- Emoji selection for tasks

### Step 2: Functionality
Implement:
- View tasks for selected date
- Add/Edit/Delete tasks
- Mark tasks as complete
- View goal progress with heatmaps
- Time selection for tasks

## Phase 5: Calendar Screen
### Step 1: View Modes
Implement 3 view modes:
- Month view with event indicators
- Week view with daily breakdown
- Day view with hourly schedule

### Step 2: Event Management
- Add/Edit/Delete calendar events
- Time selection with custom pickers
- Emoji selection for events
- Event list for selected period

## Phase 6: Goals Screen
### Step 1: Goal Management
Create:
- Goal cards with progress bars
- Progress percentage indicators
- Edit/Add goal modals
- Empty state illustrations

### Step 2: Progress Tracking
Implement:
- Daily goal completion tracking
- Progress visualization
- Goal completion toggle

## Phase 7: UI Components & Animations
### Custom Components to Create:
1. AnimatedTabIcon - Tab icons with animation on focus
2. SwipeableTaskItem - Swipeable task items with actions
3. SwipeableEventItem - Swipeable event items with actions
4. SnappingCarousel - Carousel with snapping behavior
5. CustomTimePicker - Scroll-snapping time picker
6. EmojiSelector - Emoji selection component

### Animations to Implement:
1. Header fade on scroll
2. Today's date pulse animation
3. Screen transitions between tabs
4. Time picker scroll snapping
5. Date selection animations

## Phase 8: Backend Services
### Data Models
Implement all data models as Dart classes:
1. Task Model
2. Goal Model
3. GoalProgress Model
4. User Model
5. CalendarEvent Model

### Service Layer
Create service classes for:
1. AuthService - Authentication handling
2. UserService - User document management
3. TaskService - Task CRUD operations
4. GoalService - Goal CRUD operations
5. GoalProgressService - Progress tracking
6. CalendarService - Event management

### Real-time Updates
Implement Firestore listeners for:
- Tasks (user and linked users)
- Goals (user and linked users)
- Calendar events (user and linked users)

## Phase 9: Testing & Optimization
### Testing Areas:
1. Authentication flow
2. Data synchronization
3. UI responsiveness
4. Performance on different devices
5. Edge case handling

### Optimization Focus:
1. List rendering performance
2. Animation smoothness
3. Memory usage
4. Network efficiency
5. Battery consumption

## Data Models Detailed Specification

### Task Model (lib/models/task.dart)
```dart
class Task {
  final String id;
  final String text;
  final String? description;
  final DateTime? dueDate;
  final bool completed;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? emoji;
  final String? startTime;
  final String? endTime;

  Task({
    required this.id,
    required this.text,
    this.description,
    this.dueDate,
    required this.completed,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.emoji,
    this.startTime,
    this.endTime,
  });
}
```

### Goal Model (lib/models/goal.dart)
```dart
class Goal {
  final String id;
  final String text;
  final bool completed;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  Goal({
    required this.id,
    required this.text,
    required this.completed,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });
}
```

### GoalProgress Model (lib/models/goal_progress.dart)
```dart
class GoalProgress {
  final String id;
  final String goalId;
  final String date; // YYYY-MM-DD format
  final bool completed;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  GoalProgress({
    required this.id,
    required this.goalId,
    required this.date,
    required this.completed,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });
}
```

### User Model (lib/models/user.dart)
```dart
class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String uniqueCode;
  final List<String> linkedUsers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.uniqueCode,
    required this.linkedUsers,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });
}
```

### CalendarEvent Model (lib/models/calendar_event.dart)
```dart
class CalendarEvent {
  final String id;
  final String title;
  final dynamic date; // DateTime, Timestamp, or String
  final dynamic endDate;
  final String? startTime;
  final String? endTime;
  final bool? completed;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? emoji;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.endDate,
    this.startTime,
    this.endTime,
    this.completed,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.emoji,
  });
}
```

## Firebase Security Rules
Implement Firestore security rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null && resource.data.linkedUsers.hasAny([request.auth.uid]);
    }
    
    // Tasks collection
    match /tasks/{taskId} {
      allow read, write: if request.auth != null && 
        (resource.data.createdBy == request.auth.uid || 
         resource.data.createdBy in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.linkedUsers);
    }
    
    // Goals collection
    match /goals/{goalId} {
      allow read, write: if request.auth != null && 
        (resource.data.createdBy == request.auth.uid || 
         resource.data.createdBy in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.linkedUsers);
    }
    
    // GoalProgress collection
    match /goalProgress/{progressId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
    
    // CalendarEvents collection
    match /calendarEvents/{eventId} {
      allow read, write: if request.auth != null && 
        (resource.data.createdBy == request.auth.uid || 
         resource.data.createdBy in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.linkedUsers);
    }
  }
}
```

## Environment Variables & Configuration
Create `.env` file with:
```
FIREBASE_API_KEY=your_api_key_here
FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_project_id.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id
FIREBASE_APP_ID=your_app_id
GOOGLE_WEB_CLIENT_ID=your_web_client_id
```

## Implementation Priority Order
1. Authentication & Profile (Foundational)
2. Home Screen (Core functionality)
3. Calendar Screen (Date-based features)
4. Goals Screen (Progress tracking)
5. Testing Screen (Experimental features)
6. UI Polish & Animations (Enhancement)
7. Performance Optimization (Final pass)

This comprehensive guide provides everything needed to recreate the HabitHearts app in Flutter with the same functionality, UI design, and user experience as the original React Native version.


CREDENTIALS AND OTHER THINGS : 
# Your Google Client ID for the backend (Web application type)
GOOGLE_CLIENT_ID=545998989450-ierli7eqdnkr5slmsm3vl2dcke96a7rn.apps.googleusercontent.com

# The port for the backend server
PORT=3000
# Firebase Configuration
FIREBASE_API_KEY=AIzaSyAof9wyKPDlazP3tYM_2WopQj1DuJ_IY2M
FIREBASE_AUTH_DOMAIN=habithearts.firebaseapp.com
FIREBASE_PROJECT_ID=habithearts
FIREBASE_STORAGE_BUCKET=habithearts.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=545998989450
FIREBASE_APP_ID=1:545998989450:android:64f966d0f60843e2796573
MEASUREMENT_ID=G-43D98M8KMX