const express = require('express');
const { OAuth2Client } = require('google-auth-library');
const admin = require('firebase-admin');
require('dotenv').config();

const app = express();
app.use(express.json());

// Initialize Firebase Admin SDK
// You need to replace 'habithearts-firebase-adminsdk.json' with your actual service account key
const serviceAccount = require('./habithearts-firebase-adminsdk.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://habithearts-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

// OAuth2 client for Google authentication
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'API server is running' });
});

// Google authentication endpoint
app.post('/auth/google', async (req, res) => {
  const { token } = req.body;
  try {
    const ticket = await client.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const { name, email, picture } = payload;
    
    console.log('User authenticated:', { name, email });
    res.status(200).json({ user: { name, email, picture } });
  } catch (error) {
    console.error('Google auth error', error);
    res.status(401).json({ message: 'Invalid Google token' });
  }
});

// User endpoints
app.get('/api/users/:uid', async (req, res) => {
  try {
    const userDoc = await db.collection('users').doc(req.params.uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const data = userDoc.data();
    // Convert Firestore Timestamps to milliseconds
    const createdAt = data.createdAt ? data.createdAt.toMillis() : Date.now();
    const updatedAt = data.updatedAt ? data.updatedAt.toMillis() : Date.now();
    
    res.status(200).json({
      ...data,
      createdAt,
      updatedAt
    });
  } catch (error) {
    console.error('Error getting user:', error);
    res.status(500).json({ message: 'Error getting user' });
  }
});

app.post('/api/users', async (req, res) => {
  try {
    const userData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (userData.createdAt) {
      userData.createdAt = admin.firestore.Timestamp.fromMillis(userData.createdAt);
    }
    if (userData.updatedAt) {
      userData.updatedAt = admin.firestore.Timestamp.fromMillis(userData.updatedAt);
    }
    
    await db.collection('users').doc(userData.uid).set(userData);
    res.status(201).json({ message: 'User created successfully' });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ message: 'Error creating user' });
  }
});

app.put('/api/users/:uid', async (req, res) => {
  try {
    const userData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (userData.createdAt) {
      userData.createdAt = admin.firestore.Timestamp.fromMillis(userData.createdAt);
    }
    if (userData.updatedAt) {
      userData.updatedAt = admin.firestore.Timestamp.fromMillis(userData.updatedAt);
    }
    
    await db.collection('users').doc(req.params.uid).update(userData);
    res.status(200).json({ message: 'User updated successfully' });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ message: 'Error updating user' });
  }
});

// Task endpoints
app.get('/api/tasks/:userId/:date', async (req, res) => {
  try {
    const { userId, date } = req.params;
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);
    
    // Use a simpler query that doesn't require a composite index
    const snapshot = await db.collection('tasks')
      .where('createdBy', '==', userId)
      .get();
    
    // Filter by date on the client side
    const tasks = snapshot.docs
      .map(doc => {
        const data = doc.data();
        // Convert Firestore Timestamps to milliseconds
        const createdAt = data.createdAt ? data.createdAt.toMillis() : Date.now();
        const updatedAt = data.updatedAt ? data.updatedAt.toMillis() : Date.now();
        const dueDate = data.dueDate ? data.dueDate.toMillis() : null;
        
        // Remove the original 'id' field from the data to avoid conflict with the document ID
        const { id, ...dataWithoutId } = data;
        
        return {
          id: doc.id,
          ...dataWithoutId,
          createdAt,
          updatedAt,
          dueDate
        };
      })
      .filter(task => {
        if (!task.dueDate) return false;
        const taskDate = new Date(task.dueDate);
        return taskDate >= startOfDay && taskDate <= endOfDay;
      });
    
    res.status(200).json(tasks);
  } catch (error) {
    console.error('Error getting tasks:', error);
    res.status(500).json({ message: 'Error getting tasks' });
  }
});

