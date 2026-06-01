const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const auth = require('../middleware/auth');

// @route   POST api/auth/login
// @desc    Authenticate user (PIN Login) & get token
// @access  Public
router.post('/login', async (req, res) => {
  const { phone, pin } = req.body;

  if (!phone || !pin) {
    return res.status(400).json({ message: 'Please provide phone number and 4-digit PIN' });
  }

  try {
    // Find user
    const user = await User.findOne({ phone });
    if (!user) {
      return res.status(400).json({ message: 'Invalid phone or PIN' });
    }

    // Check PIN
    const isMatch = await bcrypt.compare(pin, user.pinHash);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid phone or PIN' });
    }

    // Increment tokenVersion to invalidate all other active sessions (single-device login enforcement)
    user.tokenVersion = (user.tokenVersion || 0) + 1;
    await user.save();

    // Create JWT payload
    const payload = {
      id: user.id,
      name: user.name,
      phone: user.phone,
      tokenVersion: user.tokenVersion
    };

    // Sign Token
    jwt.sign(
      payload,
      process.env.JWT_SECRET || 'secretkey',
      { expiresIn: '30d' }, // Generous token lifespan for daily operational use
      (err, token) => {
        if (err) throw err;
        res.json({
          token,
          user: {
            id: user.id,
            name: user.name,
            phone: user.phone,
            fcmToken: user.fcmToken
          }
        });
      }
    );
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/auth/fcm-token
// @desc    Update FCM Token for push notifications
// @access  Private
router.post('/fcm-token', auth, async (req, res) => {
  const { fcmToken } = req.body;

  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.fcmToken = fcmToken || null;
    await user.save();

    res.json({ message: 'FCM token updated successfully', fcmToken: user.fcmToken });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
