const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
    index: true
  },
  phone: {
    type: String,
    required: false,
    default: '',
    trim: true
  },
  address: {
    type: String,
    required: false,
    default: '',
    trim: true
  },
  area: {
    type: String,
    required: false,
    default: 'General',
    trim: true,
    index: true
  },
  cansOut: {
    type: Number,
    required: true,
    default: 0
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Customer', customerSchema);
