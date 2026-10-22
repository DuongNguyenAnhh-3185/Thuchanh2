'use strict';

const {applicationDefault, initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');

initializeApp({credential: applicationDefault()});

async function setExistingUserRoles() {
  let pageToken;
  let updated = 0;
  do {
    const page = await getAuth().listUsers(1000, pageToken);
    for (const user of page.users) {
      await getAuth().setCustomUserClaims(user.uid, {
        ...user.customClaims,
        role: 'authenticated',
      });
      updated += 1;
    }
    pageToken = page.pageToken;
  } while (pageToken);
  console.log(`Updated role claim for ${updated} Firebase users.`);
}

setExistingUserRoles().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
