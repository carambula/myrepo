#!/usr/bin/env node

/**
 * Integration Verification Script
 * 
 * Verifies that the design system has been properly integrated into your app.
 * Checks for proper setup, spacing usage, color variables, and component usage.
 * 
 * Usage:
 *   node verify-integration.js
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class IntegrationVerifier {
  constructor(targetDir = process.cwd()) {
    this.targetDir = targetDir;
    this.results = {
      passed: [],
      failed: [],
      warnings: []
    };
  }

  async run() {
    console.log('🔍 Verifying Design System Integration\n');
    console.log('Directory:', this.targetDir, '\n');
    console.log('═══════════════════════════════════════════════════════════\n');

    // Run all checks
    this.checkPackageJson();
    this.checkGlobalStyles();
    this.checkThemeInit();
    this.checkCSSVariableUsage();
    this.checkSpacingTokenUsage();
    this.checkComponentImports();
    this.checkMainAppLoading();
    this.checkHardCodedValues();

    // Print results
    this.printResults();
  }

  checkPackageJson() {
    const packagePath = path.join(this.targetDir, 'package.json');
    
    if (!fs.existsSync(packagePath)) {
      this.results.failed.push('No package.json found');
      return;
    }

    const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
    const hasDesignSystem = 
      pkg.dependencies?.['@min-apps/design-system'] ||
      pkg.devDependencies?.['@min-apps/design-system'];

    if (hasDesignSystem) {
      this.results.passed.push('✓ Design system package installed');
    } else {
      this.results.failed.push('✗ Design system package not found in dependencies');
    }
  }

  checkGlobalStyles() {
    const srcDir = path.join(this.targetDir, 'src');
    
    if (!fs.existsSync(srcDir)) {
      this.results.warnings.push('⚠ src directory not found, skipping file checks');
      return;
    }

    // Check if global styles are imported
    let found = false;
    this.scanFilesForPattern(
      srcDir,
      /@min-apps\/design-system.*styles\.css/,
      (file) => {
        found = true;
        this.results.passed.push(`✓ Global styles imported in ${path.relative(this.targetDir, file)}`);
      }
    );

    if (!found) {
      this.results.failed.push('✗ Global styles not imported (import "@min-apps/design-system/src/styles/global.css")');
    }
  }

  checkThemeInit() {
    const srcDir = path.join(this.targetDir, 'src');
    
    if (!fs.existsSync(srcDir)) {
      return;
    }

    // Check if theme is initialized
    let found = false;
    this.scanFilesForPattern(
      srcDir,
      /initTheme\(\)/,
      (file) => {
        found = true;
        this.results.passed.push(`✓ Theme initialized in ${path.relative(this.targetDir, file)}`);
      }
    );

    if (!found) {
      this.results.failed.push('✗ Theme not initialized (call initTheme() from "@min-apps/design-system")');
    }
  }

  checkCSSVariableUsage() {
    const srcDir = path.join(this.targetDir, 'src');
    
    if (!fs.existsSync(srcDir)) {
      return;
    }

    let count = 0;
    this.scanFilesForPattern(
      srcDir,
      /var\(--color-/,
      () => { count++; }
    );

    if (count > 0) {
      this.results.passed.push(`✓ Using CSS variables for colors (${count} usage(s) found)`);
    } else {
      this.results.warnings.push('⚠ No CSS variable usage found (should use var(--color-*))');
    }
  }

  checkSpacingTokenUsage() {
    const srcDir = path.join(this.targetDir, 'src');
    
    if (!fs.existsSync(srcDir)) {
      return;
    }

    let count = 0;
    this.scanFilesForPattern(
      srcDir,
      /spacing\.(logo|page|button|list)/,
      () => { count++; }
    );

    if (count > 0) {
      this.results.passed.push(`✓ Using spacing tokens (${count} usage(s) found)`);
    } else {
      this.results.warnings.push('⚠ No spacing token usage found (should use spacing.logo.*, spacing.page.*, etc.)');
    }
  }

  checkComponentImports() {
    const srcDir = path.join(this.targetDir, 'src');
    
    if (!fs.existsSync(srcDir)) {
      return;
    }

    const components = ['Button', 'ListItem', 'AppLayout', 'HomeLayout', 'Card', 'Input'];
    const foundComponents = new Set();

    components.forEach(component => {
      const pattern = new RegExp(`import.*${component}.*@min-apps/design-system`);
      this.scanFilesForPattern(
        srcDir,
        pattern,
        () => { foundComponents.add(component); }
      );
    });

    if (foundComponents.size > 0) {
      this.results.passed.push(`✓ Using design system components: ${Array.from(foundComponents).join(', ')}`);
    } else {
      this.results.warnings.push('⚠ No design system component imports found');
    }
  }

  checkMainAppLoading() {
    const srcDir = path.join(this.targetDir, 'src');
    if (!fs.existsSync(srcDir)) return;

    let usesMainAppLoading = false;
    this.scanFilesForPattern(
      srcDir,
      /MainAppLoading/,
      () => { usesMainAppLoading = true; }
    );

    if (usesMainAppLoading) {
      this.results.passed.push('✓ Uses MainAppLoading component for bootstrap loading (mov min reference)');
    } else {
      this.results.failed.push(
        '✗ MainAppLoading not found — every min app must use the same left-aligned bootstrap loader as WatchedIt (mov min). ' +
        'Web: import { MainAppLoading } from "@min-apps/design-system/components". ' +
        'React Native: import { MainAppLoading } from "@min-apps/design-system/react-native".'
      );
    }

    let hasCenteredLoading = false;
    const centeredPatterns = [
      /justifyContent:\s*['"]center['"].*[Ll]oading/,
      /[Ll]oading.*justifyContent:\s*['"]center['"]/,
      /alignItems:\s*['"]center['"].*[Ll]oading/,
      /text-align:\s*center.*[Ll]oading/,
      /[Ll]oading.*text-align:\s*center/,
    ];
    for (const pat of centeredPatterns) {
      this.scanFilesForPattern(srcDir, pat, () => { hasCenteredLoading = true; });
    }

    if (hasCenteredLoading) {
      this.results.failed.push(
        '✗ Centered loading detected — bootstrap loading must be left-aligned (mov min reference). Remove any justifyContent/alignItems/text-align center wrappers around loading states.'
      );
    }

    let hasFlexGrowLoading = false;
    const flexGrowPatterns = [
      /flex:\s*1.*[Ll]oading/,
      /[Ll]oading.*flex:\s*1/,
      /flexGrow.*[Ll]oading/,
      /[Ll]oading.*flexGrow/,
    ];
    for (const pat of flexGrowPatterns) {
      this.scanFilesForPattern(srcDir, pat, () => { hasFlexGrowLoading = true; });
    }

    if (hasFlexGrowLoading) {
      this.results.warnings.push(
        '⚠ flex:1 or flexGrow near loading state — the loader must not expand to fill vertical space. Use MainAppLoading which pins content to top-left.'
      );
    }
  }

  checkHardCodedValues() {
    const srcDir = path.join(this.targetDir, 'src');
    
    if (!fs.existsSync(srcDir)) {
      return;
    }

    // Check for hard-coded spacing (32px, 24px, 16px, etc.)
    const criticalSpacing = ['32px', '24px', '16px', '12px'];
    const foundIssues = [];

    criticalSpacing.forEach(spacing => {
      let count = 0;
      this.scanFilesForPattern(
        srcDir,
        new RegExp(`["']${spacing}["']`),
        () => { count++; }
      );
      if (count > 0) {
        foundIssues.push(`${spacing} used ${count} time(s)`);
      }
    });

    if (foundIssues.length > 0) {
      this.results.warnings.push(`⚠ Hard-coded spacing values found: ${foundIssues.join(', ')}`);
      this.results.warnings.push('  Consider replacing with spacing tokens');
    }

    // Check for hard-coded colors
    let colorCount = 0;
    this.scanFilesForPattern(
      srcDir,
      /#[0-9A-Fa-f]{3,6}\b/,
      () => { colorCount++; }
    );

    if (colorCount > 0) {
      this.results.warnings.push(`⚠ Hard-coded hex colors found: ${colorCount} instance(s)`);
      this.results.warnings.push('  Consider replacing with CSS variables');
    }
  }

  scanFilesForPattern(dir, pattern, onMatch) {
    if (!fs.existsSync(dir)) return;

    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === 'dist' || entry.name === 'build') {
        continue;
      }

      if (entry.isDirectory()) {
        this.scanFilesForPattern(fullPath, pattern, onMatch);
      } else if (this.shouldScanFile(entry.name)) {
        const content = fs.readFileSync(fullPath, 'utf8');
        if (pattern.test(content)) {
          onMatch(fullPath);
        }
      }
    }
  }

  shouldScanFile(filename) {
    const extensions = ['.js', '.jsx', '.ts', '.tsx', '.css', '.scss'];
    return extensions.some(ext => filename.endsWith(ext));
  }

  printResults() {
    console.log('Results:\n');

    // Print passed checks
    if (this.results.passed.length > 0) {
      console.log('✅ Passed Checks:\n');
      this.results.passed.forEach(msg => console.log(`   ${msg}`));
      console.log('');
    }

    // Print failed checks
    if (this.results.failed.length > 0) {
      console.log('❌ Failed Checks:\n');
      this.results.failed.forEach(msg => console.log(`   ${msg}`));
      console.log('');
    }

    // Print warnings
    if (this.results.warnings.length > 0) {
      console.log('⚠️  Warnings:\n');
      this.results.warnings.forEach(msg => console.log(`   ${msg}`));
      console.log('');
    }

    // Overall status
    console.log('═══════════════════════════════════════════════════════════\n');
    
    const passedCount = this.results.passed.length;
    const failedCount = this.results.failed.length;
    const warningCount = this.results.warnings.length;

    console.log('Summary:');
    console.log(`  ✅ ${passedCount} passed`);
    console.log(`  ❌ ${failedCount} failed`);
    console.log(`  ⚠️  ${warningCount} warning(s)\n`);

    if (failedCount === 0 && warningCount === 0) {
      console.log('🎉 Perfect! Design system integration is complete!\n');
    } else if (failedCount === 0) {
      console.log('✅ Core integration complete!');
      console.log('⚠️  Review warnings to improve integration quality.\n');
    } else {
      console.log('❌ Integration incomplete. Fix failed checks above.\n');
    }

    console.log('Next Steps:');
    if (failedCount > 0) {
      console.log('  1. Fix failed checks');
      console.log('  2. Re-run verification');
    }
    if (warningCount > 0) {
      console.log(`  ${failedCount > 0 ? '3' : '1'}. Address warnings for better integration`);
    }
    console.log(`  ${failedCount > 0 || warningCount > 0 ? (failedCount > 0 ? '4' : '2') : '1'}. Test your app in both light and dark themes`);
    console.log(`  ${failedCount > 0 || warningCount > 0 ? (failedCount > 0 ? '5' : '3') : '2'}. Compare visual consistency with other min apps\n`);

    console.log('═══════════════════════════════════════════════════════════\n');
  }
}

// Run verification
const verifier = new IntegrationVerifier();
verifier.run().catch(error => {
  console.error('❌ Verification failed:', error);
  process.exit(1);
});
