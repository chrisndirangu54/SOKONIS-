import globals from "globals";
import pluginJs from "@eslint/js";

/** @type {import('eslint').Linter.Config[]} */
export default [
  { files: ["**/*.js"], languageOptions: { sourceType: "commonjs" } }, // Changed to commonjs for Node.js
  { languageOptions: { globals: globals.node } }, // Changed to node for Firebase Functions
  pluginJs.configs.recommended,
];