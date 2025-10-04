const express = require('express');
const { OAuth2Client } = require('google-auth-library');
const admin = require('firebase-admin');
const rateLimit = require('express-rate-limit');
const { DateTime } = require('luxon'); // For timezone handling
const { WebSocketServer } = require('ws'); // For real-time communication
require('dotenv').config();

// Enhanced logging function
function logger(level, message, metadata = {}) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    ...metadata
  };
  console.log(JSON.stringify(logEntry));
}

const app = express();

// Global variable to hold the broadcast function
let broadcastTaskUpdate = null;

// Rate limiting middleware
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});

// Apply rate limiting to all requests
app.use(limiter);

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

// Authentication middleware
async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ message: 'Access token required' });
  }

  try {
    // Verify the token using Firebase Admin SDK
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    return res.status(403).json({ message: 'Invalid or expired token' });
  }
}

// Authorization middleware to check if user can access resource
function authorizeUser(req, res, next) {
  const requestedUserId = req.params.uid || req.body.userId || req.params.userId;
  const currentUserId = req.user.uid;

  if (requestedUserId && requestedUserId !== currentUserId) {
    // Check if user is trying to access their linked users' data
    if (req.path.includes('/api/tasks/') || req.path.includes('/api/goals/') || req.path.includes('/api/calendarEvents/')) {
      // These endpoints fetch data for linked users, so we'll handle authorization separately
      return next();
    }
    return res.status(403).json({ message: 'Unauthorized access to resource' });
  }
  next();
}

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
    logger('ERROR', 'Google auth error', { error: error.message, stack: error.stack });
    res.status(401).json({ message: 'Invalid Google token' });
  }
});

