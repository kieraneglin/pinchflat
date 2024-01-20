module.exports = {
  env: {
    browser: true,
    commonjs: true,
    es6: true,
    node: true
  },
  parserOptions: {
    sourceType: 'module',
    ecmaVersion: 2022
  },
  extends: ['prettier'],
  rules: {
    'prettier/prettier': 'error'
  }
}
