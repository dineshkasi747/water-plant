module.exports = function(io) {
  io.on('connection', (socket) => {
    console.log(`Socket Client Connected: ${socket.id}`);

    // Join the default sync room automatically
    socket.join('water-plant-room');
    console.log(`Socket ${socket.id} joined 'water-plant-room'`);

    // Explicit room joining (optional backup)
    socket.on('join', (roomName) => {
      socket.join(roomName);
      console.log(`Socket ${socket.id} explicitly joined: ${roomName}`);
    });

    socket.on('disconnect', () => {
      console.log(`Socket Client Disconnected: ${socket.id}`);
    });
  });
};
