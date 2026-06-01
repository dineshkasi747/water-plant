const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const dns = require('dns');
require('dotenv').config();

// Override local DNS resolution order & servers to bypass ISP blocks for Atlas SRV records
try {
  dns.setServers(['8.8.8.8', '8.8.4.4', '1.1.1.1']);
} catch (e) {
  console.warn('Custom DNS initialization bypassed:', e.message);
}

const authRoutes = require('./routes/auth');
const customerRoutes = require('./routes/customers');
const transactionRoutes = require('./routes/transactions');
const socketEvents = require('./socket/events');

const app = express();
const server = http.createServer(app);

// CORS config for HTTP & Socket.IO
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK for background push notifications
const firebaseKeyPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './firebase-service-account.json';
const absoluteFirebaseKeyPath = path.resolve(firebaseKeyPath);

if (fs.existsSync(absoluteFirebaseKeyPath)) {
  try {
    const serviceAccount = require(absoluteFirebaseKeyPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase Admin initialized successfully using service account key file.');
  } catch (err) {
    console.warn('⚠️ Failed to parse Firebase Service Account key file. FCM background notifications will be bypassed.');
    console.warn(err.message);
    initializeMockFirebase();
  }
} else {
  console.warn(`⚠️ Firebase credentials not found at ${absoluteFirebaseKeyPath}. FCM push notifications will be bypassed.`);
  initializeMockFirebase();
}

function initializeMockFirebase() {
  // Gracefully mock admin.messaging() to prevent code exceptions
  admin.messaging = () => ({
    sendEachForMulticast: async (payload) => {
      console.log('[Mock FCM] Simulating background notification push to device(s):', payload);
      return { successCount: payload.tokens.length, failureCount: 0 };
    }
  });
}

// Database Connection
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/water-plant';
mongoose.connect(MONGO_URI)
  .then(() => console.log('MongoDB connection established successfully.'))
  .catch((err) => console.error('MongoDB connection error occurred:', err.message));

// Initialize Socket.IO with CORS settings
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Expose io instance to express routing handlers
app.set('io', io);

// Configure Socket.IO live sync events
socketEvents(io);

// Mount Application Routes
app.use('/api/auth', authRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/transactions', transactionRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date() });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'An internal server error occurred!' });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`🚀 Water Plant Tracking API Server running on port ${PORT}`);
});
