import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

let authInstance = null;

/**
 * Initialize Firebase Admin Auth (cached after first call)
 * @param {string} configJson - Firebase service account JSON config
 * @returns {Auth} Firebase Auth instance
 */
function initializeAuthSingleton(configJson) {
  if (authInstance) return authInstance;

  try {
    const serviceAccount = JSON.parse(configJson);
    const app = initializeApp({
      credential: cert(serviceAccount)
    });
    authInstance = getAuth(app);
    return authInstance;
  } catch (error) {
    throw new Error(`Firebase initialization failed: ${error.message}`);
  }
}

/**
 * Verify Firebase ID token and extract user ID
 * @param {string} authHeader - Authorization header (Bearer token)
 * @param {string} firebaseConfig - Firebase service account config
 * @returns {Promise<string>} User UID
 */
export async function verifyFirebaseToken(authHeader, firebaseConfig) {
  if (!authHeader?.startsWith('Bearer ')) {
    const error = new Error('Missing or invalid Authorization header');
    error.status = 401;
    throw error;
  }

  const token = authHeader.substring(7).trim();

  if (!token) {
    const error = new Error('Empty Bearer token');
    error.status = 401;
    throw error;
  }

  try {
    const auth = initializeAuthSingleton(firebaseConfig);
    const decodedToken = await auth.verifyIdToken(token);
    
    if (!decodedToken.uid) {
      const error = new Error('Token missing UID');
      error.status = 401;
      throw error;
    }

    return decodedToken.uid;
  } catch (error) {
    const err = new Error(`Token verification failed: ${error.message}`);
    err.status = 401;
    throw err;
  }
}
