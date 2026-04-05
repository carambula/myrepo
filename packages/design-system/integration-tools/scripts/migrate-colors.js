#!/usr/bin/env node

/**
 * Color Migration Utility
 * 
 * Scans your codebase for hard-coded color values and suggests
 * design system CSS variable replacements.
 * 
 * Usage:
 *   node migrate-colors.js <directory>
 * 
 * Example:
 *   node migrate-colors.js ./src
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Common color values and their CSS variable equivalents
const COLOR_MAP = {
  // Light mode colors
  '#FFFFFF': 'var(--color-background-primary) // white background',
  '#000000': 'var(--color-text-primary) // black text',
  '#F9FAFB': 'var(--color-background-primary) // light gray background',
  '#111827': 'var(--color-text-primary) // dark text',
  '#6B7280': 'var(--color-text-secondary) // gray text',
  '#9CA3AF': 'var(--color-text-tertiary) // light gray text',
  
  // Common UI colors
  '#3B82F6': 'var(--color-primary-main) // blue',
  '#2563EB': 'var(--color-primary-dark) // dark blue',
  '#60A5FA': 'var(--color-primary-light) // light blue',
  
  '#10B981': 'var(--color-success-main) // green',
  '#EF4444': 'var(--color-error-main) // red',
  '#F59E0B': 'var(--color-warning-main) // orange',
  '#06B6D4': 'var(--color-info-main) // cyan',
  
  // Borders
  '#E5E7EB': 'var(--color-border-primary) // light border',
  '#D1D5DB': 'var(--color-border-secondary) // medium border',
};

// Regex patterns to find color values
const HEX_PATTERN = /#[0-9A-Fa-f]{3,6}\b/g;
const RGB_PATTERN = /rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(?:,\s*[\d.]+\s*)?\)/g;
const COLOR_PROPERTIES = [
  'color', 'backgroundColor', 'background', 'borderColor',
  'border', 'outline', 'fill', 'stroke'
];

class ColorMigrator {
  constructor(targetDir) {
    this.targetDir = targetDir;
    this.findings = [];
    this.colorFrequency = {};
  }

  async run() {
    console.log('🎨 Scanning for hard-coded color values...\n');
    console.log('Directory:', this.targetDir, '\n');

    await this.scanDirectory(this.targetDir);

    if (this.findings.length === 0) {
      console.log('✅ No hard-coded color values found!\n');
      return;
    }

    this.analyzeColors();
    this.printFindings();
    this.printRecommendations();
  }

  async scanDirectory(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

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
      // Find hex colors
      const hexMatches = [...line.matchAll(HEX_PATTERN)];
      hexMatches.forEach(match => {
        const color = match[0].toUpperCase();
        this.addFinding(filePath, index + 1, 'hex', color, line.trim());
      });

      // Find rgb/rgba colors
      const rgbMatches = [...line.matchAll(RGB_PATTERN)];
      rgbMatches.forEach(match => {
        const color = match[0];
        this.addFinding(filePath, index + 1, 'rgb', color, line.trim());
      });
    });
  }

  addFinding(file, line, type, color, context) {
    // Normalize hex colors (3-digit to 6-digit)
    let normalizedColor = color;
    if (type === 'hex' && color.length === 4) {
      normalizedColor = '#' + color[1] + color[1] + color[2] + color[2] + color[3] + color[3];
      normalizedColor = normalizedColor.toUpperCase();
    }

    this.findings.push({
      file,
      line,
      type,
      color: normalizedColor,
      original: color,
      context
    });

    // Track frequency
    this.colorFrequency[normalizedColor] = (this.colorFrequency[normalizedColor] || 0) + 1;
  }

  analyzeColors() {
    // Sort colors by frequency
    this.mostUsedColors = Object.entries(this.colorFrequency)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10);
  }

  printFindings() {
    console.log(`Found ${this.findings.length} hard-coded color value(s):\n`);

    // Show most used colors
    console.log('Most Frequently Used Colors:\n');
    this.mostUsedColors.forEach(([color, count]) => {
      const suggestion = COLOR_MAP[color] || 'Review and map to design system';
      console.log(`  ${color} - used ${count} time(s)`);
      console.log(`  → ${suggestion}\n`);
    });

    // Group by file
    const byFile = {};
    this.findings.forEach(finding => {
      if (!byFile[finding.file]) {
        byFile[finding.file] = [];
      }
      byFile[finding.file].push(finding);
    });

    console.log('\nBy File:\n');
    Object.keys(byFile).slice(0, 5).forEach(file => {
      const relativePath = path.relative(this.targetDir, file);
      console.log(`📄 ${relativePath} (${byFile[file].length} color(s))`);
      
      byFile[file].slice(0, 3).forEach(finding => {
        console.log(`   Line ${finding.line}: ${finding.color}`);
      });
      
      if (byFile[file].length > 3) {
        console.log(`   ... and ${byFile[file].length - 3} more`);
      }
      console.log('');
    });

    if (Object.keys(byFile).length > 5) {
      console.log(`... and ${Object.keys(byFile).length - 5} more file(s)\n`);
    }
  }

  printRecommendations() {
    console.log('═══════════════════════════════════════════════════════════');
    console.log('💡 Recommendations');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    console.log('Replace hard-coded colors with CSS variables:\n');
    
    console.log('Background Colors:');
    console.log('  Before: backgroundColor: "#FFFFFF"');
    console.log('  After:  backgroundColor: "var(--color-background-primary)"');
    console.log('');
    
    console.log('Text Colors:');
    console.log('  Before: color: "#000000"');
    console.log('  After:  color: "var(--color-text-primary)"');
    console.log('');
    
    console.log('Primary Colors:');
    console.log('  Before: color: "#3B82F6"');
    console.log('  After:  color: "var(--color-primary-main)"');
    console.log('');
    
    console.log('Border Colors:');
    console.log('  Before: borderColor: "#E5E7EB"');
    console.log('  After:  borderColor: "var(--color-border-primary)"');
    console.log('');
    
    console.log('Available CSS Variables:\n');
    console.log('Backgrounds:');
    console.log('  --color-background-primary');
    console.log('  --color-background-secondary');
    console.log('  --color-background-tertiary');
    console.log('');
    console.log('Text:');
    console.log('  --color-text-primary');
    console.log('  --color-text-secondary');
    console.log('  --color-text-tertiary');
    console.log('');
    console.log('Semantic:');
    console.log('  --color-primary-main, --color-primary-light, --color-primary-dark');
    console.log('  --color-success-main, --color-error-main, --color-warning-main');
    console.log('');
    console.log('Borders:');
    console.log('  --color-border-primary');
    console.log('  --color-border-secondary');
    console.log('');
    
    console.log('Usage in CSS:');
    console.log('  .my-class {');
    console.log('    background-color: var(--color-background-primary);');
    console.log('    color: var(--color-text-primary);');
    console.log('  }');
    console.log('');
    
    console.log('Usage in JSX:');
    console.log('  <div style={{ backgroundColor: "var(--color-background-primary)" }}>');
    console.log('');
    
    console.log('Benefits:');
    console.log('  ✓ Automatic theme support (light/dark)');
    console.log('  ✓ Consistent colors across all apps');
    console.log('  ✓ Easy to update globally');
    console.log('  ✓ Better maintainability');
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

const migrator = new ColorMigrator(targetDir);
migrator.run().catch(error => {
  console.error('❌ Migration failed:', error);
  process.exit(1);
});
