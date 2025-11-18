import admin from 'firebase-admin';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

let db = null;

/**
 * Initialize Firebase Admin SDK (singleton pattern)
 * @param {string} configJson - Service account JSON config
 * @returns {Firestore} Firestore database instance
 */
export function initFirebase(configJson) {
  if (db) return db;

  try {
    const serviceAccount = JSON.parse(configJson);
    const app = initializeApp({
      credential: cert(serviceAccount)
    });
    db = getFirestore(app);
    return db;
  } catch (error) {
    throw new Error(`Firebase initialization failed: ${error.message}`);
  }
}

/**
 * Get Firestore instance (must call initFirebase first)
 * @returns {Firestore} Firestore database instance
 */
export function getDb() {
  if (!db) {
    throw new Error('Firebase not initialized. Call initFirebase first.');
  }
  return db;
}

/**
 * Helper to create FieldValue.increment for coins
 * @param {number} amount - Amount to increment (positive or negative)
 * @returns {FieldValue} Firestore increment operation
 */
export function incrementCoins(amount) {
  return admin.firestore.FieldValue.increment(amount);
}

/**
 * Helper to get server timestamp
 * @returns {FieldValue} Server timestamp
 */
export function serverTimestamp() {
  return admin.firestore.FieldValue.serverTimestamp();
}

/**
 * Execute atomic read-validate-write transaction
 * @param {Firestore} db - Firestore instance
 * @param {DocumentReference} docRef - Document to read/write
 * @param {Function} validator - Function that validates snapshot, throws if invalid
 * @param {Function|Object} updates - Function returning update data or update object
 * @returns {Promise<Object>} Original document data
 */
export async function readValidateWrite(db, docRef, validator, updates) {
  let result;

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(docRef);

    if (!snap.exists) {
      const err = new Error('Document not found');
      err.status = 404;
      throw err;
    }

    // Run validator (throws if invalid)
    validator(snap.data(), snap);

    // Get update data
    const updateData =
      typeof updates === 'function' ? updates(snap.data(), snap) : updates;

    // Perform update
    transaction.update(docRef, updateData);

    result = snap.data();
  });

  return result;
}

/**
 * Execute atomic multi-document transaction
 * @param {Firestore} db - Firestore instance
 * @param {Function} transactionFn - Async function that receives transaction and performs updates
 * @returns {Promise<any>} Result returned by transactionFn
 */
export async function atomicTransaction(db, transactionFn) {
  return await db.runTransaction(transactionFn);
}

/**
 * Add audit log entry (fire-and-forget, returns Promise for ctx.waitUntil)
 * @param {Firestore} db - Firestore instance
 * @param {string} userId - User ID
 * @param {string} actionType - Type of action
 * @param {Object} data - Additional data to log
 * @returns {Promise<DocumentReference>} Promise for audit log write
 */
export function addAuditLog(db, userId, actionType, data = {}) {
  const userRef = db.collection('users').doc(userId);
  return userRef.collection('actions').add({
    type: actionType,
    ...data,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: new Date().toISOString()
  });
}

export { admin };
