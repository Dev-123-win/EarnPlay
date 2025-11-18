import { verifyFirebaseToken } from './auth.js';
import { initFirebase } from './utils/firebase.js';
import { handleError } from './utils/validation.js';
import { handleAdReward } from './endpoints/ad.js';
import { handleWithdrawal, handleReferral } from './endpoints/withdrawal_referral.js';

/**
 * Handle CORS preflight requests
 * @returns {Response} CORS headers response
 */
function handleCorsPreFlight() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}

/**
 * Add CORS headers to response
 * @param {Response} response - Original response
 * @returns {Response} Response with CORS headers
 */
function addCorsHeaders(response) {
  const headers = new Headers(response.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  return new Response(response.body, {
    status: response.status,
    headers
  });
}

/**
 * Main worker fetch handler
 */
export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCorsPreFlight();
    }

    // Only POST allowed
    if (request.method !== 'POST') {
      return addCorsHeaders(
        handleError('Method not allowed. Only POST is supported.', 405)
      );
    }

    try {
      // Validate Firebase config exists
      if (!env.FIREBASE_CONFIG) {
        console.error('FIREBASE_CONFIG not set in wrangler.toml');
        return addCorsHeaders(
          handleError('Server configuration error', 500)
        );
      }

      // Initialize Firebase Admin SDK
      const db = initFirebase(env.FIREBASE_CONFIG);

      // Verify Firebase ID token
      const authHeader = request.headers.get('Authorization');
      let userId;

      try {
        userId = await verifyFirebaseToken(authHeader, env.FIREBASE_CONFIG);
      } catch (authError) {
        return addCorsHeaders(
          handleError(authError.message, authError.status || 401)
        );
      }

      // Log request (for debugging)
      const url = new URL(request.url);
      console.log(`[${request.method}] ${url.pathname} from user ${userId}`);

      // Route to appropriate endpoint
      const path = url.pathname;
      let response;

      switch (path) {
        case '/verify-ad':
          response = await handleAdReward(request, db, userId, ctx);
          break;

        case '/request-withdrawal':
          response = await handleWithdrawal(request, db, userId, ctx);
          break;

        case '/claim-referral':
          response = await handleReferral(request, db, userId, ctx);
          break;

        // Phase 2+ endpoints (not yet implemented)
        case '/verify-game':
        case '/spin-wheel':
        case '/claim-streak':
          response = handleError(`Endpoint ${path} not yet implemented`, 501);
          break;

        default:
          response = handleError(`Endpoint not found: ${path}`, 404);
      }

      return addCorsHeaders(response);
    } catch (error) {
      console.error('[Worker Error]', error);

      return addCorsHeaders(
        handleError(
          'Internal server error',
          500
        )
      );
    }
  }
};
