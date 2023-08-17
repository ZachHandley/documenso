module.exports = {
  extends: [
    'next',
    'turbo',
    'prettier',
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],

  plugins: ['prettier'],

  env: {
    node: true,
    browser: true,
    es6: true,
  },

  parser: '@typescript-eslint/parser',

  parserOptions: {
    ecmaVersion: 2022,
    ecmaFeatures: {
      jsx: true,
    },
    sourceType: 'module',
  },

  rules: {
    'react/no-unescaped-entities': 'off',

    'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],

    // We never want to use `as` but are required to on occasion to handle
    // shortcomings in third-party and generated types.
    //
    // To handle this we want this rule to catch usages and highlight them as
    // warnings so we can write appropriate interfaces and guards later.
    '@typescript-eslint/consistent-type-assertions': ['warn', { assertionStyle: 'never' }],
  },
};