app.post('/api/tasks', async (req, res) => {
  try {
    const taskData = req.body;
    console.log('Creating task with data:', taskData);
    
    // Convert milliseconds to Firestore Timestamps
    if (taskData.createdAt) {
      taskData.createdAt = admin.firestore.Timestamp.fromMillis(taskData.createdAt);
    }
    if (taskData.updatedAt) {
      taskData.updatedAt = admin.firestore.Timestamp.fromMillis(taskData.updatedAt);
    }
    if (taskData.dueDate) {
      taskData.dueDate = admin.firestore.Timestamp.fromMillis(taskData.dueDate);
    }
    
    const docRef = await db.collection('tasks').add(taskData);
    console.log('Task created with ID:', docRef.id);
    
    res.status(201).json({ 
      id: docRef.id, 
      text: taskData.text,
      description: taskData.description,
      dueDate: taskData.dueDate ? taskData.dueDate.toMillis() : null,
      completed: taskData.completed,
      createdBy: taskData.createdBy,
      creatorName: taskData.creatorName,
      createdAt: taskData.createdAt ? taskData.createdAt.toMillis() : Date.now(),
      updatedAt: taskData.updatedAt ? taskData.updatedAt.toMillis() : Date.now(),
      status: taskData.status,
      emoji: taskData.emoji,
      startTime: taskData.startTime,
      endTime: taskData.endTime
    });
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ message: 'Error creating task' });
  }
});

app.put('/api/tasks/:id', async (req, res) => {
  try {
    const taskData = req.body;
    const taskId = req.params.id;
    console.log('Updating task with ID:', taskId, 'data:', taskData);
    
    // Create a copy of taskData for Firestore update to avoid modifying the original
    const firestoreTaskData = { ...taskData };
    
    // Convert milliseconds to Firestore Timestamps
    if (firestoreTaskData.createdAt) {
      firestoreTaskData.createdAt = admin.firestore.Timestamp.fromMillis(firestoreTaskData.createdAt);
    }
    if (firestoreTaskData.updatedAt) {
      firestoreTaskData.updatedAt = admin.firestore.Timestamp.fromMillis(firestoreTaskData.updatedAt);
    }
    if (firestoreTaskData.dueDate) {
      firestoreTaskData.dueDate = admin.firestore.Timestamp.fromMillis(firestoreTaskData.dueDate);
    }
    
    // Check if the document exists before updating
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      console.log('Task document not found:', taskId);
      return res.status(404).json({ message: 'Task not found' });
    }
    
    await db.collection('tasks').doc(taskId).update(firestoreTaskData);
    console.log('Task updated successfully:', taskId);
    
    // Return the updated task data in the response
    res.status(200).json({ 
      id: taskId,
      ...taskData,
      updatedAt: taskData.updatedAt ? taskData.updatedAt : Date.now()
    });
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ message: 'Error updating task' });
  }
});

app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const taskId = req.params.id;
    console.log('Deleting task with ID:', taskId);
    
    // Check if the document exists before deleting
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      console.log('Task document not found:', taskId);
      return res.status(404).json({ message: 'Task not found' });
    }
    
    await db.collection('tasks').doc(taskId).delete();
    console.log('Task deleted successfully:', taskId);
    res.status(200).json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Error deleting task:', error);
    res.status(500).json({ message: 'Error deleting task' });
  }
});

// Goal endpoints
app.get('/api/goals/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const snapshot = await db.collection('goals')
      .where('createdBy', '==', userId)
      .get();
    
    const goals = snapshot.docs.map(doc => {
      const data = doc.data();
      // Convert Firestore Timestamps to milliseconds
      const createdAt = data.createdAt ? data.createdAt.toMillis() : Date.now();
      const updatedAt = data.updatedAt ? data.updatedAt.toMillis() : Date.now();
      const startDate = data.startDate ? data.startDate.toMillis() : null;
      const endDate = data.endDate ? data.endDate.toMillis() : null;
      
      // Remove the original 'id' field from the data to avoid conflict with the document ID
      const { id, ...dataWithoutId } = data;

      return {
        id: doc.id,
        ...dataWithoutId,
        createdAt,
        updatedAt,
        isHabit: data.isHabit || false,
        startDate,
        endDate
      };
    });
    
    res.status(200).json(goals);
  } catch (error) {
    console.error('Error getting goals:', error);
    res.status(500).json({ message: 'Error getting goals' });
  }
});

