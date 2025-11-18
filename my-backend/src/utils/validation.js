import { ERROR_MESSAGES } from './constants.js';

/**
 * Generic error response builder
 * @param {string} message - Error message
 * @param {number} status - HTTP status code (default 500)
 * @returns {Response} HTTP response
 */
export function handleError(message, status = 500) {
  console.error(`[Error ${status}] ${message}`);

  return new Response(
    JSON.stringify({
      error: message,
      status,
      timestamp: new Date().toISOString()
    }),
    {
      status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    }
  );
}

/**
 * Validate and parse JSON request body
 * @param {Request} request - HTTP request
 * @param {Object} schema - Validation schema {fieldName: 'type'}
 * @returns {Promise<Object>} Parsed and validated body
 * @throws {Error} If validation fails
 */
export async function validateRequest(request, schema) {
  let body;

  try {
    body = await request.json();
  } catch (error) {
    const err = new Error('Invalid JSON in request body');
    err.status = 400;
    throw err;
  }

  // Validate each field against schema
  for (const [field, expectedType] of Object.entries(schema)) {
    if (!(field in body)) {
      const err = new Error(`Missing required field: ${field}`);
      err.status = 400;
      throw err;
    }

    const actualType = typeof body[field];
    if (actualType !== expectedType) {
      const err = new Error(
        `Field '${field}' must be ${expectedType}, got ${actualType}`
      );
      err.status = 400;
      throw err;
    }
  }

  return body;
}

/**
 * Validate request timestamp (prevent replay attacks)
 * @param {number} requestTimestamp - Timestamp from request (milliseconds)
 * @param {number} maxAgeMsec - Max age allowed (default 60 seconds)
 * @throws {Error} If timestamp is too old or invalid
 */
export function validateTimestamp(requestTimestamp, maxAgeMsec = 60000) {
  if (typeof requestTimestamp !== 'number') {
    const err = new Error('Timestamp must be a number (milliseconds)');
    err.status = 400;
    throw err;
  }

  const now = Date.now();
  const age = Math.abs(now - requestTimestamp);

  if (age > maxAgeMsec) {
    const err = new Error(ERROR_MESSAGES.STALE_REQUEST);
    err.status = 400;
    throw err;
  }
}

/**
 * Check if date has changed (for daily reset detection)
 * @param {Date|null} lastDate - Last known date
 * @returns {boolean} True if day has changed
 */
export function hasDateChanged(lastDate) {
  if (!lastDate) return true;

  const now = new Date();
  const last = lastDate instanceof Date ? lastDate : new Date(lastDate);

  return (
    now.getDate() !== last.getDate() ||
    now.getMonth() !== last.getMonth() ||
    now.getFullYear() !== last.getFullYear()
  );
}

/**
 * Safe JSON response builder
 * @param {Object} data - Data to send
 * @param {number} status - HTTP status (default 200)
 * @returns {Response} HTTP response
 */
export function successResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}
