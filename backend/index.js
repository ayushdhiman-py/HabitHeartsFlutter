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
    let createdAt = Date.now();
    let updatedAt = Date.now();
    
    // Safely convert createdAt if it exists and is a Firestore Timestamp
    if (data.createdAt) {
      if (typeof data.createdAt.toMillis === 'function') {
        // It's already a Firestore Timestamp
        createdAt = data.createdAt.toMillis();
      } else if (typeof data.createdAt === 'number') {
        // It's already in milliseconds
        createdAt = data.createdAt;
      } else if (data.createdAt instanceof Date) {
        // It's a JavaScript Date object
        createdAt = data.createdAt.getTime();
      }
    }
    
    // Safely convert updatedAt if it exists and is a Firestore Timestamp
    if (data.updatedAt) {
      if (typeof data.updatedAt.toMillis === 'function') {
        // It's already a Firestore Timestamp
        updatedAt = data.updatedAt.toMillis();
      } else if (typeof data.updatedAt === 'number') {
        // It's already in milliseconds
        updatedAt = data.updatedAt;
      } else if (data.updatedAt instanceof Date) {
        // It's a JavaScript Date object
        updatedAt = data.updatedAt.getTime();
      }
    }
    
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

// Get multiple users by their IDs
app.post('/api/users/batch', async (req, res) => {
  try {
    const { userIds } = req.body;
    
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'userIds must be a non-empty array' });
    }
    
    // Limit to 10 users at a time to prevent abuse
    if (userIds.length > 10) {
      return res.status(400).json({ message: 'Cannot fetch more than 10 users at a time' });
    }
    
    // Fetch all users in parallel
    const userPromises = userIds.map(uid => db.collection('users').doc(uid).get());
    const userDocs = await Promise.all(userPromises);
    
    // Process the results
    const users = {};
    userDocs.forEach((doc, index) => {
      const uid = userIds[index];
      if (doc.exists) {
        const data = doc.data();
        // Convert Firestore Timestamps to milliseconds
        let createdAt = Date.now();
        let updatedAt = Date.now();
        
        // Safely convert createdAt if it exists and is a Firestore Timestamp
        if (data.createdAt) {
          if (typeof data.createdAt.toMillis === 'function') {
            createdAt = data.createdAt.toMillis();
          } else if (typeof data.createdAt === 'number') {
            createdAt = data.createdAt;
          } else if (data.createdAt instanceof Date) {
            createdAt = data.createdAt.getTime();
          }
        }
        
        // Safely convert updatedAt if it exists and is a Firestore Timestamp
        if (data.updatedAt) {
          if (typeof data.updatedAt.toMillis === 'function') {
            updatedAt = data.updatedAt.toMillis();
          } else if (typeof data.updatedAt === 'number') {
            updatedAt = data.updatedAt;
          } else if (data.updatedAt instanceof Date) {
            updatedAt = data.updatedAt.getTime();
          }
        }
        
        users[uid] = {
          ...data,
          uid,
          createdAt,
          updatedAt
        };
      }
    });
    
    res.status(200).json(users);
  } catch (error) {
    console.error('Error getting users:', error);
    res.status(500).json({ message: 'Error getting users' });
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

// User linking endpoints
app.post('/api/users/link', async (req, res) => {
  try {
    const { userId, partnerCode } = req.body;
    
    // Find the partner user by their unique code
    const partnerSnapshot = await db.collection('users')
      .where('uniqueCode', '==', partnerCode)
      .limit(1)
      .get();
    
    if (partnerSnapshot.empty) {
      return res.status(404).json({ message: 'Partner not found with that code' });
    }
    
    const partnerDoc = partnerSnapshot.docs[0];
    const partnerUid = partnerDoc.id;
    const partnerData = partnerDoc.data();
    
    // Check if they're already linked
    const currentUserDoc = await db.collection('users').doc(userId).get();
    if (!currentUserDoc.exists) {
      return res.status(404).json({ message: 'Current user not found' });
    }
    
    const currentUserData = currentUserDoc.data();
    
    // Check if already linked
    if (currentUserData.linkedUsers && currentUserData.linkedUsers.includes(partnerUid)) {
      return res.status(400).json({ message: 'Users are already linked' });
    }
    
    // Update both users to link them
    await db.collection('users').doc(userId).update({
      linkedUsers: admin.firestore.FieldValue.arrayUnion(partnerUid),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await db.collection('users').doc(partnerUid).update({
      linkedUsers: admin.firestore.FieldValue.arrayUnion(userId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(200).json({ 
      message: 'Users linked successfully',
      partner: {
        uid: partnerUid,
        displayName: partnerData.displayName,
        email: partnerData.email,
        photoURL: partnerData.photoURL
      }
    });
  } catch (error) {
    console.error('Error linking users:', error);
    res.status(500).json({ message: 'Error linking users' });
  }
});

app.post('/api/users/unlink', async (req, res) => {
  try {
    const { userId, partnerId } = req.body;
    
    // Update both users to unlink them
    await db.collection('users').doc(userId).update({
      linkedUsers: admin.firestore.FieldValue.arrayRemove(partnerId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await db.collection('users').doc(partnerId).update({
      linkedUsers: admin.firestore.FieldValue.arrayRemove(userId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(200).json({ message: 'Users unlinked successfully' });
  } catch (error) {
    console.error('Error unlinking users:', error);
    res.status(500).json({ message: 'Error unlinking users' });
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
    
    // First, get the user to check their linked users
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = userDoc.data();
    const linkedUsers = userData.linkedUsers || [];
    
    // Include the current user in the list of users to fetch tasks for
    const allUserIds = [userId, ...linkedUsers];
    
    // Use a simpler query that doesn't require a composite index
    const snapshot = await db.collection('tasks')
      .where('createdBy', 'in', allUserIds)
      .get();
    
    // Fetch user data for all users to get their display names
    const userDocs = await Promise.all(
      allUserIds.map(uid => db.collection('users').doc(uid).get())
    );
    
    // Create a map of user ID to display name
    const userNames = {};
    userDocs.forEach(userDoc => {
      if (userDoc.exists) {
        const data = userDoc.data();
        userNames[userDoc.id] = data.displayName || 'Unknown';
      }
    });
    
    // Filter by date on the client side
      const tasks = snapshot.docs
        .map(doc => {
          const data = doc.data();
          // Convert Firestore Timestamps to milliseconds
          let createdAt = Date.now();
          if (data.createdAt) {
            if (typeof data.createdAt.toMillis === 'function') {
              createdAt = data.createdAt.toMillis();
            } else if (typeof data.createdAt === 'number') {
              createdAt = data.createdAt;
            } else if (data.createdAt instanceof Date) {
              createdAt = data.createdAt.getTime();
            }
          }
          
          let updatedAt = Date.now();
          if (data.updatedAt) {
            if (typeof data.updatedAt.toMillis === 'function') {
              updatedAt = data.updatedAt.toMillis();
            } else if (typeof data.updatedAt === 'number') {
              updatedAt = data.updatedAt;
            } else if (data.updatedAt instanceof Date) {
              updatedAt = data.updatedAt.getTime();
            }
          }
          
          let dueDate = null;
          if (data.dueDate) {
            if (typeof data.dueDate.toMillis === 'function') {
              dueDate = data.dueDate.toMillis();
            } else if (typeof data.dueDate === 'number') {
              dueDate = data.dueDate;
            } else if (data.dueDate instanceof Date) {
              dueDate = data.dueDate.getTime();
            }
          }
          
          // Remove the original 'id' field from the data to avoid conflict with the document ID
          const { id, ...dataWithoutId } = data;
          
          // Determine creator name - 'You' for current user, actual name for others
          const creatorName = data.createdBy === userId 
            ? 'You' 
            : (userNames[data.createdBy] || 'Unknown');
          
          return {
            id: doc.id,
            ...dataWithoutId,
            creatorName, // Add the creator name
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
    
    // Safely convert Firestore Timestamps to milliseconds for the response
    let dueDate = null;
    if (taskData.dueDate) {
      if (typeof taskData.dueDate.toMillis === 'function') {
        dueDate = taskData.dueDate.toMillis();
      } else if (typeof taskData.dueDate === 'number') {
        dueDate = taskData.dueDate;
      } else if (taskData.dueDate instanceof Date) {
        dueDate = taskData.dueDate.getTime();
      }
    }
    
    let taskCreatedAt = Date.now();
    if (taskData.createdAt) {
      if (typeof taskData.createdAt.toMillis === 'function') {
        taskCreatedAt = taskData.createdAt.toMillis();
      } else if (typeof taskData.createdAt === 'number') {
        taskCreatedAt = taskData.createdAt;
      } else if (taskData.createdAt instanceof Date) {
        taskCreatedAt = taskData.createdAt.getTime();
      }
    }
    
    let taskUpdatedAt = Date.now();
    if (taskData.updatedAt) {
      if (typeof taskData.updatedAt.toMillis === 'function') {
        taskUpdatedAt = taskData.updatedAt.toMillis();
      } else if (typeof taskData.updatedAt === 'number') {
        taskUpdatedAt = taskData.updatedAt;
      } else if (taskData.updatedAt instanceof Date) {
        taskUpdatedAt = taskData.updatedAt.getTime();
      }
    }

    res.status(201).json({ 
      id: docRef.id, 
      text: taskData.text,
      description: taskData.description,
      dueDate: dueDate,
      completed: taskData.completed,
      createdBy: taskData.createdBy,
      creatorName: taskData.creatorName,
      createdAt: taskCreatedAt,
      updatedAt: taskUpdatedAt,
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
    let taskUpdatedAt = Date.now();
    if (taskData.updatedAt) {
      if (typeof taskData.updatedAt.toMillis === 'function') {
        taskUpdatedAt = taskData.updatedAt.toMillis();
      } else if (typeof taskData.updatedAt === 'number') {
        taskUpdatedAt = taskData.updatedAt;
      } else if (taskData.updatedAt instanceof Date) {
        taskUpdatedAt = taskData.updatedAt.getTime();
      } else {
        taskUpdatedAt = taskData.updatedAt;
      }
    }
    
    res.status(200).json({ 
      id: taskId,
      ...taskData,
      updatedAt: taskUpdatedAt
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
    
    // First, get the user to check their linked users
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = userDoc.data();
    const linkedUsers = userData.linkedUsers || [];
    
    // Include the current user in the list of users to fetch goals for
    const allUserIds = [userId, ...linkedUsers];
    
    const snapshot = await db.collection('goals')
      .where('createdBy', 'in', allUserIds)
      .get();
    
    // Fetch user data for all users to get their display names
    const userDocs = await Promise.all(
      allUserIds.map(uid => db.collection('users').doc(uid).get())
    );
    
    // Create a map of user ID to display name
    const userNames = {};
    userDocs.forEach(userDoc => {
      if (userDoc.exists) {
        const data = userDoc.data();
        userNames[userDoc.id] = data.displayName || 'Unknown';
      }
    });
    
    const goals = snapshot.docs.map(doc => {
      const data = doc.data();
      // Convert Firestore Timestamps to milliseconds
      let createdAt = Date.now();
      if (data.createdAt) {
        if (typeof data.createdAt.toMillis === 'function') {
          createdAt = data.createdAt.toMillis();
        } else if (typeof data.createdAt === 'number') {
          createdAt = data.createdAt;
        } else if (data.createdAt instanceof Date) {
          createdAt = data.createdAt.getTime();
        }
      }
      
      let updatedAt = Date.now();
      if (data.updatedAt) {
        if (typeof data.updatedAt.toMillis === 'function') {
          updatedAt = data.updatedAt.toMillis();
        } else if (typeof data.updatedAt === 'number') {
          updatedAt = data.updatedAt;
        } else if (data.updatedAt instanceof Date) {
          updatedAt = data.updatedAt.getTime();
        }
      }
      
      let startDate = null;
      if (data.startDate) {
        if (typeof data.startDate.toMillis === 'function') {
          startDate = data.startDate.toMillis();
        } else if (typeof data.startDate === 'number') {
          startDate = data.startDate;
        } else if (data.startDate instanceof Date) {
          startDate = data.startDate.getTime();
        }
      }
      
      let endDate = null;
      if (data.endDate) {
        if (typeof data.endDate.toMillis === 'function') {
          endDate = data.endDate.toMillis();
        } else if (typeof data.endDate === 'number') {
          endDate = data.endDate;
        } else if (data.endDate instanceof Date) {
          endDate = data.endDate.getTime();
        }
      }
      
      // Remove the original 'id' field from the data to avoid conflict with the document ID
      const { id, ...dataWithoutId } = data;
      
      // Determine creator name - 'You' for current user, actual name for others
      const creatorName = data.createdBy === userId 
        ? 'You' 
        : (userNames[data.createdBy] || 'Unknown');

      return {
        id: doc.id,
        ...dataWithoutId,
        creatorName, // Add the creator name
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
    // Safely convert Firestore Timestamps to milliseconds for the response
    let goalStartDate = null;
    if (goalData.startDate) {
      if (typeof goalData.startDate.toMillis === 'function') {
        goalStartDate = goalData.startDate.toMillis();
      } else if (typeof goalData.startDate === 'number') {
        goalStartDate = goalData.startDate;
      } else if (goalData.startDate instanceof Date) {
        goalStartDate = goalData.startDate.getTime();
      }
    }
    
    let goalEndDate = null;
    if (goalData.endDate) {
      if (typeof goalData.endDate.toMillis === 'function') {
        goalEndDate = goalData.endDate.toMillis();
      } else if (typeof goalData.endDate === 'number') {
        goalEndDate = goalData.endDate;
      } else if (goalData.endDate instanceof Date) {
        goalEndDate = goalData.endDate.getTime();
      }
    }
    
    let goalCreatedAt = Date.now();
    if (goalData.createdAt) {
      if (typeof goalData.createdAt.toMillis === 'function') {
        goalCreatedAt = goalData.createdAt.toMillis();
      } else if (typeof goalData.createdAt === 'number') {
        goalCreatedAt = goalData.createdAt;
      } else if (goalData.createdAt instanceof Date) {
        goalCreatedAt = goalData.createdAt.getTime();
      }
    }
    
    let goalUpdatedAt = Date.now();
    if (goalData.updatedAt) {
      if (typeof goalData.updatedAt.toMillis === 'function') {
        goalUpdatedAt = goalData.updatedAt.toMillis();
      } else if (typeof goalData.updatedAt === 'number') {
        goalUpdatedAt = goalData.updatedAt;
      } else if (goalData.updatedAt instanceof Date) {
        goalUpdatedAt = goalData.updatedAt.getTime();
      }
    }
    
    res.status(201).json({ 
      id: docRef.id, 
      text: goalData.text,
      completed: goalData.completed,
      createdBy: goalData.createdBy,
      creatorName: goalData.creatorName,
      emoji: goalData.emoji,
      status: goalData.status,
      isHabit: goalData.isHabit || false,
      startDate: goalStartDate,
      endDate: goalEndDate,
      // Convert back to milliseconds for the response
      createdAt: goalCreatedAt,
      updatedAt: goalUpdatedAt
    });
  } catch (error) {
    console.error('Error creating goal:', error);
    res.status(500).json({ message: 'Error creating goal' });
  }
});

app.put('/api/goals/:id', async (req, res) => {
  try {
    const { text, status, emoji, startDate, endDate, isHabit, completed, isShared } = req.body;
    const updateData = { updatedAt: admin.firestore.Timestamp.fromMillis(Date.now()) }; // Always update updatedAt

    if (text !== undefined) updateData.text = text;
    if (status !== undefined) updateData.status = status;
    if (emoji !== undefined) updateData.emoji = emoji;
    if (startDate !== undefined) updateData.startDate = admin.firestore.Timestamp.fromMillis(startDate);
    if (endDate !== undefined) updateData.endDate = admin.firestore.Timestamp.fromMillis(endDate);
    if (isHabit !== undefined) updateData.isHabit = isHabit;
    if (completed !== undefined) updateData.completed = completed;
    if (isShared !== undefined) updateData.isShared = isShared;

    await db.collection('goals').doc(req.params.id).update(updateData);

    // Fetch the updated document to return it in the response
    const updatedDoc = await db.collection('goals').doc(req.params.id).get();
    const updatedData = updatedDoc.data();

    res.status(200).json({ 
      id: updatedDoc.id,
      ...updatedData,
      // Safely convert Firestore Timestamps to milliseconds
      createdAt: updatedData.createdAt && typeof updatedData.createdAt.toMillis === 'function' ? 
        updatedData.createdAt.toMillis() : 
        (typeof updatedData.createdAt === 'number' ? updatedData.createdAt : Date.now()),
      updatedAt: updatedData.updatedAt && typeof updatedData.updatedAt.toMillis === 'function' ? 
        updatedData.updatedAt.toMillis() : 
        (typeof updatedData.updatedAt === 'number' ? updatedData.updatedAt : Date.now()),
      isHabit: updatedData.isHabit || false,
      startDate: updatedData.startDate && typeof updatedData.startDate.toMillis === 'function' ? 
        updatedData.startDate.toMillis() : 
        (typeof updatedData.startDate === 'number' ? updatedData.startDate : null),
      endDate: updatedData.endDate && typeof updatedData.endDate.toMillis === 'function' ? 
        updatedData.endDate.toMillis() : 
        (typeof updatedData.endDate === 'number' ? updatedData.endDate : null)
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
    
    // First, get the user to check their linked users
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = userDoc.data();
    const linkedUsers = userData.linkedUsers || [];
    
    // Include the current user in the list of users to fetch events for
    const allUserIds = [userId, ...linkedUsers];
    
    let query = db.collection('calendarEvents').where('createdBy', 'in', allUserIds);
    
    if (startDate) {
      query = query.where('date', '>=', new Date(startDate));
    }
    
    if (endDate) {
      const end = new Date(endDate);
      end.setUTCHours(23, 59, 59, 999); // Set to the end of the day
      query = query.where('date', '<=', end);
    }
    
    const snapshot = await query.get();
    
    // Fetch user data for all users to get their display names
    const userDocs = await Promise.all(
      allUserIds.map(uid => db.collection('users').doc(uid).get())
    );
    
    // Create a map of user ID to display name
    const userNames = {};
    userDocs.forEach(userDoc => {
      if (userDoc.exists) {
        const data = userDoc.data();
        userNames[userDoc.id] = data.displayName || 'Unknown';
      }
    });
    
    const events = snapshot.docs.map(doc => {
      const data = doc.data();
      // Convert Firestore Timestamps to milliseconds
      let createdAt = Date.now();
      if (data.createdAt) {
        if (typeof data.createdAt.toMillis === 'function') {
          createdAt = data.createdAt.toMillis();
        } else if (typeof data.createdAt === 'number') {
          createdAt = data.createdAt;
        } else if (data.createdAt instanceof Date) {
          createdAt = data.createdAt.getTime();
        }
      }
      
      let updatedAt = Date.now();
      if (data.updatedAt) {
        if (typeof data.updatedAt.toMillis === 'function') {
          updatedAt = data.updatedAt.toMillis();
        } else if (typeof data.updatedAt === 'number') {
          updatedAt = data.updatedAt;
        } else if (data.updatedAt instanceof Date) {
          updatedAt = data.updatedAt.getTime();
        }
      }
      
      let eventDate = null;
      if (data.date) {
        if (typeof data.date.toMillis === 'function') {
          eventDate = data.date.toMillis();
        } else if (typeof data.date === 'number') {
          eventDate = data.date;
        } else if (data.date instanceof Date) {
          eventDate = data.date.getTime();
        }
      }
      
      let eventEndDate = null;
      if (data.endDate) {
        if (typeof data.endDate.toMillis === 'function') {
          eventEndDate = data.endDate.toMillis();
        } else if (typeof data.endDate === 'number') {
          eventEndDate = data.endDate;
        } else if (data.endDate instanceof Date) {
          eventEndDate = data.endDate.getTime();
        }
      }

      // Remove the original 'id' field from the data to avoid conflict with the document ID
      const { id, ...dataWithoutId } = data;
      
      // Determine creator name - 'You' for current user, actual name for others
      const creatorName = data.createdBy === userId 
        ? 'You' 
        : (userNames[data.createdBy] || 'Unknown');

      return {
        id: doc.id,
        ...dataWithoutId,
        creatorName, // Add the creator name
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
    // Safely convert Firestore Timestamps to milliseconds for the response
    let eventDate = null;
    if (eventData.date) {
      if (typeof eventData.date.toMillis === 'function') {
        eventDate = eventData.date.toMillis();
      } else if (typeof eventData.date === 'number') {
        eventDate = eventData.date;
      } else if (eventData.date instanceof Date) {
        eventDate = eventData.date.getTime();
      }
    }
    
    let eventEndDate = null;
    if (eventData.endDate) {
      if (typeof eventData.endDate.toMillis === 'function') {
        eventEndDate = eventData.endDate.toMillis();
      } else if (typeof eventData.endDate === 'number') {
        eventEndDate = eventData.endDate;
      } else if (eventData.endDate instanceof Date) {
        eventEndDate = eventData.endDate.getTime();
      }
    }
    
    let eventCreatedAt = Date.now();
    if (eventData.createdAt) {
      if (typeof eventData.createdAt.toMillis === 'function') {
        eventCreatedAt = eventData.createdAt.toMillis();
      } else if (typeof eventData.createdAt === 'number') {
        eventCreatedAt = eventData.createdAt;
      } else if (eventData.createdAt instanceof Date) {
        eventCreatedAt = eventData.createdAt.getTime();
      }
    }
    
    let eventUpdatedAt = Date.now();
    if (eventData.updatedAt) {
      if (typeof eventData.updatedAt.toMillis === 'function') {
        eventUpdatedAt = eventData.updatedAt.toMillis();
      } else if (typeof eventData.updatedAt === 'number') {
        eventUpdatedAt = eventData.updatedAt;
      } else if (eventData.updatedAt instanceof Date) {
        eventUpdatedAt = eventData.updatedAt.getTime();
      }
    }
    
    res.status(201).json({ 
      id: docRef.id, 
      title: eventData.title,
      description: eventData.description,
      date: eventDate,
      endDate: eventEndDate,
      startTime: eventData.startTime,
      endTime: eventData.endTime,
      completed: eventData.completed,
      createdBy: eventData.createdBy,
      creatorName: eventData.creatorName,
      createdAt: eventCreatedAt,
      updatedAt: eventUpdatedAt,
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