app.post('/api/goals', async (req, res) => {
  try {
    const goalData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (goalData.createdAt) {
      goalData.createdAt = admin.firestore.Timestamp.fromMillis(goalData.createdAt);
    }
    if (goalData.updatedAt) {
      goalData.updatedAt = admin.firestore.Timestamp.fromMillis(goalData.updatedAt);
    }
    if (goalData.startDate) {
      goalData.startDate = admin.firestore.Timestamp.fromMillis(goalData.startDate);
    } else {
      goalData.startDate = null; // Explicitly set to null if not provided
    }
    if (goalData.endDate) {
      goalData.endDate = admin.firestore.Timestamp.fromMillis(goalData.endDate);
    } else {
      goalData.endDate = null; // Explicitly set to null if not provided
    }
    
    const docRef = await db.collection('goals').add(goalData);
    res.status(201).json({ 
      id: docRef.id, 
      text: goalData.text,
      completed: goalData.completed,
      createdBy: goalData.createdBy,
      creatorName: goalData.creatorName,
      emoji: goalData.emoji,
      status: goalData.status,
      isHabit: goalData.isHabit || false,
      startDate: goalData.startDate ? goalData.startDate.toMillis() : null,
      endDate: goalData.endDate ? goalData.endDate.toMillis() : null,
      // Convert back to milliseconds for the response
      createdAt: goalData.createdAt ? goalData.createdAt.toMillis() : Date.now(),
      updatedAt: goalData.updatedAt ? goalData.updatedAt.toMillis() : Date.now()
    });
  } catch (error) {
    console.error('Error creating goal:', error);
    res.status(500).json({ message: 'Error creating goal' });
  }
});

app.put('/api/goals/:id', async (req, res) => {
  try {
    const { text, status, emoji, startDate, endDate, isHabit, completed } = req.body;
    const updateData = { updatedAt: admin.firestore.Timestamp.fromMillis(Date.now()) }; // Always update updatedAt

    if (text !== undefined) updateData.text = text;
    if (status !== undefined) updateData.status = status;
    if (emoji !== undefined) updateData.emoji = emoji;
    if (startDate !== undefined) updateData.startDate = admin.firestore.Timestamp.fromMillis(startDate);
    if (endDate !== undefined) updateData.endDate = admin.firestore.Timestamp.fromMillis(endDate);
    if (isHabit !== undefined) updateData.isHabit = isHabit;
    if (completed !== undefined) updateData.completed = completed;

    await db.collection('goals').doc(req.params.id).update(updateData);

    // Fetch the updated document to return it in the response
    const updatedDoc = await db.collection('goals').doc(req.params.id).get();
    const updatedData = updatedDoc.data();

    res.status(200).json({ 
      id: updatedDoc.id,
      ...updatedData,
      createdAt: updatedData.createdAt ? updatedData.createdAt.toMillis() : Date.now(),
      updatedAt: updatedData.updatedAt ? updatedData.updatedAt.toMillis() : Date.now(),
      isHabit: updatedData.isHabit || false,
      startDate: updatedData.startDate ? updatedData.startDate.toMillis() : null,
      endDate: updatedData.endDate ? updatedData.endDate.toMillis() : null
    });
  } catch (error) {
    console.error('Error updating goal:', error);
    res.status(500).json({ message: 'Error updating goal' });
  }
});

app.delete('/api/goals/:id', async (req, res) => {
  try {
    await db.collection('goals').doc(req.params.id).delete();
    res.status(200).json({ message: 'Goal deleted successfully' });
  } catch (error) {
    console.error('Error deleting goal:', error);
    res.status(500).json({ message: 'Error deleting goal' });
  }
});

// DELETE endpoint for removing a user's progress for a specific goal
app.delete('/api/users/:userId/goal-progress/:goalId', async (req, res) => {
  const { userId, goalId } = req.params;

  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return res.status(404).send('User not found');
    }

    // The path to the specific goal in the goalProgress map
    const goalProgressField = `goalProgress.${goalId}`;

    // Use FieldValue.delete() to remove the key from the map
    await userRef.update({
      [goalProgressField]: admin.firestore.FieldValue.delete()
    });

    console.log(`Successfully deleted progress for goal ${goalId} for user ${userId}`);
    res.status(200).send(`Progress for goal ${goalId} deleted successfully.`);

  } catch (error) {
    console.error('Error deleting goal progress:', error);
    res.status(500).send('Error deleting goal progress');
  }
});

