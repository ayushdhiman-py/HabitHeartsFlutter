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
        
        return {
          id: doc.id,
          ...data,
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
      ...taskData,
      // Convert back to milliseconds for the response
      createdAt: taskData.createdAt ? taskData.createdAt.toMillis() : Date.now(),
      updatedAt: taskData.updatedAt ? taskData.updatedAt.toMillis() : Date.now(),
      dueDate: taskData.dueDate ? taskData.dueDate.toMillis() : null
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
    
    // Check if the document exists before updating
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      console.log('Task document not found:', taskId);
      return res.status(404).json({ message: 'Task not found' });
    }
    
    await db.collection('tasks').doc(taskId).update(taskData);
    console.log('Task updated successfully:', taskId);
    res.status(200).json({ message: 'Task updated successfully' });
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
      
      return {
        id: doc.id,
        ...data,
        createdAt,
        updatedAt
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
    
    const docRef = await db.collection('goals').add(goalData);
    res.status(201).json({ 
      id: docRef.id, 
      ...goalData,
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
    const goalData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (goalData.createdAt) {
      goalData.createdAt = admin.firestore.Timestamp.fromMillis(goalData.createdAt);
    }
    if (goalData.updatedAt) {
      goalData.updatedAt = admin.firestore.Timestamp.fromMillis(goalData.updatedAt);
    }
    
    await db.collection('goals').doc(req.params.id).update(goalData);
    res.status(200).json({ message: 'Goal updated successfully' });
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
      query = query.where('date', '<=', new Date(endDate));
    }
    
    const snapshot = await query.get();
    
    const events = snapshot.docs.map(doc => {
      const data = doc.data();
      // Convert Firestore Timestamps to milliseconds
      const createdAt = data.createdAt ? data.createdAt.toMillis() : Date.now();
      const updatedAt = data.updatedAt ? data.updatedAt.toMillis() : Date.now();
      
      return {
        id: doc.id,
        ...data,
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
      ...eventData,
      // Convert back to milliseconds for the response
      createdAt: eventData.createdAt ? eventData.createdAt.toMillis() : Date.now(),
      updatedAt: eventData.updatedAt ? eventData.updatedAt.toMillis() : Date.now(),
      date: eventData.date ? eventData.date.toMillis() : null,
      endDate: eventData.endDate ? eventData.endDate.toMillis() : null
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

// Goal progress endpoints
app.get('/api/goalProgress/:goalId', async (req, res) => {
  try {
    const { goalId } = req.params;
    const snapshot = await db.collection('goalProgress')
      .where('goalId', '==', goalId)
      .get();
    
    const progress = snapshot.docs.map(doc => {
      const data = doc.data();
      // Convert Firestore Timestamps to milliseconds
      const createdAt = data.createdAt ? data.createdAt.toMillis() : Date.now();
      const updatedAt = data.updatedAt ? data.updatedAt.toMillis() : Date.now();
      
      return {
        id: doc.id,
        ...data,
        createdAt,
        updatedAt
      };
    });
    
    res.status(200).json(progress);
  } catch (error) {
    console.error('Error getting goal progress:', error);
    res.status(500).json({ message: 'Error getting goal progress' });
  }
});

app.post('/api/goalProgress', async (req, res) => {
  try {
    const progressData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (progressData.createdAt) {
      progressData.createdAt = admin.firestore.Timestamp.fromMillis(progressData.createdAt);
    }
    if (progressData.updatedAt) {
      progressData.updatedAt = admin.firestore.Timestamp.fromMillis(progressData.updatedAt);
    }
    
    const docRef = await db.collection('goalProgress').add(progressData);
    res.status(201).json({ 
      id: docRef.id, 
      ...progressData,
      // Convert back to milliseconds for the response
      createdAt: progressData.createdAt ? progressData.createdAt.toMillis() : Date.now(),
      updatedAt: progressData.updatedAt ? progressData.updatedAt.toMillis() : Date.now()
    });
  } catch (error) {
    console.error('Error creating goal progress:', error);
    res.status(500).json({ message: 'Error creating goal progress' });
  }
});

app.put('/api/goalProgress/:id', async (req, res) => {
  try {
    const progressData = req.body;
    // Convert milliseconds to Firestore Timestamps
    if (progressData.createdAt) {
      progressData.createdAt = admin.firestore.Timestamp.fromMillis(progressData.createdAt);
    }
    if (progressData.updatedAt) {
      progressData.updatedAt = admin.firestore.Timestamp.fromMillis(progressData.updatedAt);
    }
    
    await db.collection('goalProgress').doc(req.params.id).update(progressData);
    res.status(200).json({ message: 'Goal progress updated successfully' });
  } catch (error) {
    console.error('Error updating goal progress:', error);
    res.status(500).json({ message: 'Error updating goal progress' });
  }
});

app.delete('/api/goalProgress/:id', async (req, res) => {
  try {
    await db.collection('goalProgress').doc(req.params.id).delete();
    res.status(200).json({ message: 'Goal progress deleted successfully' });
  } catch (error) {
    console.error('Error deleting goal progress:', error);
    res.status(500).json({ message: 'Error deleting goal progress' });
  }
});

// Toggle goal progress endpoint
app.post('/api/goalProgress/toggle', async (req, res) => {
  try {
    const { goalId, date, userId } = req.body;
    
    // Check if progress already exists for this date
    const snapshot = await db.collection('goalProgress')
      .where('goalId', '==', goalId)
      .where('date', '==', date)
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      // Update existing progress
      const doc = snapshot.docs[0];
      const progress = doc.data();
      const updatedAt = admin.firestore.FieldValue.serverTimestamp();
      await db.collection('goalProgress').doc(doc.id).update({
        completed: !progress.completed,
        updatedAt,
      });
      res.status(200).json({ 
        message: 'Goal progress updated successfully',
        updatedAt: new Date().getTime() // Return milliseconds for consistency
      });
    } else {
      // Create new progress
      const createdAt = admin.firestore.FieldValue.serverTimestamp();
      const updatedAt = admin.firestore.FieldValue.serverTimestamp();
      const newProgress = {
        goalId,
        date,
        userId,
        completed: true,
        createdAt,
        updatedAt,
      };
      
      const docRef = await db.collection('goalProgress').add(newProgress);
      res.status(201).json({ 
        id: docRef.id, 
        ...newProgress,
        // Convert timestamps to milliseconds
        createdAt: new Date().getTime(),
        updatedAt: new Date().getTime()
      });
    }
  } catch (error) {
    console.error('Error toggling goal progress:', error);
    res.status(500).json({ message: 'Error toggling goal progress' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});