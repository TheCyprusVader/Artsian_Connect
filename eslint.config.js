// eslint.config.js
module.exports = [
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
    },
    rules: {
      semi: ['error', 'always'],
      quotes: ['error', 'double'],
      indent: ['error', 2],
      "object-curly-spacing": ["error", "never"],
      "arrow-parens": ["error", "always"],
      "max-len": ["error", {"code":120}],
      "comma-dangle": ["error", "always-multiline"],
      "no-var": "error",
      "space-in-parens": ["error", "never"],
      "space-before-function-paren": ["error", "never"],
      "key-spacing": ["error", {"beforeColon":true,"afterColon":true}],
    },
  },
];