// Calendar event endpoints
app.get('/api/calendarEvents/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { startDate, endDate } = req.query;
    
    let query = db.collection('calendarEvents').where('createdBy', '==', userId);
    
    if (startDate) {
      query = query.where('date', '>=', new Date(startDate));
    }
    
    if (endDate) {
      const end = new Date(endDate);
      end.setUTCHours(23, 59, 59, 999); // Set to the end of the day
      query = query.where('date', '<=', end);
    }
    
    const snapshot = await query.get();
    
    const events = snapshot.docs.map(doc => {
      const data = doc.data();
      // Convert Firestore Timestamps to milliseconds
      const createdAt = data.createdAt ? data.createdAt.toMillis() : Date.now();
      const updatedAt = data.updatedAt ? data.updatedAt.toMillis() : Date.now();
      const eventDate = data.date ? data.date.toMillis() : null;
      const eventEndDate = data.endDate ? data.endDate.toMillis() : null;

      // Remove the original 'id' field from the data to avoid conflict with the document ID
      const { id, ...dataWithoutId } = data;

      return {
        id: doc.id,
        ...dataWithoutId,
        date: eventDate,
        endDate: eventEndDate,
        createdAt,
        updatedAt
      };
    });
    
    res.status(200).json(events);
  } catch (error) {
    console.error('Error getting calendar events:', error);
    res.status(500).json({ message: 'Error getting calendar events' });
  }
});

app.post('/api/calendarEvents', async (req, res) => {
  try {
    const eventData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (eventData.createdAt) {
      eventData.createdAt = admin.firestore.Timestamp.fromMillis(eventData.createdAt);
    }
    if (eventData.updatedAt) {
      eventData.updatedAt = admin.firestore.Timestamp.fromMillis(eventData.updatedAt);
    }
    if (eventData.date) {
      eventData.date = admin.firestore.Timestamp.fromMillis(eventData.date);
    }
    if (eventData.endDate) {
      eventData.endDate = admin.firestore.Timestamp.fromMillis(eventData.endDate);
    }
    
    const docRef = await db.collection('calendarEvents').add(eventData);
    res.status(201).json({ 
      id: docRef.id, 
      title: eventData.title,
      description: eventData.description,
      date: eventData.date ? eventData.date.toMillis() : null,
      endDate: eventData.endDate ? eventData.endDate.toMillis() : null,
      startTime: eventData.startTime,
      endTime: eventData.endTime,
      completed: eventData.completed,
      createdBy: eventData.createdBy,
      creatorName: eventData.creatorName,
      createdAt: eventData.createdAt ? eventData.createdAt.toMillis() : Date.now(),
      updatedAt: eventData.updatedAt ? eventData.updatedAt.toMillis() : Date.now(),
      status: eventData.status,
      emoji: eventData.emoji
    });
  } catch (error) {
    console.error('Error creating calendar event:', error);
    res.status(500).json({ message: 'Error creating calendar event' });
  }
});

app.put('/api/calendarEvents/:id', async (req, res) => {
  try {
    const eventData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (eventData.createdAt) {
      eventData.createdAt = admin.firestore.Timestamp.fromMillis(eventData.createdAt);
    }
    if (eventData.updatedAt) {
      eventData.updatedAt = admin.firestore.Timestamp.fromMillis(eventData.updatedAt);
    }
    if (eventData.date) {
      eventData.date = admin.firestore.Timestamp.fromMillis(eventData.date);
    }
    if (eventData.endDate) {
      eventData.endDate = admin.firestore.Timestamp.fromMillis(eventData.endDate);
    }
    
    await db.collection('calendarEvents').doc(req.params.id).update(eventData);
    res.status(200).json({ message: 'Calendar event updated successfully' });
  } catch (error) {
    console.error('Error updating calendar event:', error);
    res.status(500).json({ message: 'Error updating calendar event' });
  }
});

