const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const projectRoot = __dirname;
const monorepoRoot = path.resolve(projectRoot, '../../..');

const config = getDefaultConfig(projectRoot);

// Watch the monorepo root for changes (needed for link:..)
config.watchFolders = [monorepoRoot];

// Resolve modules from both the example and monorepo root node_modules
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(monorepoRoot, 'node_modules'),
];

// Block Metro from crawling into native build directories
config.resolver.blockList = [
  /.*\/ios\/Pods\/.*/,
  /.*\/android\/build\/.*/,
  /.*\/android\/.gradle\/.*/,
];

module.exports = config;
