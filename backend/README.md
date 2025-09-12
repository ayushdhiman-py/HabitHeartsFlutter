# HabitHearts Backend API

This is the backend API for the HabitHearts application. It provides RESTful endpoints for the frontend to interact with Firebase services.

## Setup Instructions

1. Install dependencies:
   ```
   npm install
   ```

2. Generate Firebase Admin SDK credentials:
   - Go to the Firebase Console
   - Select your project
   - Go to Project Settings
   - Go to the Service Accounts tab
   - Click "Generate new private key"
   - Save the JSON file as `habithearts-firebase-adminsdk.json` in this directory

3. Create a `.env` file with your Google Client ID:
   ```
   GOOGLE_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
   PORT=3000
   ```

4. Start the server:
   ```
   npm start
   ```

## API Endpoints

### Authentication
- `POST /auth/google` - Verify Google ID token

### Users
- `GET /api/users/:uid` - Get user by ID
- `POST /api/users` - Create a new user
- `PUT /api/users/:uid` - Update user

### Tasks
- `GET /api/tasks/:userId/:date` - Get tasks for a user on a specific date
- `POST /api/tasks` - Create a new task
- `PUT /api/tasks/:id` - Update a task
- `DELETE /api/tasks/:id` - Delete a task

### Goals
- `GET /api/goals/:userId` - Get goals for a user
- `POST /api/goals` - Create a new goal
- `PUT /api/goals/:id` - Update a goal
- `DELETE /api/goals/:id` - Delete a goal

### Calendar Events
- `GET /api/calendarEvents/:userId` - Get calendar events for a user
- `POST /api/calendarEvents` - Create a new calendar event
- `PUT /api/calendarEvents/:id` - Update a calendar event
- `DELETE /api/calendarEvents/:id` - Delete a calendar event

### Goal Progress
- `GET /api/goalProgress/:goalId` - Get progress for a specific goal
- `POST /api/goalProgress` - Create/update goal progress
- `PUT /api/goalProgress/:id` - Update goal progress
- `DELETE /api/goalProgress/:id` - Delete goal progress
- `POST /api/goalProgress/toggle` - Toggle goal progress for a specific date