app.delete('/api/calendarEvents/:id', async (req, res) => {
  try {
    await db.collection('calendarEvents').doc(req.params.id).delete();
    res.status(200).json({ message: 'Calendar event deleted successfully' });
  } catch (error) {
    console.error('Error deleting calendar event:', error);
    res.status(500).json({ message: 'Error deleting calendar event' });
  }
});

// Removed old goalProgress endpoints - now using bit-based approach in user documents

// Toggle goal progress endpoint (NEW: Bit-based approach)
app.post('/api/user/:userId/goal/:goalId/toggle', async (req, res) => {
  try {
    const { userId, goalId } = req.params;
    const { completed } = req.body; // true for done, false for not done
    const today = new Date();
    const yearMonth = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}`;
    const day = today.getDate();
    const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();

    // Get user document
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }

    const userData = userDoc.data();
    const goalProgress = userData.goalProgress || {};

    // Initialize goal progress if it doesn't exist
    if (!goalProgress[goalId]) {
      goalProgress[goalId] = {
        monthlyData: {},
        currentStreak: 0,
        longestStreak: 0,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      };
    }

    // Get current bit string or initialize
    let bitString = goalProgress[goalId].monthlyData[yearMonth] || '0'.repeat(daysInMonth);
    
    // Ensure bit string has correct length
    if (bitString.length < daysInMonth) {
      bitString = bitString.padEnd(daysInMonth, '0');
    } else if (bitString.length > daysInMonth) {
      bitString = bitString.substring(0, daysInMonth);
    }

    // Update the specific day
    const index = day - 1;
    if (index >= 0 && index < bitString.length) {
      const bits = bitString.split('');
      bits[index] = completed ? '1' : '0';
      bitString = bits.join('');
    }

    // Update monthly data
    goalProgress[goalId].monthlyData[yearMonth] = bitString;
    goalProgress[goalId].lastUpdated = admin.firestore.FieldValue.serverTimestamp();

    // Recalculate streaks
    const streaks = calculateStreaks(goalProgress[goalId], today);
    goalProgress[goalId].currentStreak = streaks.currentStreak;
    goalProgress[goalId].longestStreak = streaks.longestStreak;

    // Update user document
    await db.collection('users').doc(userId).update({
      goalProgress,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({ 
      message: 'Goal progress updated successfully',
      completed: completed,
      currentStreak: streaks.currentStreak,
      longestStreak: streaks.longestStreak
    });
  } catch (error) {
    console.error('Error toggling goal progress:', error);
    res.status(500).json({ message: 'Error toggling goal progress' });
  }
});

// Helper function to calculate streaks
function calculateStreaks(progressData, today) {
  const yearMonth = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}`;
  const day = today.getDate();
  
  // Calculate current streak (counting backwards from today)
  let currentStreak = 0;
  let currentDate = new Date(today);
  
  while (true) {
    const currentYearMonth = `${currentDate.getFullYear()}-${(currentDate.getMonth() + 1).toString().padStart(2, '0')}`;
    const currentDay = currentDate.getDate();
    
    // Check if we have data for this month
    if (!progressData.monthlyData[currentYearMonth]) break;
    
    const bitString = progressData.monthlyData[currentYearMonth];
    const index = currentDay - 1;
    
    // Check if index is valid and day is completed
    if (index >= 0 && index < bitString.length && bitString[index] === '1') {
      currentStreak++;
      // Move to previous day
      currentDate.setDate(currentDate.getDate() - 1);
      // If we moved to previous month, continue
    } else {
      break;
    }
  }
  
  // For longest streak, we would need to check all months
  // This is a simplified version - in practice you might want to store this separately
  const longestStreak = Math.max(currentStreak, progressData.longestStreak || 0);
  
  return { currentStreak, longestStreak };
}

// Migration endpoint to convert old goalProgress documents to new bit-based format
app.post('/api/migrateGoalProgress', async (req, res) => {
  try {
    console.log('Starting migration of goal progress data to bit-based format');
    
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    let migratedUsers = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Skip if user already has goalProgress in new format
      if (userData.goalProgress) {
        console.log(`User ${userId} already has new format goalProgress, skipping`);
        continue;
      }
      
      // Initialize goalProgress for this user
      const goalProgress = {};
      
      // Get all goals for this user
      const goalsSnapshot = await db.collection('goals')
        .where('createdBy', '==', userId)
        .get();
      
      for (const goalDoc of goalsSnapshot.docs) {
        const goalId = goalDoc.id;
        
        // Get all progress documents for this goal and user
        const progressSnapshot = await db.collection('goalProgress')
          .where('goalId', '==', goalId)
          .where('userId', '==', userId)
          .get();
        
        if (!progressSnapshot.empty) {
          // Initialize goal progress summary
          goalProgress[goalId] = {
            monthlyData: {},
            currentStreak: 0,
            longestStreak: 0,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          };
          
          // Group progress by month
          const monthlyProgress = {};
          
          for (const progressDoc of progressSnapshot.docs) {
            const progressData = progressDoc.data();
            const date = new Date(progressData.date);
            const yearMonth = `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}`;
            const day = date.getDate();
            
            // Initialize month if not exists
            if (!monthlyProgress[yearMonth]) {
              const daysInMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
              monthlyProgress[yearMonth] = {
                daysInMonth: daysInMonth,
                completedDays: []
              };
            }
            
            // Add completed day
            if (progressData.completed) {
              monthlyProgress[yearMonth].completedDays.push(day);
            }
          }
          
          // Convert to bit strings
          for (const [yearMonth, monthData] of Object.entries(monthlyProgress)) {
            const { daysInMonth, completedDays } = monthData;
            let bitString = '0'.repeat(daysInMonth);
            
            // Set completed days to 1
            for (const day of completedDays) {
              if (day >= 1 && day <= daysInMonth) {
                const index = day - 1;
                const bits = bitString.split('');
                bits[index] = '1';
                bitString = bits.join('');
              }
            }
            
            goalProgress[goalId].monthlyData[yearMonth] = bitString;
          }
          
          // Calculate initial streaks
          const today = new Date();
          const streaks = calculateStreaks(goalProgress[goalId], today);
          goalProgress[goalId].currentStreak = streaks.currentStreak;
          goalProgress[goalId].longestStreak = streaks.longestStreak;
        }
      }
      
      // Update user document with new goalProgress format
      if (Object.keys(goalProgress).length > 0) {
        await db.collection('users').doc(userId).update({
          goalProgress,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`Migrated goal progress for user ${userId}`);
        migratedUsers++;
      }
    }
    
    res.status(200).json({ 
      message: 'Migration completed successfully',
      migratedUsers: migratedUsers
    });
  } catch (error) {
    console.error('Error migrating goal progress:', error);
    res.status(500).json({ message: 'Error migrating goal progress', error: error.message });
  }
});

const PORT = process.env.PORT || 3000;

// Function to check if migration is needed and run it
async function checkAndRunMigration() {
  try {
    console.log('Checking if migration is needed...');
    
    // Check if any user still has old format (no goalProgress field or empty)
    const usersSnapshot = await db.collection('users').limit(1).get();
    if (usersSnapshot.empty) {
      console.log('No users found, no migration needed');
      return;
    }
    
    // Check first user to see if migration is needed
    const firstUser = usersSnapshot.docs[0];
    const userData = firstUser.data();
    
    // If user doesn't have goalProgress field or it's empty, migration might be needed
    if (!userData.goalProgress || Object.keys(userData.goalProgress).length === 0) {
      // Check if there are any old goalProgress documents
      const oldProgressSnapshot = await db.collection('goalProgress').limit(1).get();
      if (!oldProgressSnapshot.empty) {
        console.log('Old goalProgress documents found, migration needed');
        // Note: In production, you might want to run this manually via API
        // For now, we'll just log that it's needed
      } else {
        console.log('No old goalProgress documents found, no migration needed');
      }
    } else {
      console.log('Users already have new format goalProgress, no migration needed');
    }
  } catch (error) {
    console.error('Error checking migration status:', error);
  }
}

app.listen(PORT, async () => {
  console.log(`Server is running on port ${PORT}`);
  await checkAndRunMigration();
});