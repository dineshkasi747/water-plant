const express = require('express');
const router = express.Router();
const Customer = require('../models/Customer');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');

// @route   GET api/customers
// @desc    Get all customers or search by name/area
// @access  Private
router.get('/', auth, async (req, res) => {
  const { search } = req.query;

  try {
    let query = {};
    if (search) {
      const searchRegex = new RegExp(search, 'i');
      query = {
        $or: [
          { name: searchRegex },
          { area: searchRegex }
        ]
      };
    }

    const customers = await Customer.find(query).sort({ name: 1 });
    res.json(customers);
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/customers
// @desc    Add a new customer
// @access  Private
router.post('/', auth, async (req, res) => {
  const { name, phone, address, area } = req.body;

  if (!name) {
    return res.status(400).json({ message: 'Please enter customer name' });
  }

  try {
    const newCustomer = new Customer({
      name,
      phone: phone || '',
      address: address || '',
      area: area || 'General',
      cansOut: 0
    });

    const customer = await newCustomer.save();
    
    // Broadcast via global io if attached to app
    const io = req.app.get('io');
    if (io) {
      io.emit('customer_updated', customer);
    }

    res.status(201).json(customer);
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/customers/:id
// @desc    Get customer by ID with transaction history
// @access  Private
router.get('/:id', auth, async (req, res) => {
  try {
    const customer = await Customer.findById(req.params.id);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    // Get all transactions for this customer
    const history = await Transaction.find({ customerId: req.params.id })
      .populate('by', 'name phone')
      .sort({ timestamp: -1 });

    res.json({
      customer,
      history
    });
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Customer not found' });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   PUT api/customers/:id
// @desc    Update a customer's details
// @access  Private
router.put('/:id', auth, async (req, res) => {
  const { name, phone, address, area } = req.body;

  try {
    let customer = await Customer.findById(req.params.id);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    if (name) customer.name = name;
    if (phone) customer.phone = phone;
    if (address) customer.address = address;
    if (area) customer.area = area;

    await customer.save();

    // Broadcast update via Socket.IO
    const io = req.app.get('io');
    if (io) {
      io.emit('customer_updated', customer);
    }

    res.json(customer);
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Customer not found' });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE api/customers/:id
// @desc    Delete a customer and their transaction log
// @access  Private
router.delete('/:id', auth, async (req, res) => {
  try {
    const customer = await Customer.findById(req.params.id);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    // Delete all transaction logs associated with this customer
    await Transaction.deleteMany({ customerId: req.params.id });

    // Delete customer
    await customer.deleteOne();

    // Broadcast deletion via Socket.IO
    const io = req.app.get('io');
    if (io) {
      io.emit('customer_deleted', req.params.id);
    }

    res.json({ message: 'Customer and history purged successfully!' });
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Customer not found' });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
