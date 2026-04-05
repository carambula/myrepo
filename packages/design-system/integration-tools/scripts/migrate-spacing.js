#!/usr/bin/env node

/**
 * Spacing Migration Utility
 * 
 * Scans your codebase and suggests replacements for hard-coded spacing values
 * with design system tokens.
 * 
 * Usage:
 *   node migrate-spacing.js <directory>
 * 
 * Example:
 *   node migrate-spacing.js ./src
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Common spacing values and their token equivalents
const SPACING_MAP = {
  // Logo positioning
  '32px': 'spacing.logo.marginTop (desktop)',
  '24px': 'spacing.logo.marginBottom OR spacing.page.marginTop',
  
  // Button spacing
  // (24px horizontal, 12px vertical for buttons specifically)
  
  // List spacing
  '16px': 'spacing.list.itemPaddingY OR spacing.list.itemPaddingX OR spacing.page.marginLeft',
  '12px': 'spacing.list.itemGap OR spacing.button.paddingY',
  '8px': 'spacing.list.betweenItems OR spacing.button.gap',
  
  // Common spacing
  '4px': 'spacing[1]',
  '48px': 'spacing[12]',
  '64px': 'spacing[16]',
  '96px': 'spacing[24]',
};

const PADDING_PATTERNS = [
  /padding:\s*['"]?(\d+)px\s+(\d+)px['"]?/g,
  /padding:\s*['"]?(\d+)px['"]?/g,
  /paddingTop:\s*['"]?(\d+)px['"]?/g,
  /paddingBottom:\s*['"]?(\d+)px['"]?/g,
  /paddingLeft:\s*['"]?(\d+)px['"]?/g,
  /paddingRight:\s*['"]?(\d+)px['"]?/g,
];

const MARGIN_PATTERNS = [
  /margin:\s*['"]?(\d+)px\s+(\d+)px['"]?/g,
  /margin:\s*['"]?(\d+)px['"]?/g,
  /marginTop:\s*['"]?(\d+)px['"]?/g,
  /marginBottom:\s*['"]?(\d+)px['"]?/g,
  /marginLeft:\s*['"]?(\d+)px['"]?/g,
  /marginRight:\s*['"]?(\d+)px['"]?/g,
];

const GAP_PATTERNS = [
  /gap:\s*['"]?(\d+)px['"]?/g,
  /rowGap:\s*['"]?(\d+)px['"]?/g,
  /columnGap:\s*['"]?(\d+)px['"]?/g,
];

class SpacingMigrator {
  constructor(targetDir) {
    this.targetDir = targetDir;
    this.findings = [];
  }

  async run() {
    console.log('🔍 Scanning for hard-coded spacing values...\n');
    console.log('Directory:', this.targetDir, '\n');

    await this.scanDirectory(this.targetDir);

    if (this.findings.length === 0) {
      console.log('✅ No hard-coded spacing values found!\n');
      return;
    }

    this.printFindings();
    this.printRecommendations();
  }

  async scanDirectory(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      // Skip node_modules and other common directories
      if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === 'dist' || entry.name === 'build') {
        continue;
      }

      if (entry.isDirectory()) {
        await this.scanDirectory(fullPath);
      } else if (this.shouldScanFile(entry.name)) {
        await this.scanFile(fullPath);
      }
    }
  }

  shouldScanFile(filename) {
    const extensions = ['.js', '.jsx', '.ts', '.tsx', '.css', '.scss', '.sass', '.less'];
    return extensions.some(ext => filename.endsWith(ext));
  }

  async scanFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');

    lines.forEach((line, index) => {
      // Check for padding
      PADDING_PATTERNS.forEach(pattern => {
        const matches = [...line.matchAll(pattern)];
        matches.forEach(match => {
          this.findings.push({
            file: filePath,
            line: index + 1,
            type: 'padding',
            original: match[0],
            value: match[1],
            context: line.trim()
          });
        });
      });

      // Check for margin
      MARGIN_PATTERNS.forEach(pattern => {
        const matches = [...line.matchAll(pattern)];
        matches.forEach(match => {
          this.findings.push({
            file: filePath,
            line: index + 1,
            type: 'margin',
            original: match[0],
            value: match[1],
            context: line.trim()
          });
        });
      });

      // Check for gap
      GAP_PATTERNS.forEach(pattern => {
        const matches = [...line.matchAll(pattern)];
        matches.forEach(match => {
          this.findings.push({
            file: filePath,
            line: index + 1,
            type: 'gap',
            original: match[0],
            value: match[1],
            context: line.trim()
          });
        });
      });
    });
  }

  printFindings() {
    console.log(`Found ${this.findings.length} hard-coded spacing value(s):\n`);

    // Group by file
    const byFile = {};
    this.findings.forEach(finding => {
      if (!byFile[finding.file]) {
        byFile[finding.file] = [];
      }
      byFile[finding.file].push(finding);
    });

    Object.keys(byFile).forEach(file => {
      const relativePath = path.relative(this.targetDir, file);
      console.log(`📄 ${relativePath}`);
      
      byFile[file].forEach(finding => {
        const suggestion = SPACING_MAP[`${finding.value}px`] || `spacing[${Math.floor(finding.value / 4)}]`;
        console.log(`   Line ${finding.line}: ${finding.type}`);
        console.log(`      Current: ${finding.original}`);
        console.log(`      Suggest: ${suggestion}`);
        console.log(`      Context: ${finding.context.substring(0, 80)}${finding.context.length > 80 ? '...' : ''}`);
        console.log('');
      });
    });
  }

  printRecommendations() {
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('💡 Recommendations');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    console.log('Critical Spacing to Fix:\n');
    
    console.log('1. Logo Positioning (Home Screen)');
    console.log('   Replace: marginTop: "32px"');
    console.log('   With:    marginTop: spacing.logo.marginTop');
    console.log('');
    
    console.log('2. Button Padding');
    console.log('   Replace: padding: "12px 24px"');
    console.log('   With:    padding: `${spacing.button.paddingY} ${spacing.button.paddingX}`');
    console.log('');
    
    console.log('3. List Item Spacing');
    console.log('   Replace: padding: "16px"');
    console.log('   With:    padding: spacing.list.itemPaddingY');
    console.log('');
    
    console.log('4. Page Margins');
    console.log('   Replace: marginTop: "24px"');
    console.log('   With:    marginTop: spacing.page.marginTop');
    console.log('');
    
    console.log('How to Use Design Tokens:\n');
    console.log('// Import spacing tokens');
    console.log('import { spacing } from \'@min-apps/design-system/tokens\';\n');
    console.log('// Use in inline styles');
    console.log('<div style={{ marginTop: spacing.logo.marginTop }}>');
    console.log('');
    console.log('// Use in CSS-in-JS');
    console.log('const styles = {');
    console.log('  container: {');
    console.log('    padding: spacing.list.itemPaddingY');
    console.log('  }');
    console.log('};');
    console.log('');
    
    console.log('═══════════════════════════════════════════════════════════\n');
  }
}

// Run the migration
const targetDir = process.argv[2] || process.cwd();

if (!fs.existsSync(targetDir)) {
  console.error('❌ Directory does not exist:', targetDir);
  process.exit(1);
}

const migrator = new SpacingMigrator(targetDir);
migrator.run().catch(error => {
  console.error('❌ Migration failed:', error);
  process.exit(1);
});
