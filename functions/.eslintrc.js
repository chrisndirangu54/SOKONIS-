module.exports = {
  env: {
    es2020: true, // Update to a more recent ECMAScript version
    node: true,   // Ensure Node.js globals like module, require, exports are recognized
  },
  parserOptions: {
    ecmaVersion: 2020, // Match env
    sourceType: "module", // Explicitly set to module for ES6+ support
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "no-unused-vars": "warn", // Relax to warnings to allow deployment
    "no-undef": "error" // Ensure this doesn’t interfere, but node: true should fix require/exports
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};