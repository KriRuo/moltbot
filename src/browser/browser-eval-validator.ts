/**
 * Security validation for browser evaluation functions
 * 
 * ⚠️ SECURITY NOTE: This module provides defense-in-depth validation
 * for JavaScript functions executed in browser contexts via Playwright.
 * 
 * While browser evaluation is isolated from the Node.js server, it can
 * still access sensitive data in the target page's DOM, cookies, and storage.
 * 
 * This validator implements pattern-based detection of potentially dangerous
 * operations to prevent data exfiltration and malicious page manipulation.
 */

/**
 * Dangerous patterns that could enable data exfiltration or malicious actions
 * in the browser context. These are blocked by default.
 */
const DANGEROUS_PATTERNS = [
  // Network operations - could exfiltrate data
  { pattern: /\bfetch\s*\(/i, description: "fetch() - network request" },
  { pattern: /\bXMLHttpRequest\b/i, description: "XMLHttpRequest - network request" },
  { pattern: /\bWebSocket\b/i, description: "WebSocket - network connection" },
  { pattern: /\bnavigator\.sendBeacon\b/i, description: "navigator.sendBeacon - network request" },
  
  // Dynamic imports - could load malicious code
  { pattern: /\bimport\s*\(/i, description: "import() - dynamic import" },
  { pattern: /\brequire\s*\(/i, description: "require() - module loading" },
  
  // Storage access - could access sensitive data
  { pattern: /\blocalStorage\b/i, description: "localStorage - storage access" },
  { pattern: /\bsessionStorage\b/i, description: "sessionStorage - storage access" },
  { pattern: /\bIndexedDB\b/i, description: "IndexedDB - storage access" },
  { pattern: /\bdocument\.cookie\b/i, description: "document.cookie - cookie access" },
  
  // Dangerous DOM operations
  { pattern: /\bdocument\.write\b/i, description: "document.write - DOM manipulation" },
  { pattern: /\beval\s*\(/i, description: "eval() - code execution" },
  { pattern: /\bFunction\s*\(/i, description: "Function() constructor - code execution" },
  
  // Credential/auth access
  { pattern: /\bcredentials\b/i, description: "credentials - credential access" },
  { pattern: /\bpassword\b/i, description: "password - credential access" },
  
  // Location manipulation - could redirect user
  { pattern: /\blocation\.href\s*=/i, description: "location.href = - navigation" },
  { pattern: /\blocation\.replace\b/i, description: "location.replace() - navigation" },
  { pattern: /\blocation\.assign\b/i, description: "location.assign() - navigation" },
  
  // Service Workers - could persist malicious code
  { pattern: /\bServiceWorker\b/i, description: "ServiceWorker - background script" },
  { pattern: /\bnavigator\.serviceWorker\b/i, description: "navigator.serviceWorker - background script" },
];

/**
 * ValidationResult indicates whether the function body is safe to execute
 */
export type ValidationResult = {
  safe: boolean;
  reason?: string;
  blockedPattern?: string;
};

/**
 * ValidationOptions allow customization of validation behavior
 */
export type ValidationOptions = {
  /**
   * If true, allows dangerous patterns (use only with trusted input)
   * Default: false
   */
  allowDangerous?: boolean;
  
  /**
   * Custom patterns to block (in addition to default dangerous patterns)
   */
  customBlockedPatterns?: Array<{ pattern: RegExp; description: string }>;
  
  /**
   * If true, skips syntax validation (faster but less safe)
   * Default: false
   */
  skipSyntaxCheck?: boolean;
};

/**
 * Validates a JavaScript function body for security risks before browser evaluation
 * 
 * @param fnBody - The JavaScript function body to validate
 * @param options - Validation options
 * @returns ValidationResult indicating if the function is safe
 * 
 * @example
 * ```typescript
 * const result = validateBrowserEvalFunction("() => document.title");
 * if (!result.safe) {
 *   throw new Error(`Unsafe function: ${result.reason}`);
 * }
 * ```
 */
export function validateBrowserEvalFunction(
  fnBody: string,
  options: ValidationOptions = {},
): ValidationResult {
  // Empty or whitespace-only functions are safe (no-op)
  if (!fnBody || !fnBody.trim()) {
    return { safe: true };
  }

  // If allowDangerous is explicitly set, skip pattern checks
  if (options.allowDangerous === true) {
    return { safe: true };
  }

  // Check against dangerous patterns
  const patternsToCheck = [
    ...DANGEROUS_PATTERNS,
    ...(options.customBlockedPatterns ?? []),
  ];

  for (const { pattern, description } of patternsToCheck) {
    if (pattern.test(fnBody)) {
      return {
        safe: false,
        reason: `Dangerous pattern detected: ${description}`,
        blockedPattern: pattern.source,
      };
    }
  }

  // Syntax validation (ensure it's valid JavaScript)
  if (!options.skipSyntaxCheck) {
    try {
      // Test if the function body is valid JavaScript
      // This doesn't execute the code, just parses it
      new Function(fnBody);
    } catch (err) {
      return {
        safe: false,
        reason: `Invalid function syntax: ${err instanceof Error ? err.message : String(err)}`,
      };
    }
  }

  return { safe: true };
}

/**
 * Creates a validated error message for unsafe functions
 * 
 * @param result - The validation result
 * @returns User-friendly error message
 */
export function createValidationError(result: ValidationResult): Error {
  const message = result.reason
    ? `Browser evaluation blocked: ${result.reason}`
    : "Browser evaluation blocked: security validation failed";
  
  const error = new Error(message);
  error.name = "BrowserEvalSecurityError";
  return error;
}

/**
 * Convenience function to validate and throw on unsafe input
 * 
 * @param fnBody - The JavaScript function body to validate
 * @param options - Validation options
 * @throws Error if the function body is unsafe
 * 
 * @example
 * ```typescript
 * validateOrThrow("() => fetch('https://evil.com')");
 * // Throws: BrowserEvalSecurityError
 * ```
 */
export function validateOrThrow(
  fnBody: string,
  options: ValidationOptions = {},
): void {
  const result = validateBrowserEvalFunction(fnBody, options);
  if (!result.safe) {
    throw createValidationError(result);
  }
}
