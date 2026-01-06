/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
  verbose: true,
  testMatch: ['**/*.test.js'],
  // Evitar problemas con handles abiertos del emulador
  forceExit: true,
  detectOpenHandles: true
};
