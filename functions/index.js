'use strict';

const {
  beforeUserCreated,
  beforeUserSignedIn,
} = require('firebase-functions/v2/identity');

// Supabase Third-party Auth ánh xạ JWT sang Postgres role từ claim này.
exports.beforeUserCreated = beforeUserCreated(() => ({
  customClaims: {role: 'authenticated'},
}));

exports.beforeUserSignedIn = beforeUserSignedIn(() => ({
  customClaims: {role: 'authenticated'},
}));
