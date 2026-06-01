const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dns = require('dns');
require('dotenv').config();

// Override local DNS resolution order & servers to bypass ISP blocks for Atlas SRV records
try {
  dns.setServers(['8.8.8.8', '8.8.4.4', '1.1.1.1']);
} catch (e) {
  console.warn('Custom DNS initialization bypassed:', e.message);
}

const User = require('./models/User');
const Customer = require('./models/Customer');
const Transaction = require('./models/Transaction');

const seedData = async () => {
  const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/water-plant';
  
  try {
    console.log('Connecting to MongoDB database at:', MONGO_URI);
    await mongoose.connect(MONGO_URI);
    console.log('MongoDB Connected successfully.');

    // Clear existing collections
    await User.deleteMany();
    await Customer.deleteMany();
    await Transaction.deleteMany();
    console.log('Existing collections cleared.');

    // Hash PINs
    const pinHashDad = await bcrypt.hash('1234', 10);
    const pinHashSon = await bcrypt.hash('5678', 10);

    // Seed Dad & Son
    const dad = new User({
      name: 'Dad',
      phone: '9876543210',
      pinHash: pinHashDad
    });

    const son = new User({
      name: 'Son',
      phone: '8765432109',
      pinHash: pinHashSon
    });

    await dad.save();
    await son.save();
    console.log('Dad and Son accounts seeded successfully!');
    console.log(' - Dad: Phone 9876543210, PIN 1234');
    console.log(' - Son: Phone 8765432109, PIN 5678');

    // Seed initial Customers
    const customers = [
      {
        name: 'Vikas Sweets',
        phone: '9012345678',
        address: 'Shop No. 12, Main Market Road',
        area: 'Market Square',
        cansOut: 15
      },
      {
        name: 'Metro Apartments (Security)',
        phone: '9123456789',
        address: 'Tower A Entrance lobby',
        area: 'Green Glen Layout',
        cansOut: 8
      },
      {
        name: 'Dr. Sharma Clinic',
        phone: '9234567890',
        address: 'House 44, Clinic Road',
        area: 'Doctor Colony',
        cansOut: 3
      },
      {
        name: 'Riya Bakery',
        phone: '9345678901',
        address: 'Opposite Railway Station, Gali 2',
        area: 'Station Road',
        cansOut: 0
      }
    ];

    const seededCustomers = await Customer.insertMany(customers);
    console.log(`${seededCustomers.length} initial customers seeded.`);

    // Seed a few initial transactions
    const transactions = [
      {
        customerId: seededCustomers[0]._id,
        type: 'gave',
        qty: 20,
        by: dad._id,
        timestamp: new Date(Date.now() - 3600000 * 24 * 2), // 2 days ago
        returned: false
      },
      {
        customerId: seededCustomers[0]._id,
        type: 'returned',
        qty: 5,
        by: son._id,
        timestamp: new Date(Date.now() - 3600000 * 24), // 1 day ago
        returned: true
      },
      {
        customerId: seededCustomers[1]._id,
        type: 'gave',
        qty: 8,
        by: son._id,
        timestamp: new Date(Date.now() - 3600000 * 6), // 6 hours ago
        returned: false
      },
      {
        customerId: seededCustomers[2]._id,
        type: 'gave',
        qty: 3,
        by: dad._id,
        timestamp: new Date(Date.now() - 3600000 * 1), // 1 hour ago
        returned: false
      }
    ];

    await Transaction.insertMany(transactions);
    console.log('Demo transaction log history seeded successfully.');

    console.log('Database Seeding finished fully.');
    process.exit(0);
  } catch (err) {
    console.error('Seeding process encountered error:', err.message);
    process.exit(1);
  }
};

seedData();
