const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const Customer = require('../models/Customer');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const auth = require('../middleware/auth');

// Helper function to send Firebase background notifications
async function sendFCMNotification(senderName, type, qty, customerName, senderId) {
  try {
    // Find all other users with valid FCM tokens
    const otherUsers = await User.find({
      _id: { $ne: senderId },
      fcmToken: { $ne: null }
    });

    const tokens = otherUsers.map(u => u.fcmToken).filter(Boolean);
    if (tokens.length === 0) {
      console.log('No other users registered with FCM tokens to notify.');
      return;
    }

    const actionText = type === 'gave' ? 'gave' : 'received';
    const preposition = type === 'gave' ? 'to' : 'from';
    const messagePayload = {
      notification: {
        title: '🪣 Water Can Update',
        body: `${senderName} ${actionText} ${qty} ${qty === 1 ? 'can' : 'cans'} ${preposition} ${customerName}.`,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type: 'transaction_update',
        timestamp: new Date().toISOString()
      }
    };

    // Firebase Admin sendMulticast
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: messagePayload.notification,
      data: messagePayload.data,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'water_plant_notifications'
        }
      }
    });

    console.log(`FCM notifications sent. Success: ${response.successCount}, Failure: ${response.failureCount}`);

    // If there are failures, log them and clean up expired/invalid tokens from DB
    if (response.failureCount > 0) {
      for (let i = 0; i < response.responses.length; i++) {
        const resObj = response.responses[i];
        if (!resObj.success) {
          const badToken = tokens[i];
          const errCode = resObj.error ? resObj.error.code : 'unknown';
          const errMsg = resObj.error ? resObj.error.message : 'No error message';
          console.warn(`[FCM Error] Target Token: ${badToken.substring(0, 15)}... Code: ${errCode}, Msg: ${errMsg}`);

          // Remove the token from our database if it is no longer valid or registered
          if (
            errCode === 'messaging/registration-token-not-registered' ||
            errCode === 'messaging/invalid-registration-token' ||
            errMsg.includes('not-registered') ||
            errMsg.includes('invalid')
          ) {
            console.log(`[FCM Cleanup] Purging dead/unregistered token from database.`);
            await User.updateOne({ fcmToken: badToken }, { $set: { fcmToken: null } });
          }
        }
      }
    }
  } catch (err) {
    console.error('Failed to send FCM notification:', err.message);
  }
}

// @route   POST api/transactions
// @desc    Record a new give/return transaction
// @access  Private
router.post('/', auth, async (req, res) => {
  const { customerId, type, qty } = req.body;

  if (!customerId || !type || !qty) {
    return res.status(400).json({ message: 'Please provide customerId, type (gave/returned), and qty' });
  }

  if (!['gave', 'returned'].includes(type)) {
    return res.status(400).json({ message: 'Transaction type must be either "gave" or "returned"' });
  }

  if (qty <= 0) {
    return res.status(400).json({ message: 'Quantity must be at least 1' });
  }

  try {
    // Find customer
    const customer = await Customer.findById(customerId);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    // Update customer outstanding counts
    if (type === 'gave') {
      customer.cansOut += Number(qty);
    } else if (type === 'returned') {
      customer.cansOut = Math.max(0, customer.cansOut - Number(qty));
    }

    await customer.save();

    // Create transaction
    const newTransaction = new Transaction({
      customerId,
      type,
      qty: Number(qty),
      by: req.user.id,
      returned: type === 'returned'
    });

    const savedTransaction = await newTransaction.save();

    // Populate transaction for rich socket broadcast
    const transaction = await Transaction.findById(savedTransaction._id)
      .populate('customerId', 'name phone address area cansOut')
      .populate('by', 'name phone');

    // Real-time synchronization broadcast via Socket.IO
    const io = req.app.get('io');
    if (io) {
      // Broadcast to room
      io.emit('transaction_created', transaction);
      io.emit('customer_updated', customer);
    }

    // Trigger FCM Background Notification asynchronously
    sendFCMNotification(req.user.name, type, qty, customer.name, req.user.id);

    res.status(201).json(transaction);
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/transactions
// @desc    Get all transactions (Global Activity Log)
// @access  Private
router.get('/', auth, async (req, res) => {
  try {
    const transactions = await Transaction.find()
      .populate('customerId', 'name phone address area cansOut')
      .populate('by', 'name phone')
      .sort({ timestamp: -1 });

    res.json(transactions);
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE api/transactions/:id
// @desc    Revert and delete a transaction, correcting outstanding cans
// @access  Private
router.delete('/:id', auth, async (req, res) => {
  try {
    const transaction = await Transaction.findById(req.params.id);
    if (!transaction) {
      return res.status(404).json({ message: 'Transaction not found' });
    }

    const customer = await Customer.findById(transaction.customerId);
    if (customer) {
      // Revert outstanding cans count
      if (transaction.type === 'gave') {
        customer.cansOut = Math.max(0, customer.cansOut - transaction.qty);
      } else if (transaction.type === 'returned') {
        customer.cansOut += transaction.qty;
      }
      await customer.save();
    }

    // Delete transaction
    await transaction.deleteOne();

    // Broadcast deletion & customer update via Socket.IO
    const io = req.app.get('io');
    if (io) {
      io.emit('transaction_deleted', req.params.id);
      if (customer) {
        io.emit('customer_updated', customer);
      }
    }

    res.json({ message: 'Transaction reverted and deleted successfully!', customer });
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Transaction not found' });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