// User endpoints
app.get('/api/users/:uid', authenticateToken, async (req, res) => {
  try {
    // Check if the requested user is the same as the authenticated user or linked
    if (req.params.uid !== req.user.uid) {
      // Check if user is linked
      const currentUserDoc = await db.collection('users').doc(req.user.uid).get();
      if (!currentUserDoc.exists) {
        return res.status(404).json({ message: 'Current user not found' });
      }
      
      const currentUserData = currentUserDoc.data();
      const linkedUsers = currentUserData.linkedUsers || [];
      
      if (!linkedUsers.includes(req.params.uid)) {
        return res.status(403).json({ message: 'Unauthorized to access user data' });
      }
    }
    
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
app.post('/api/users/batch', authenticateToken, async (req, res) => {
  try {
    const { userIds } = req.body;
    
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'userIds must be a non-empty array' });
    }
    
    // Limit to 30 users at a time to improve scalability
    if (userIds.length > 30) {
      return res.status(400).json({ message: 'Cannot fetch more than 30 users at a time' });
    }
    
    // Check if user has access to these user IDs by validating they're linked
    const currentUserDoc = await db.collection('users').doc(req.user.uid).get();
    if (!currentUserDoc.exists) {
      return res.status(404).json({ message: 'Current user not found' });
    }
    
    const currentUserData = currentUserDoc.data();
    const linkedUsers = currentUserData.linkedUsers || [];
    
    // Filter userIds to only include linked users or self
    const allowedUserIds = userIds.filter(uid => uid === req.user.uid || linkedUsers.includes(uid));
    
    if (allowedUserIds.length !== userIds.length) {
      // Return only allowed users or just the current user if no links exist
      console.warn(`User ${req.user.uid} attempted to access users not linked to them`);
    }
    
    // Fetch all users in parallel
    const userPromises = allowedUserIds.map(uid => db.collection('users').doc(uid).get());
    const userDocs = await Promise.all(userPromises);
    
    // Process the results
    const users = {};
    userDocs.forEach((doc, index) => {
      const uid = allowedUserIds[index];
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

app.post('/api/users', authenticateToken, async (req, res) => {
  try {
    const userData = req.body;
    
    // Validate input
    if (!userData.uid || userData.uid !== req.user.uid) {
      return res.status(400).json({ message: 'User ID must match authenticated user' });
    }
    
    // Sanitize input
    const allowedFields = ['uid', 'displayName', 'email', 'photoURL', 'uniqueCode', 'linkedUsers', 'createdAt', 'updatedAt', 'goalProgress', 'zodiacSign'];
    const sanitizedUserData = {};
    for (const field of allowedFields) {
      if (userData[field] !== undefined) {
        sanitizedUserData[field] = userData[field];
      }
    }
    
    // Convert milliseconds to Firestore Timestamps
    if (sanitizedUserData.createdAt) {
      sanitizedUserData.createdAt = admin.firestore.Timestamp.fromMillis(sanitizedUserData.createdAt);
    }
    if (sanitizedUserData.updatedAt) {
      sanitizedUserData.updatedAt = admin.firestore.Timestamp.fromMillis(sanitizedUserData.updatedAt);
    }
    
    await db.collection('users').doc(sanitizedUserData.uid).set(sanitizedUserData);
    res.status(201).json({ message: 'User created successfully' });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ message: 'Error creating user' });
  }
});

app.put('/api/users/:uid', authenticateToken, async (req, res) => {
  try {
    // Only allow user to update their own data
    if (req.params.uid !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to update this user' });
    }
    
    const userData = req.body;
    
    // Sanitize input - don't allow updating uid
    const allowedFields = ['displayName', 'email', 'photoURL', 'uniqueCode', 'linkedUsers', 'createdAt', 'updatedAt', 'zodiacSign'];
    const sanitizedUserData = {};
    for (const field of allowedFields) {
      if (userData[field] !== undefined) {
        sanitizedUserData[field] = userData[field];
      }
    }
    
    // Convert milliseconds to Firestore Timestamps
    if (sanitizedUserData.createdAt) {
      sanitizedUserData.createdAt = admin.firestore.Timestamp.fromMillis(sanitizedUserData.createdAt);
    }
    if (sanitizedUserData.updatedAt) {
      sanitizedUserData.updatedAt = admin.firestore.Timestamp.fromMillis(sanitizedUserData.updatedAt);
    }
    
    await db.collection('users').doc(req.params.uid).update(sanitizedUserData);
    res.status(200).json({ message: 'User updated successfully' });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ message: 'Error updating user' });
  }
});

// DELETE endpoint for removing a user account
app.delete('/api/users/:uid', authenticateToken, async (req, res) => {
  try {
    const userId = req.params.uid;
    
    // Check if the requested user is the same as the authenticated user
    if (userId !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to delete this user account' });
    }
    
    // Check if the user exists
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Perform cascade deletion:
    // 1. Find and delete all tasks created by this user
    const tasksSnapshot = await db.collection('tasks').where('createdBy', '==', userId).get();
    const taskDeletePromises = [];
    tasksSnapshot.forEach(doc => {
      taskDeletePromises.push(db.collection('tasks').doc(doc.id).delete());
    });
    
    // 2. Find and delete all goals created by this user
    const goalsSnapshot = await db.collection('goals').where('createdBy', '==', userId).get();
    const goalDeletePromises = [];
    goalsSnapshot.forEach(doc => {
      goalDeletePromises.push(db.collection('goals').doc(doc.id).delete());
    });
    
    // 3. Find and delete all calendar events created by this user
    const eventsSnapshot = await db.collection('calendarEvents').where('createdBy', '==', userId).get();
    const eventDeletePromises = [];
    eventsSnapshot.forEach(doc => {
      eventDeletePromises.push(db.collection('calendarEvents').doc(doc.id).delete());
    });
    
    // 4. Update other users to remove this user from their linkedUsers list
    const usersSnapshot = await db.collection('users').where('linkedUsers', 'array-contains', userId).get();
    const unlinkPromises = [];
    usersSnapshot.forEach(doc => {
      const otherUserRef = db.collection('users').doc(doc.id);
      unlinkPromises.push(otherUserRef.update({
        linkedUsers: admin.firestore.FieldValue.arrayRemove(userId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }));
    });
    
    // Execute all deletion promises in parallel
    await Promise.all([
      ...taskDeletePromises,
      ...goalDeletePromises,
      ...eventDeletePromises,
      ...unlinkPromises
    ]);
    
    // Finally, delete the user document itself
    await db.collection('users').doc(userId).delete();
    
    res.status(200).json({ message: 'User and all related data deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ message: 'Error deleting user', error: error.message });
  }
});

// User linking endpoints
app.post('/api/users/link', authenticateToken, async (req, res) => {
  try {
    const { userId, partnerCode } = req.body;
    
    // Ensure the userId matches the authenticated user
    if (userId !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to link with this user ID' });
    }
    
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

app.post('/api/users/unlink', authenticateToken, async (req, res) => {
  try {
    const { userId, partnerId } = req.body;
    
    // Ensure the userId matches the authenticated user
    if (userId !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to unlink with this user ID' });
    }
    
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
app.get('/api/tasks/:userId/:date', authenticateToken, async (req, res) => {
  try {
    const { userId, date } = req.params;
    
    // Check if the requested user is the same as the authenticated user or linked
    if (userId !== req.user.uid) {
      // Check if user is linked
      const currentUserDoc = await db.collection('users').doc(req.user.uid).get();
      if (!currentUserDoc.exists) {
        return res.status(404).json({ message: 'Current user not found' });
      }
      
      const currentUserData = currentUserDoc.data();
      const linkedUsers = currentUserData.linkedUsers || [];
      
      if (!linkedUsers.includes(userId)) {
        return res.status(403).json({ message: 'Unauthorized to access this user\'s tasks' });
      }
    }
    
    // Use timezone-aware date handling
    const taskDate = DateTime.fromISO(date, { zone: 'UTC' });
    const startOfDay = taskDate.startOf('day').toJSDate();
    const endOfDay = taskDate.endOf('day').toJSDate();
    
    // First, get the user to check their linked users
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
      }
      
      const userData = userDoc.data();
      const linkedUsers = userData.linkedUsers || [];
      
      // Include the current user in the list of users to fetch tasks for
      const allUserIds = [userId, ...linkedUsers];
      
      let tasks = [];

      // Fetch tasks created by the requested user
      const userTasksSnapshot = await db.collection('tasks')
        .where('createdBy', '==', userId)
        .get();

      let userTasks = userTasksSnapshot.docs;
      userTasks = userTasks.filter(doc => {
          const data = doc.data();
          if (!data.dueDate) return false;
          const taskDate = data.dueDate.toDate();
          return taskDate >= startOfDay && taskDate <= endOfDay;
      });
      tasks = tasks.concat(userTasks);

      // Fetch shared tasks from linked users (old format - tasks in 'tasks' collection)
      if (linkedUsers.length > 0) {
        for (const linkedId of linkedUsers) {
          const sharedTasksSnapshot = await db.collection('tasks')
            .where('createdBy', '==', linkedId)
            .where('isShared', '==', true)
            .get();
          
          let sharedTasks = sharedTasksSnapshot.docs;
          sharedTasks = sharedTasks.filter(doc => {
              const data = doc.data();
              if (!data.dueDate) return false;
              const taskDate = data.dueDate.toDate();
              return taskDate >= startOfDay && taskDate <= endOfDay;
          });

          tasks = tasks.concat(sharedTasks);
        }
      }
      
      // Fetch new format shared tasks from 'shared_tasks' collection
      // NEW: Fetch shared task documents for linked users
      if (linkedUsers.length > 0) {
        const sharedTasksSnapshot = await db.collection('shared_tasks')
          .where('linkedUserIds', 'array-contains', userId) // Tasks shared with the requesting user
          .get();
        
        // Process shared tasks with async operations
        const sharedTaskPromises = sharedTasksSnapshot.docs.map(async (doc) => {
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
          
          // Determine the completion status for the requesting user
          let userSpecificCompleted = data.completed || false;
          if (data.completionStatus && data.completionStatus[userId] !== undefined) {
            userSpecificCompleted = data.completionStatus[userId];
          }
          
          // Get the user who completed the task
          const completedByUserId = data.completedBy || null;
          let completedByUserDisplayName = 'Unknown';
          if (completedByUserId) {
            const userRef = await db.collection('users').doc(completedByUserId).get();
            if (userRef.exists) {
              const userData = userRef.data();
              completedByUserDisplayName = userData.displayName || completedByUserId;
            }
          }
          
          return {
            id: doc.id,
            ...data.taskData, // Use the task data from the shared task
            // Override with shared-specific properties
            completed: userSpecificCompleted,
            isShared: true, // Mark as shared task
            createdBy: data.ownerId, // Owner of the shared task
            creatorName: data.ownerName || 'Unknown', // Name of the owner
            completedBy: completedByUserId,
            completedByName: completedByUserDisplayName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            dueDate: dueDate
          };
        });

        // Wait for all async operations to complete
        const sharedTasks = await Promise.all(sharedTaskPromises);

        tasks = tasks.concat(sharedTasks);
      }
    
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
    
    // Fetch the authenticated user's task completion data to include per-user completion status
    const authUserDoc = await db.collection('users').doc(req.user.uid).get();
    let authUserTaskCompletion = {};
    if (authUserDoc.exists) {
      const authUserData = authUserDoc.data();
      authUserTaskCompletion = authUserData.taskCompletion || {};
    }
    
    const mappedTasks = tasks
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
        
        // Check if this is a shared task and get the current user's completion status
        let userSpecificCompleted = data.completed; // Default to original completed status
        if (data.isShared && authUserTaskCompletion[doc.id]) {
          // Get the task date to check completion status for that specific date
          let taskDate = null;
          if (data.dueDate) {
            if (typeof data.dueDate.toDate === 'function') {
              taskDate = data.dueDate.toDate();
            } else if (typeof data.dueDate === 'number') {
              taskDate = new Date(data.dueDate);
            } else if (data.dueDate instanceof Date) {
              taskDate = data.dueDate;
            }
          } else {
            // If no due date, use today's date
            taskDate = new Date();
          }
          
          const dateKey = `${taskDate.getFullYear()}-${(taskDate.getMonth() + 1).toString().padStart(2, '0')}-${taskDate.getDate().toString().padStart(2, '0')}`;
          
          // If there's specific completion data for this user for this task on this date, use that
          if (authUserTaskCompletion[doc.id][dateKey] !== undefined) {
            userSpecificCompleted = authUserTaskCompletion[doc.id][dateKey];
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
          completed: userSpecificCompleted, // Use user-specific completion status for shared tasks
          createdAt,
          updatedAt,
          dueDate
        };
      });
    
    res.status(200).json(mappedTasks);
  } catch (error) {
    console.error('Error getting tasks:', error);
    res.status(500).json({ message: 'Error getting tasks' });
  }
});

app.post('/api/tasks', authenticateToken, async (req, res) => {
  try {
    const taskData = req.body;
    
    // Validate input
    if (!taskData.createdBy || taskData.createdBy !== req.user.uid) {
      return res.status(400).json({ message: 'Task must be created by authenticated user' });
    }
    
    // Sanitize input
    const allowedFields = ['text', 'description', 'dueDate', 'completed', 'createdBy', 'creatorName', 'status', 'emoji', 'startTime', 'endTime', 'isShared', 'createdAt', 'updatedAt'];
    const sanitizedTaskData = {};
    for (const field of allowedFields) {
      if (taskData[field] !== undefined) {
        sanitizedTaskData[field] = taskData[field];
      }
    }
    
    console.log('Creating task with data:', sanitizedTaskData);
    
    // Convert milliseconds to Firestore Timestamps
    if (sanitizedTaskData.createdAt) {
      sanitizedTaskData.createdAt = admin.firestore.Timestamp.fromMillis(sanitizedTaskData.createdAt);
    }
    if (sanitizedTaskData.updatedAt) {
      sanitizedTaskData.updatedAt = admin.firestore.Timestamp.fromMillis(sanitizedTaskData.updatedAt);
    }
    if (sanitizedTaskData.dueDate) {
      sanitizedTaskData.dueDate = admin.firestore.Timestamp.fromMillis(sanitizedTaskData.dueDate);
    }
    
    const docRef = await db.collection('tasks').add(sanitizedTaskData);
    console.log('Task created with ID:', docRef.id);
    
    // Safely convert Firestore Timestamps to milliseconds for the response
    let dueDate = null;
    if (sanitizedTaskData.dueDate) {
      if (typeof sanitizedTaskData.dueDate.toMillis === 'function') {
        dueDate = sanitizedTaskData.dueDate.toMillis();
      } else if (typeof sanitizedTaskData.dueDate === 'number') {
        dueDate = sanitizedTaskData.dueDate;
      } else if (typeof sanitizedTaskData.dueDate instanceof Date) {
        dueDate = sanitizedTaskData.dueDate.getTime();
      }
    }
    
    let taskCreatedAt = Date.now();
    if (sanitizedTaskData.createdAt) {
      if (typeof sanitizedTaskData.createdAt.toMillis === 'function') {
        taskCreatedAt = sanitizedTaskData.createdAt.toMillis();
      } else if (typeof sanitizedTaskData.createdAt === 'number') {
        taskCreatedAt = sanitizedTaskData.createdAt;
      } else if (sanitizedTaskData.createdAt instanceof Date) {
        taskCreatedAt = sanitizedTaskData.createdAt.getTime();
      }
    }
    
    let taskUpdatedAt = Date.now();
    if (sanitizedTaskData.updatedAt) {
      if (typeof sanitizedTaskData.updatedAt.toMillis === 'function') {
        taskUpdatedAt = sanitizedTaskData.updatedAt.toMillis();
      } else if (typeof sanitizedTaskData.updatedAt === 'number') {
        taskUpdatedAt = sanitizedTaskData.updatedAt;
      } else if (sanitizedTaskData.updatedAt instanceof Date) {
        taskUpdatedAt = sanitizedTaskData.updatedAt.getTime();
      }
    }

    res.status(201).json({ 
      id: docRef.id, 
      text: sanitizedTaskData.text,
      description: sanitizedTaskData.description,
      dueDate: dueDate,
      completed: sanitizedTaskData.completed,
      createdBy: sanitizedTaskData.createdBy,
      creatorName: sanitizedTaskData.creatorName,
      createdAt: taskCreatedAt,
      updatedAt: taskUpdatedAt,
      status: sanitizedTaskData.status,
      emoji: sanitizedTaskData.emoji,
      startTime: sanitizedTaskData.startTime,
      endTime: sanitizedTaskData.endTime
    });
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ message: 'Error creating task' });
  }
});

app.put('/api/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const taskData = req.body;
    const taskId = req.params.id;
    console.log('Updating task with ID:', taskId, 'data:', taskData);
    
    // Check if the document exists before updating
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      console.log('Task document not found:', taskId);
      return res.status(404).json({ message: 'Task not found' });
    }
    
    // Check if the task belongs to the authenticated user
    const task = taskDoc.data();
    if (task.createdBy !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to update this task' });
    }
    
    // Sanitize input
    const allowedFields = ['text', 'description', 'dueDate', 'completed', 'creatorName', 'status', 'emoji', 'startTime', 'endTime', 'isShared', 'updatedAt'];
    const sanitizedTaskData = {};
    for (const field of allowedFields) {
      if (taskData[field] !== undefined) {
        sanitizedTaskData[field] = taskData[field];
      }
    }
    
    // Create a copy of taskData for Firestore update to avoid modifying the original
    const firestoreTaskData = { ...sanitizedTaskData };
    
    // Convert milliseconds to Firestore Timestamps
    if (firestoreTaskData.updatedAt) {
      firestoreTaskData.updatedAt = admin.firestore.Timestamp.fromMillis(firestoreTaskData.updatedAt);
    }
    if (firestoreTaskData.dueDate) {
      firestoreTaskData.dueDate = admin.firestore.Timestamp.fromMillis(firestoreTaskData.dueDate);
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

app.delete('/api/tasks/:id', authenticateToken, async (req, res) => {
  try {
    const taskId = req.params.id;
    console.log('Deleting task with ID:', taskId);
    
    // Check if the document exists before deleting
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      console.log('Task document not found:', taskId);
      return res.status(404).json({ message: 'Task not found' });
    }
    
    // Check if the task belongs to the authenticated user
    const task = taskDoc.data();
    if (task.createdBy !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to delete this task' });
    }
    
    await db.collection('tasks').doc(taskId).delete();
    console.log('Task deleted successfully:', taskId);
    res.status(200).json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Error deleting task:', error);
    res.status(500).json({ message: 'Error deleting task' });
  }
});

// Shared Task endpoints
app.post('/api/shared-tasks', authenticateToken, async (req, res) => {
  try {
    const taskData = req.body;
    
    // Validate input
    if (!taskData.createdBy || taskData.createdBy !== req.user.uid) {
      return res.status(400).json({ message: 'Shared task must be created by authenticated user' });
    }
    
    if (!taskData.linkedUserIds || !Array.isArray(taskData.linkedUserIds)) {
      return res.status(400).json({ message: 'linkedUserIds array is required' });
    }
    
    // Verify that all linked users are actually linked to the creator
    const userDoc = await db.collection('users').doc(req.user.uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = userDoc.data();
    const linkedUsers = userData.linkedUsers || [];
    
    // Check if all requested users are linked to the creator
    const invalidUsers = taskData.linkedUserIds.filter(userId => !linkedUsers.includes(userId));
    if (invalidUsers.length > 0) {
      return res.status(403).json({ message: `Unauthorized to share tasks with users: ${invalidUsers.join(', ')}` });
    }
    
    // Get the owner's display name
    const ownerName = userData.displayName || req.user.uid;
    
    // Sanitize input - extract task-specific data
    const allowedTaskFields = ['text', 'description', 'dueDate', 'status', 'emoji', 'startTime', 'endTime'];
    const allowedSharedTaskFields = ['isShared', 'completed', 'createdAt', 'updatedAt'];
    
    const taskSpecificData = {};
    for (const field of allowedTaskFields) {
      if (taskData[field] !== undefined) {
        taskSpecificData[field] = taskData[field];
      }
    }
    
    // Ensure isShared is true for shared tasks
    taskSpecificData.isShared = true;
    
    const sharedTaskData = {};
    for (const field of allowedSharedTaskFields) {
      if (taskData[field] !== undefined) {
        sharedTaskData[field] = taskData[field];
      }
    }
    
    // Add shared task specific properties
    sharedTaskData.taskData = taskSpecificData;
    sharedTaskData.ownerId = req.user.uid;
    sharedTaskData.ownerName = ownerName;
    sharedTaskData.linkedUserIds = [...new Set([...taskData.linkedUserIds, req.user.uid])]; // Include owner in linkedUserIds
    sharedTaskData.completionStatus = {}; // Initialize completion status map
    sharedTaskData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    sharedTaskData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    
    // Create the shared task document
    const docRef = await db.collection('shared_tasks').add(sharedTaskData);
    
    console.log('Shared task created with ID:', docRef.id);
    
    // Format response similar to regular tasks
    let dueDate = null;
    if (taskSpecificData.dueDate) {
      if (typeof taskSpecificData.dueDate.toMillis === 'function') {
        dueDate = taskSpecificData.dueDate.toMillis();
      } else if (typeof taskSpecificData.dueDate === 'number') {
        dueDate = taskSpecificData.dueDate;
      } else if (taskSpecificData.dueDate instanceof Date) {
        dueDate = taskSpecificData.dueDate.getTime();
      }
    }
    
    const createdAt = sharedTaskData.createdAt.toMillis ? sharedTaskData.createdAt.toMillis() : Date.now();
    const updatedAt = sharedTaskData.updatedAt.toMillis ? sharedTaskData.updatedAt.toMillis() : Date.now();
    
    res.status(201).json({ 
      id: docRef.id,
      ...taskSpecificData,
      completed: sharedTaskData.completed || false,
      isShared: true,
      createdBy: req.user.uid,
      creatorName: ownerName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      dueDate: dueDate
    });
    
  } catch (error) {
    console.error('Error creating shared task:', error);
    res.status(500).json({ message: 'Error creating shared task', error: error.message });
  }
});

// Update shared task endpoint
app.put('/api/shared-tasks/:id', authenticateToken, async (req, res) => {
  try {
    const taskData = req.body;
    const taskId = req.params.id;
    
    console.log('Updating shared task with ID:', taskId, 'data:', taskData);
    
    // Check if the shared task document exists
    const sharedTaskDoc = await db.collection('shared_tasks').doc(taskId).get();
    if (!sharedTaskDoc.exists) {
      console.log('Shared task document not found:', taskId);
      return res.status(404).json({ message: 'Shared task not found' });
    }
    
    const sharedTask = sharedTaskDoc.data();
    
    // Only the owner can update shared tasks
    if (sharedTask.ownerId !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to update this shared task' });
    }
    
    // Sanitize input - only allow updating task data fields, not shared-specific fields
    const allowedTaskFields = ['text', 'description', 'dueDate', 'status', 'emoji', 'startTime', 'endTime'];
    
    const updateData = {};
    for (const field of allowedTaskFields) {
      if (taskData[field] !== undefined) {
        updateData[`taskData.${field}`] = taskData[field];
      }
    }
    
    updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    
    // Update the shared task document
    await db.collection('shared_tasks').doc(taskId).update(updateData);
    console.log('Shared task updated successfully:', taskId);
    
    // Get the updated document for response
    const updatedDoc = await db.collection('shared_tasks').doc(taskId).get();
    const updatedData = updatedDoc.data();
    
    let dueDate = null;
    if (updatedData.taskData.dueDate) {
      if (typeof updatedData.taskData.dueDate.toMillis === 'function') {
        dueDate = updatedData.taskData.dueDate.toMillis();
      } else if (typeof updatedData.taskData.dueDate === 'number') {
        dueDate = updatedData.taskData.dueDate;
      } else if (updatedData.taskData.dueDate instanceof Date) {
        dueDate = updatedData.taskData.dueDate.getTime();
      }
    }
    
    const updatedAt = updatedData.updatedAt.toMillis ? updatedData.updatedAt.toMillis() : Date.now();
    
    res.status(200).json({ 
      id: taskId,
      ...updatedData.taskData,
      completed: updatedData.completed || false,
      isShared: true,
      createdBy: updatedData.ownerId,
      creatorName: updatedData.ownerName || 'Unknown',
      createdAt: updatedData.createdAt.toMillis ? updatedData.createdAt.toMillis() : Date.now(),
      updatedAt: updatedAt,
      dueDate: dueDate
    });
    
  } catch (error) {
    console.error('Error updating shared task:', error);
    res.status(500).json({ message: 'Error updating shared task', error: error.message });
  }
});

// Toggle shared task completion endpoint
app.post('/api/shared-tasks/:taskId/toggle', authenticateToken, async (req, res) => {
  try {
    const { taskId } = req.params;
    const { completed } = req.body;
    const userId = req.user.uid; // The user toggling the task
    
    console.log('Toggling shared task completion for user:', userId, 'task:', taskId, 'status:', completed);
    
    // Check if the shared task document exists
    const sharedTaskDoc = await db.collection('shared_tasks').doc(taskId).get();
    if (!sharedTaskDoc.exists) {
      console.log('Shared task document not found:', taskId);
      return res.status(404).json({ message: 'Shared task not found' });
    }
    
    const sharedTask = sharedTaskDoc.data();
    
    // Verify that the requesting user has access to this shared task
    const hasAccess = [sharedTask.ownerId, ...sharedTask.linkedUserIds].includes(userId);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Unauthorized to toggle completion for this shared task' });
    }
    
    // Update the shared task document with completion status and who completed it
    const updateData = {
      completed: completed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Update the completion status map for the current user
    updateData[`completionStatus.${userId}`] = completed;
    
    // Only update completedBy if the task is being completed (not uncompleted)
    if (completed) {
      updateData.completedBy = userId;
    } else {
      // When uncompleting, set completedBy to null if the current user was the one who completed it
      if (sharedTask.completedBy === userId) {
        updateData.completedBy = null;
      }
    }
    
    await db.collection('shared_tasks').doc(taskId).update(updateData);
    
    // Get the updated document for response
    const updatedDoc = await db.collection('shared_tasks').doc(taskId).get();
    const updatedData = updatedDoc.data();
    
    // Get the display name of the user who completed the task
    let completedByUserDisplayName = 'Unknown';
    if (updatedData.completedBy) {
      const userRef = await db.collection('users').doc(updatedData.completedBy).get();
      if (userRef.exists) {
        const userData = userRef.data();
        completedByUserDisplayName = userData.displayName || updatedData.completedBy;
        console.log('Task completed by user:', userData.displayName || updatedData.completedBy);
      }
    }
    
    // Broadcast the update to all subscribed clients
    if (broadcastTaskUpdate && typeof broadcastTaskUpdate === 'function') {
      broadcastTaskUpdate(taskId, {
        completed: updatedData.completed,
        completedBy: updatedData.completedBy,
        completedByName: completedByUserDisplayName,
        updatedAt: updatedData.updatedAt ? updatedData.updatedAt.toMillis() : Date.now()
      });
    } else {
      console.log('Broadcast function not available in this scope');
    }
    
    console.log('Shared task completion status updated successfully');
    res.status(200).json({ 
      message: 'Shared task completion status updated successfully',
      completed: updatedData.completed,
      completedBy: updatedData.completedBy,
      completedByName: completedByUserDisplayName,
      taskId: taskId,
      userId: userId
    });
    
  } catch (error) {
    console.error('Error toggling shared task completion:', error);
    res.status(500).json({ message: 'Error toggling shared task completion', error: error.message });
  }
});

// Delete shared task endpoint
app.delete('/api/shared-tasks/:id', authenticateToken, async (req, res) => {
  try {
    const taskId = req.params.id;
    console.log('Deleting shared task with ID:', taskId);
    
    // Check if the shared task document exists
    const sharedTaskDoc = await db.collection('shared_tasks').doc(taskId).get();
    if (!sharedTaskDoc.exists) {
      console.log('Shared task document not found:', taskId);
      return res.status(404).json({ message: 'Shared task not found' });
    }
    
    const sharedTask = sharedTaskDoc.data();
    
    // Only the owner can delete shared tasks
    if (sharedTask.ownerId !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to delete this shared task' });
    }
    
    // Delete the shared task document
    await db.collection('shared_tasks').doc(taskId).delete();
    console.log('Shared task deleted successfully:', taskId);
    res.status(200).json({ message: 'Shared task deleted successfully' });
    
  } catch (error) {
    console.error('Error deleting shared task:', error);
    res.status(500).json({ message: 'Error deleting shared task' });
  }
});

// Goal endpoints
app.get('/api/goals/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Check if the requested user is the same as the authenticated user or linked
    if (userId !== req.user.uid) {
      // Check if user is linked
      const currentUserDoc = await db.collection('users').doc(req.user.uid).get();
      if (!currentUserDoc.exists) {
        return res.status(404).json({ message: 'Current user not found' });
      }
      
      const currentUserData = currentUserDoc.data();
      const linkedUsers = currentUserData.linkedUsers || [];
      
      if (!linkedUsers.includes(userId)) {
        return res.status(403).json({ message: 'Unauthorized to access this user\'s goals' });
      }
    }
    
    // First, get the user to check their linked users
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = userDoc.data();
    const linkedUsers = userData.linkedUsers || [];
    
    // Include the current user in the list of users to fetch goals for
    const allUserIds = [userId, ...linkedUsers];
    
    let goals = [];

    // Fetch goals created by the requested user
    const userGoalsSnapshot = await db.collection('goals')
      .where('createdBy', '==', userId)
      .get();
    goals = goals.concat(userGoalsSnapshot.docs);

    // Fetch shared goals from linked users
    if (linkedUsers.length > 0) {
      for (const linkedId of linkedUsers) {
        const sharedGoalsSnapshot = await db.collection('goals')
          .where('createdBy', '==', linkedId)
          .where('isShared', '==', true)
          .get();
        goals = goals.concat(sharedGoalsSnapshot.docs);
      }
    }
    
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
    
    const filteredGoals = goals.map(doc => {
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
    
    res.status(200).json(filteredGoals);
  } catch (error) {
    console.error('Error getting goals:', error);
    res.status(500).json({ message: 'Error getting goals' });
  }
});

app.post('/api/goals', authenticateToken, async (req, res) => {
  try {
    const goalData = req.body;
    
    // Validate input
    if (!goalData.createdBy || goalData.createdBy !== req.user.uid) {
      return res.status(400).json({ message: 'Goal must be created by authenticated user' });
    }
    
    // Sanitize input
    const allowedFields = ['text', 'completed', 'createdBy', 'creatorName', 'emoji', 'status', 'isHabit', 'startDate', 'endDate', 'isShared', 'createdAt', 'updatedAt'];
    const sanitizedGoalData = {};
    for (const field of allowedFields) {
      if (goalData[field] !== undefined) {
        sanitizedGoalData[field] = goalData[field];
      }
    }
    
    // Convert milliseconds to Firestore Timestamps
    if (sanitizedGoalData.createdAt) {
      sanitizedGoalData.createdAt = admin.firestore.Timestamp.fromMillis(sanitizedGoalData.createdAt);
    }
    if (sanitizedGoalData.updatedAt) {
      sanitizedGoalData.updatedAt = admin.firestore.Timestamp.fromMillis(sanitizedGoalData.updatedAt);
    }
    if (sanitizedGoalData.startDate) {
      sanitizedGoalData.startDate = admin.firestore.Timestamp.fromMillis(sanitizedGoalData.startDate);
    } else {
      sanitizedGoalData.startDate = null; // Explicitly set to null if not provided
    }
    if (sanitizedGoalData.endDate) {
      sanitizedGoalData.endDate = admin.firestore.Timestamp.fromMillis(sanitizedGoalData.endDate);
    } else {
      sanitizedGoalData.endDate = null; // Explicitly set to null if not provided
    }
    
    const docRef = await db.collection('goals').add(sanitizedGoalData);
    // Safely convert Firestore Timestamps to milliseconds for the response
    let goalStartDate = null;
    if (sanitizedGoalData.startDate) {
      if (typeof sanitizedGoalData.startDate.toMillis === 'function') {
        goalStartDate = sanitizedGoalData.startDate.toMillis();
      } else if (typeof sanitizedGoalData.startDate === 'number') {
        goalStartDate = sanitizedGoalData.startDate;
      } else if (typeof sanitizedGoalData.startDate instanceof Date) {
        goalStartDate = sanitizedGoalData.startDate.getTime();
      }
    }
    
    let goalEndDate = null;
    if (sanitizedGoalData.endDate) {
      if (typeof sanitizedGoalData.endDate.toMillis === 'function') {
        goalEndDate = sanitizedGoalData.endDate.toMillis();
      } else if (typeof sanitizedGoalData.endDate === 'number') {
        goalEndDate = sanitizedGoalData.endDate;
      } else if (typeof sanitizedGoalData.endDate instanceof Date) {
        goalEndDate = sanitizedGoalData.endDate.getTime();
      }
    }
    
    let goalCreatedAt = Date.now();
    if (sanitizedGoalData.createdAt) {
      if (typeof sanitizedGoalData.createdAt.toMillis === 'function') {
        goalCreatedAt = sanitizedGoalData.createdAt.toMillis();
      } else if (typeof sanitizedGoalData.createdAt === 'number') {
        goalCreatedAt = sanitizedGoalData.createdAt;
      } else if (typeof sanitizedGoalData.createdAt instanceof Date) {
        goalCreatedAt = sanitizedGoalData.createdAt.getTime();
      }
    }
    
    let goalUpdatedAt = Date.now();
    if (sanitizedGoalData.updatedAt) {
      if (typeof sanitizedGoalData.updatedAt.toMillis === 'function') {
        goalUpdatedAt = sanitizedGoalData.updatedAt.toMillis();
      } else if (typeof sanitizedGoalData.updatedAt === 'number') {
        goalUpdatedAt = sanitizedGoalData.updatedAt;
      } else if (typeof sanitizedGoalData.updatedAt instanceof Date) {
        goalUpdatedAt = sanitizedGoalData.updatedAt.getTime();
      }
    }
    
    res.status(201).json({ 
      id: docRef.id, 
      text: sanitizedGoalData.text,
      completed: sanitizedGoalData.completed,
      createdBy: sanitizedGoalData.createdBy,
      creatorName: sanitizedGoalData.creatorName,
      emoji: sanitizedGoalData.emoji,
      status: sanitizedGoalData.status,
      isHabit: sanitizedGoalData.isHabit || false,
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

app.put('/api/goals/:id', authenticateToken, async (req, res) => {
  try {
    const goalId = req.params.id;
    
    // Check if the document exists before updating
    const goalDoc = await db.collection('goals').doc(goalId).get();
    if (!goalDoc.exists) {
      return res.status(404).json({ message: 'Goal not found' });
    }
    
    // Check if the goal belongs to the authenticated user
    const goal = goalDoc.data();
    if (goal.createdBy !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to update this goal' });
    }
    
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

    await db.collection('goals').doc(goalId).update(updateData);

    // Fetch the updated document to return it in the response
    const updatedDoc = await db.collection('goals').doc(goalId).get();
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

app.delete('/api/goals/:id', authenticateToken, async (req, res) => {
  try {
    const goalId = req.params.id;
    
    // Check if the document exists before deleting
    const goalDoc = await db.collection('goals').doc(goalId).get();
    if (!goalDoc.exists) {
      return res.status(404).json({ message: 'Goal not found' });
    }
    
    // Check if the goal belongs to the authenticated user
    const goal = goalDoc.data();
    if (goal.createdBy !== req.user.uid) {
      return res.status(403).json({ message: 'Unauthorized to delete this goal' });
    }
    
    // Perform cascade deletion: remove progress data for this goal
    const userId = goal.createdBy;
    try {
      // Delete the goal from the user's goalProgress if it exists
      const userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        const goalProgress = userData.goalProgress || {};
        
        // Remove the goal from goalProgress
        if (goalProgress[goalId]) {
          delete goalProgress[goalId];
          
          // Update the user document
          await db.collection('users').doc(userId).update({
            goalProgress
          });
        }
      }
    } catch (progressError) {
      // If deleting progress fails, log but continue with goal deletion
      console.error('Error deleting goal progress:', progressError);
    }
    
    await db.collection('goals').doc(goalId).delete();
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
app.get('/api/calendarEvents/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Check if the requested user is the same as the authenticated user or linked
    if (userId !== req.user.uid) {
      // Check if user is linked
      const currentUserDoc = await db.collection('users').doc(req.user.uid).get();
      if (!currentUserDoc.exists) {
        return res.status(404).json({ message: 'Current user not found' });
      }
      
      const currentUserData = currentUserDoc.data();
      const linkedUsers = currentUserData.linkedUsers || [];
      
      if (!linkedUsers.includes(userId)) {
        return res.status(403).json({ message: 'Unauthorized to access this user\'s calendar events' });
      }
    }
    
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
    
    let events = [];

    // Fetch events created by the requested user
    const userEventsSnapshot = await db.collection('calendarEvents')
      .where('createdBy', '==', userId)
      .get();

    let userEvents = userEventsSnapshot.docs;
    if (startDate || endDate) {
        const start = startDate ? DateTime.fromISO(startDate, { zone: 'UTC' }).toJSDate() : null;
        const end = endDate ? DateTime.fromISO(endDate, { zone: 'UTC' }).endOf('day').toJSDate() : null;

        userEvents = userEvents.filter(doc => {
            const data = doc.data();
            if (!data.date) return false;
            const eventDate = data.date.toDate();
            if (start && eventDate < start) return false;
            if (end && eventDate > end) return false;
            return true;
        });
    }
    events = events.concat(userEvents);

    // Fetch shared events from linked users
    if (linkedUsers.length > 0) {
      for (const linkedId of linkedUsers) {
        const sharedEventsSnapshot = await db.collection('calendarEvents')
          .where('createdBy', '==', linkedId)
          .where('isShared', '==', true)
          .get();
        
        let sharedEvents = sharedEventsSnapshot.docs;

        if (startDate || endDate) {
            const start = startDate ? DateTime.fromISO(startDate, { zone: 'UTC' }).toJSDate() : null;
            const end = endDate ? DateTime.fromISO(endDate, { zone: 'UTC' }).endOf('day').toJSDate() : null;

            sharedEvents = sharedEvents.filter(doc => {
                const data = doc.data();
                if (!data.date) return false;
                const eventDate = data.date.toDate();
                if (start && eventDate < start) return false;
                if (end && eventDate > end) return false;
                return true;
            });
        }
        
        events = events.concat(sharedEvents);
      }
    }
    
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
    
    const filteredEvents = events.map(doc => {
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
    
    res.status(200).json(filteredEvents);
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
    const streaks = calculateStreaks(goalProgress[goalId]);
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

// Helper function to calculate streaks accurately across all months
function calculateStreaks(progressData) {
  // Calculate current streak (counting backwards from today)  
  let currentStreak = 0;
  const today = new Date();
  let currentDate = new Date(today);
  let continueCounting = true;
  
  while (continueCounting) {
    const currentYearMonth = `${currentDate.getFullYear()}-${(currentDate.getMonth() + 1).toString().padStart(2, '0')}`;
    const currentDay = currentDate.getDate();
    
    // Check if we have data for this month
    if (!progressData.monthlyData[currentYearMonth]) {
      // If no data for this month, break the streak counting
      break;
    }
    
    const bitString = progressData.monthlyData[currentYearMonth];
    const index = currentDay - 1;
    
    // Check if index is valid and day exists in bitString
    if (index >= 0 && index < bitString.length) {
      if (bitString[index] === '1') {
        // Day is completed, increment streak
        currentStreak++;
        // Move to previous day
        currentDate.setDate(currentDate.getDate() - 1);
      } else {
        // Day is not completed, stop the streak counting
        continueCounting = false;
      }
    } else {
      // Day doesn't exist in this month, go to previous day
      currentDate.setDate(currentDate.getDate() - 1);
    }
    
    // Check if we've gone beyond a reasonable date range (e.g., more than 2 years back)
    if (currentDate < new Date(today.getFullYear() - 2, today.getMonth(), today.getDate())) {
      break;
    }
  }
  
  // Calculate longest streak by checking all possible streaks
  let longestStreak = 0;
  let currentPotentialStreak = 0;
  let inStreak = false;
  
  // Get all months in chronological order
  const months = Object.keys(progressData.monthlyData).sort();
  
  // Process each month to calculate longest streak
  for (const month of months) {
    const bitString = progressData.monthlyData[month];
    if (!bitString) continue;
    
    // For each day in this month
    for (let i = 0; i < bitString.length; i++) {
      if (bitString[i] === '1') {
        // Day is completed, increment streak
        currentPotentialStreak++;
        inStreak = true;
      } else {
        // Day is not completed, reset streak counter
        if (inStreak) {
          longestStreak = Math.max(longestStreak, currentPotentialStreak);
          currentPotentialStreak = 0;
          inStreak = false;
        }
      }
    }
  }
  
  // Don't forget to check the final potential streak if it was ongoing
  if (inStreak) {
    longestStreak = Math.max(longestStreak, currentPotentialStreak);
  }
  
  // Also consider the stored longest streak value
  longestStreak = Math.max(longestStreak, progressData.longestStreak || 0);
  
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

// Toggle task completion endpoint for linked users
// Toggle shared task completion endpoint - new format for shared tasks
app.post('/api/tasks/:taskId/toggle-shared-completion', async (req, res) => {
  console.log('DEBUG: Toggle shared task completion endpoint called');
  console.log('DEBUG: Params:', { taskId: req.params.taskId });
  console.log('DEBUG: Body:', { completed: req.body.completed });
  console.log('DEBUG: Headers:', req.headers);

  try {
    const { taskId } = req.params;
    const { completed } = req.body;
    
    // Verify the user is authenticated
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN
    
    if (!token) {
      console.log('DEBUG: No authorization token provided');
      return res.status(401).json({ message: 'Access token required' });
    }
    
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(token);
      console.log('DEBUG: Token verified, decoded token UID:', decodedToken.uid);
    } catch (error) {
      console.error('Token verification error:', error);
      return res.status(403).json({ message: 'Invalid or expired token' });
    }
    
    const requestUserId = decodedToken.uid;
    console.log('DEBUG: Requesting user ID:', requestUserId, 'Task ID:', taskId);
    
    // Check if this is a shared task document from the shared_tasks collection
    const sharedTaskDoc = await db.collection('shared_tasks').doc(taskId).get();
    if (sharedTaskDoc.exists) {
      console.log('DEBUG: Found shared task in shared_tasks collection');
      const taskData = sharedTaskDoc.data();
      
      // Verify that the requesting user has access to this shared task
      const hasAccess = [taskData.ownerId, ...(taskData.linkedUserIds || [])].includes(requestUserId);
      if (!hasAccess) {
        console.log('DEBUG: Requesting user does not have access to this shared task');
        return res.status(403).json({ message: 'Unauthorized to toggle completion for this shared task' });
      }
      
      // Update the shared task document with completion status for the requesting user
      const updateData = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Update the completion status map for the current user
      updateData[`completionStatus.${requestUserId}`] = completed;
      
      // Only update completedBy if the task is being completed (not uncompleted)
      if (completed) {
        updateData.completedBy = requestUserId;
      } else {
        // When uncompleting, set completedBy to null if the current user was the one who completed it
        if (taskData.completedBy === requestUserId) {
          updateData.completedBy = null;
        }
      }
      
      await db.collection('shared_tasks').doc(taskId).update(updateData);
      
      // Get the updated document for response
      const updatedDoc = await db.collection('shared_tasks').doc(taskId).get();
      const updatedData = updatedDoc.data();
      
      // Get the display name of the user who completed the task
      let completedByUserDisplayName = 'Unknown';
      if (updatedData.completedBy) {
        const userRef = await db.collection('users').doc(updatedData.completedBy).get();
        if (userRef.exists) {
          const userData = userRef.data();
          completedByUserDisplayName = userData.displayName || updatedData.completedBy;
          console.log('Shared task completed by user:', userData.displayName || updatedData.completedBy);
        }
      }
      
      // Broadcast the update to all subscribed clients
      if (broadcastTaskUpdate && typeof broadcastTaskUpdate === 'function') {
        broadcastTaskUpdate(taskId, {
          completed: updatedData.completed,
          completedBy: updatedData.completedBy,
          completedByName: completedByUserDisplayName,
          updatedAt: updatedData.updatedAt ? updatedData.updatedAt.toMillis() : Date.now()
        });
      } else {
        console.log('Broadcast function not available in this scope');
      }
      
      console.log('DEBUG: Shared task completion status updated successfully');
      res.status(200).json({ 
        message: 'Shared task completion status updated successfully',
        completed: updatedData.completionStatus && updatedData.completionStatus[requestUserId] !== undefined 
          ? updatedData.completionStatus[requestUserId] 
          : updatedData.completed,
        completedBy: updatedData.completedBy,
        completedByName: completedByUserDisplayName,
        taskId: taskId,
        userId: requestUserId
      });
      return;
    }
    
    // If not found in shared_tasks, look in regular tasks collection
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      console.log('DEBUG: Task document does not exist in either collection');
      return res.status(404).json({ message: 'Task not found' });
    }
    
    const taskData = taskDoc.data();
    console.log('DEBUG: Regular task data:', { isShared: taskData.isShared, createdBy: taskData.createdBy });
    
    // Check if this is a shared task and if the requesting user has permission to complete it
    let hasPermission = false;
    if (taskData.createdBy === requestUserId) {
      // Task owner can always toggle
      hasPermission = true;
      console.log('DEBUG: Requesting user is task owner - permission granted');
    } else if (taskData.isShared) {
      // For shared tasks, check if requesting user is linked to the task owner
      const taskOwnerDoc = await db.collection('users').doc(taskData.createdBy).get();
      if (taskOwnerDoc.exists) {
        const taskOwnerData = taskOwnerDoc.data();
        const taskOwnerLinkedUsers = taskOwnerData.linkedUsers || [];
        if (taskOwnerLinkedUsers.includes(requestUserId)) {
          hasPermission = true;
          console.log('DEBUG: Requesting user is linked to task owner - permission granted');
        } else {
          console.log('DEBUG: Requesting user is not linked to task owner - permission denied');
        }
      } else {
        console.log('DEBUG: Task owner document does not exist');
      }
    } else {
      console.log('DEBUG: Task is not shared and requesting user is not owner - permission denied');
    }
    
    if (!hasPermission) {
      return res.status(403).json({ message: 'Unauthorized to toggle completion for this task' });
    }
    
    // Update the MAIN TASK's completion status
    console.log('DEBUG: Updating main task completion status to:', completed, 'for user:', requestUserId);
    const updateData = {
      completed: completed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Only update completedBy if the task is being completed (not uncompleted)
    if (completed) {
      updateData.completedBy = requestUserId;
    } else {
      // When uncompleting, set completedBy to null
      updateData.completedBy = null;
    }
    
    await db.collection('tasks').doc(taskId).update(updateData);
    
    // Also update the user-specific completion status (for consistency with existing design)
    const requestUserDoc = await db.collection('users').doc(requestUserId).get();
    if (!requestUserDoc.exists) {
      console.log('DEBUG: Requesting user document does not exist');
      return res.status(404).json({ message: 'User not found' });
    }

    const userData = requestUserDoc.data();
    let taskCompletionData = userData.taskCompletion || {};
    
    // Initialize task completion data if it doesn't exist
    if (!taskCompletionData[taskId]) {
      console.log('DEBUG: Initializing task completion data for task:', taskId);
      taskCompletionData[taskId] = {};
    }
    
    // Record the completion status for today
    const today = new Date();
    const dateKey = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    console.log('DEBUG: Updating user-specific completion for date:', dateKey, 'Status:', completed);
    taskCompletionData[taskId][dateKey] = completed;
    
    // Update user document
    console.log('DEBUG: Updating user document with new task completion data');
    await db.collection('users').doc(requestUserId).update({
      taskCompletion: taskCompletionData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Get the display name of the user who completed the task
    let completedByDisplayName = 'Unknown';
    if (requestUserId) {
      const userRef = await db.collection('users').doc(requestUserId).get();
      if (userRef.exists) {
        const userData = userRef.data();
        completedByDisplayName = userData.displayName || requestUserId;
      }
    }
    
    // Verify the main task update
    const updatedTaskDoc = await db.collection('tasks').doc(taskId).get();
    const updatedTaskData = updatedTaskDoc.data();
    console.log('DEBUG: Verification - Updated main task data:', { 
      completed: updatedTaskData.completed, 
      completedBy: updatedTaskData.completedBy 
    });
    
    console.log('DEBUG: Task completion status updated successfully in main task document');
    res.status(200).json({ 
      message: 'Task completion status updated successfully',
      completed: updatedTaskData.completed,
      completedBy: updatedTaskData.completedBy,
      completedByName: completedByDisplayName,
      taskId: taskId,
      userId: requestUserId
    });
    
  } catch (error) {
    console.error('Error toggling shared task completion:', error);
    res.status(500).json({ message: 'Error toggling shared task completion', error: error.message });
  }
});

// Toggle task completion endpoint for linked users - updates main task completion status
app.post('/api/user/:userId/task/:taskId/toggle', async (req, res) => {
  console.log('DEBUG: Toggle task completion endpoint called');
  console.log('DEBUG: Params:', { userId: req.params.userId, taskId: req.params.taskId });
  console.log('DEBUG: Body:', { completed: req.body.completed });
  console.log('DEBUG: Headers:', req.headers);

  try {
    const { userId, taskId } = req.params;
    const { completed } = req.body;
    
    // Verify the user is authenticated
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN
    
    if (!token) {
      console.log('DEBUG: No authorization token provided');
      return res.status(401).json({ message: 'Access token required' });
    }
    
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(token);
      console.log('DEBUG: Token verified, decoded token UID:', decodedToken.uid);
    } catch (error) {
      console.error('Token verification error:', error);
      return res.status(403).json({ message: 'Invalid or expired token' });
    }
    
    const requestUserId = decodedToken.uid;
    console.log('DEBUG: Request user ID:', requestUserId, 'Target userId for completion storage:', userId);
    
    // Verify that the requesting user is either:
    // 1. The task owner, OR
    // 2. A linked user trying to toggle a shared task
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      console.log('DEBUG: Task document does not exist');
      return res.status(404).json({ message: 'Task not found' });
    }
    
    const taskData = taskDoc.data();
    console.log('DEBUG: Task data:', { isShared: taskData.isShared, createdBy: taskData.createdBy });
    
    // Check if this is a shared task and if the requesting user has permission to complete it
    let hasPermission = false;
    if (taskData.createdBy === requestUserId) {
      // Task owner can always toggle
      hasPermission = true;
      console.log('DEBUG: Requesting user is task owner - permission granted');
    } else if (taskData.isShared) {
      // For shared tasks, check if requesting user is linked to the task owner
      const taskOwnerDoc = await db.collection('users').doc(taskData.createdBy).get();
      if (taskOwnerDoc.exists) {
        const taskOwnerData = taskOwnerDoc.data();
        const taskOwnerLinkedUsers = taskOwnerData.linkedUsers || [];
        if (taskOwnerLinkedUsers.includes(requestUserId)) {
          hasPermission = true;
          console.log('DEBUG: Requesting user is linked to task owner - permission granted');
        } else {
          console.log('DEBUG: Requesting user is not linked to task owner - permission denied');
        }
      } else {
        console.log('DEBUG: Task owner document does not exist');
      }
    } else {
      console.log('DEBUG: Task is not shared and requesting user is not owner - permission denied');
    }
    
    if (!hasPermission) {
      return res.status(403).json({ message: 'Unauthorized to toggle completion for this task' });
    }
    
    // Update the MAIN TASK's completion status
    console.log('DEBUG: Updating main task completion status to:', completed, 'for user:', requestUserId);
    const updateData = {
      completed: completed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Only update completedBy if the task is being completed (not uncompleted)
    if (completed) {
      updateData.completedBy = requestUserId;
    } else {
      // When uncompleting, set completedBy to null
      updateData.completedBy = null;
    }
    
    await db.collection('tasks').doc(taskId).update(updateData);
    
    // Also update the user-specific completion status (for consistency with existing design)
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log('DEBUG: Target user document does not exist');
      return res.status(404).json({ message: 'User not found' });
    }

    const userData = userDoc.data();
    let taskCompletionData = userData.taskCompletion || {};
    
    // Initialize task completion data if it doesn't exist
    if (!taskCompletionData[taskId]) {
      console.log('DEBUG: Initializing task completion data for task:', taskId);
      taskCompletionData[taskId] = {};
    }
    
    // Record the completion status for today
    const today = new Date();
    const dateKey = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    console.log('DEBUG: Updating user-specific completion for date:', dateKey, 'Status:', completed);
    taskCompletionData[taskId][dateKey] = completed;
    
    // Update user document
    console.log('DEBUG: Updating user document with new task completion data');
    await db.collection('users').doc(userId).update({
      taskCompletion: taskCompletionData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Get the display name of the user who completed the task
    let completedByDisplayName = 'Unknown';
    if (requestUserId) {
      const userRef = await db.collection('users').doc(requestUserId).get();
      if (userRef.exists) {
        const userData = userRef.data();
        completedByDisplayName = userData.displayName || requestUserId;
      }
    }
    
    // Verify the main task update
    const updatedTaskDoc = await db.collection('tasks').doc(taskId).get();
    const updatedTaskData = updatedTaskDoc.data();
    console.log('DEBUG: Verification - Updated main task data:', { 
      completed: updatedTaskData.completed, 
      completedBy: updatedTaskData.completedBy 
    });
    
    console.log('DEBUG: Task completion status updated successfully in main task document');
    res.status(200).json({ 
      message: 'Task completion status updated successfully',
      completed: updatedTaskData.completed,
      completedBy: updatedTaskData.completedBy,
      completedByName: completedByDisplayName,
      taskId: taskId,
      userId: userId
    });
    
  } catch (error) {
    console.error('Error toggling task completion:', error);
    res.status(500).json({ message: 'Error toggling task completion', error: error.message });
  }
});

// Start the server (only add this once, at the very end)
if (require.main === module) {
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

  // Create HTTP server and WebSocket server
  const server = app.listen(PORT, async () => {
    console.log(`Server is running on port ${PORT}`);
    await checkAndRunMigration();
  });

  // Initialize WebSocket server
  const wss = new WebSocketServer({ server });

  // Store connected clients
  const clients = new Map(); // Map: userId -> Set of WebSocket connections

  wss.on('connection', (ws, req) => {
    console.log('New WebSocket connection established');
    
    // Authenticate connection with token from query parameter
    const urlParams = new URLSearchParams(req.url.split('?')[1]);
    const token = urlParams.get('token');
    
    if (!token) {
      console.log('WebSocket connection rejected: No token provided');
      ws.close(4001, 'Authentication token required');
      return;
    }
    
    // Verify token
    admin.auth().verifyIdToken(token)
      .then(decodedToken => {
        const userId = decodedToken.uid;
        console.log(`WebSocket authenticated for user: ${userId}`);
        
        // Add this connection to the user's connections
        if (!clients.has(userId)) {
          clients.set(userId, new Set());
        }
        clients.get(userId).add(ws);
        
        // Store user ID on the WebSocket connection for easy access
        ws.userId = userId;
        
        ws.on('message', (message) => {
          try {
            const data = JSON.parse(message);
            console.log(`Received message from user ${userId}:`, data.type);
            
            // Handle different message types
            switch (data.type) {
              case 'subscribe_shared_task':
                // Client wants to subscribe to updates for a shared task
                ws.subscribedTasks = ws.subscribedTasks || new Set();
                ws.subscribedTasks.add(data.taskId);
                console.log(`User ${userId} subscribed to shared task: ${data.taskId}`);
                break;
              case 'unsubscribe_shared_task':
                // Client wants to unsubscribe from a shared task
                if (ws.subscribedTasks) {
                  ws.subscribedTasks.delete(data.taskId);
                  console.log(`User ${userId} unsubscribed from shared task: ${data.taskId}`);
                }
                break;
              default:
                console.log(`Unknown message type: ${data.type}`);
            }
          } catch (error) {
            console.error('Error parsing WebSocket message:', error);
          }
        });
        
        ws.on('close', () => {
          console.log(`WebSocket connection closed for user: ${userId}`);
          
          // Remove this connection from the user's connections
          if (clients.has(userId)) {
            clients.get(userId).delete(ws);
            if (clients.get(userId).size === 0) {
              clients.delete(userId);
            }
          }
        });
        
        ws.on('error', (error) => {
          console.error('WebSocket error:', error);
        });
        
        // Send welcome message
        ws.send(JSON.stringify({ type: 'welcome', message: 'Connected to HabitHearts WebSocket server' }));
      })
      .catch(error => {
        console.log('WebSocket authentication failed:', error);
        ws.close(4002, 'Invalid authentication token');
      });
  });

  // Function to broadcast task updates to all subscribed clients
  broadcastTaskUpdate = function(taskId, updateData) {
    console.log(`Broadcasting task update for task ${taskId} to subscribed clients`);
    
    // Get the shared task document to find all users who should receive the update
    db.collection('shared_tasks').doc(taskId).get()
      .then(taskDoc => {
        if (!taskDoc.exists) {
          console.log(`Shared task ${taskId} not found`);
          return;
        }
        
        const taskData = taskDoc.data();
        const usersToNotify = [taskData.ownerId, ...(taskData.linkedUserIds || [])];
        
        console.log(`Notifying users: ${usersToNotify.join(', ')}`);
        
        // For each user who should receive the update
        for (const userId of usersToNotify) {
          if (clients.has(userId)) {
            const userConnections = clients.get(userId);
            
            // For each of the user's connections
            for (const connection of userConnections) {
              // Check if this connection is subscribed to this task
              if (connection.subscribedTasks && connection.subscribedTasks.has(taskId)) {
                try {
                  connection.send(JSON.stringify({
                    type: 'task_update',
                    taskId: taskId,
                    ...updateData
                  }));
                  console.log(`Sent task update to user ${userId} connection`);
                } catch (error) {
                  console.error(`Error sending message to user ${userId}:`, error);
                }
              } else {
                console.log(`User ${userId} connection not subscribed to task ${taskId}`);
              }
            }
          }
        }
      })
      .catch(error => {
        console.error('Error broadcasting task update:', error);
      });
  };

}