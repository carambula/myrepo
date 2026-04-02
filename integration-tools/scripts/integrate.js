#!/usr/bin/env node

/**
 * Design System Integration Script
 * 
 * Automates the integration of @min-apps/design-system into a min app.
 * 
 * Usage:
 *   cd /path/to/your-app
 *   node /path/to/design-system/integration-tools/scripts/integrate.js
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const APP_TYPES = {
  watchedit: 'WatchedIt (mov min)',
  podlink: 'podlink (pod min)',
  yourtube: 'yourtube (vid min)',
  cyclismo: 'Cyclismo guide (cyc min)'
};

class DesignSystemIntegrator {
  constructor(targetDir = process.cwd()) {
    this.targetDir = targetDir;
    this.appType = null;
    this.packageJson = null;
  }

  async run() {
    console.log('🎨 Design System Integration Script\n');
    console.log('Target directory:', this.targetDir);
    console.log('');

    // Step 1: Detect app type
    this.detectAppType();

    // Step 2: Verify package.json exists
    this.loadPackageJson();

    // Step 3: Check if design system is already installed
    this.checkDesignSystem();

    // Step 4: Install design system if needed
    await this.installDesignSystem();

    // Step 5: Create integration files
    this.createIntegrationFiles();

    // Step 6: Create app-specific checklist
    this.createChecklist();

    // Step 7: Summary
    this.printSummary();
  }

  detectAppType() {
    const packagePath = path.join(this.targetDir, 'package.json');
    
    if (!fs.existsSync(packagePath)) {
      console.log('⚠️  No package.json found in current directory.');
      console.log('   Please run this script from your app root directory.\n');
      process.exit(1);
    }

    const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
    const appName = pkg.name?.toLowerCase() || '';

    // Detect app type from package name or directory name
    if (appName.includes('watch') || this.targetDir.includes('watch')) {
      this.appType = 'watchedit';
    } else if (appName.includes('pod') || this.targetDir.includes('pod')) {
      this.appType = 'podlink';
    } else if (appName.includes('tube') || appName.includes('video') || this.targetDir.includes('tube')) {
      this.appType = 'yourtube';
    } else if (appName.includes('cycl') || this.targetDir.includes('cycl')) {
      this.appType = 'cyclismo';
    }

    if (this.appType) {
      console.log(`✅ Detected app type: ${APP_TYPES[this.appType]}\n`);
    } else {
      console.log('⚠️  Could not auto-detect app type.');
      console.log('   Proceeding with generic integration.\n');
    }
  }

  loadPackageJson() {
    const packagePath = path.join(this.targetDir, 'package.json');
    this.packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
  }

  checkDesignSystem() {
    const hasDesignSystem = 
      this.packageJson.dependencies?.['@min-apps/design-system'] ||
      this.packageJson.devDependencies?.['@min-apps/design-system'];

    if (hasDesignSystem) {
      console.log('✅ Design system is already installed\n');
    } else {
      console.log('📦 Design system not found in package.json\n');
    }
  }

  async installDesignSystem() {
    const hasDesignSystem = 
      this.packageJson.dependencies?.['@min-apps/design-system'] ||
      this.packageJson.devDependencies?.['@min-apps/design-system'];

    if (hasDesignSystem) {
      return;
    }

    console.log('Installing @min-apps/design-system...');
    
    try {
      // For now, we'll use a local file path reference
      // In production, this would be: npm install @min-apps/design-system
      const designSystemPath = path.join(__dirname, '..', '..');
      
      console.log(`Adding local reference to design system...`);
      
      // Update package.json
      this.packageJson.dependencies = this.packageJson.dependencies || {};
      this.packageJson.dependencies['@min-apps/design-system'] = `file:${designSystemPath}`;
      
      fs.writeFileSync(
        path.join(this.targetDir, 'package.json'),
        JSON.stringify(this.packageJson, null, 2)
      );
      
      console.log('✅ Design system added to package.json');
      console.log('   Run `npm install` to install dependencies\n');
    } catch (error) {
      console.error('❌ Failed to install design system:', error.message);
    }
  }

  createIntegrationFiles() {
    console.log('Creating integration files...\n');

    // Create src directory if it doesn't exist
    const srcDir = path.join(this.targetDir, 'src');
    if (!fs.existsSync(srcDir)) {
      fs.mkdirSync(srcDir, { recursive: true });
    }

    // Create theme setup file
    this.createThemeSetup();

    // Create example App.jsx with design system
    this.createAppExample();

    // Create example home screen
    this.createHomeExample();

    console.log('✅ Integration files created\n');
  }

  createThemeSetup() {
    const themePath = path.join(this.targetDir, 'src', 'theme-setup.js');
    
    if (fs.existsSync(themePath)) {
      console.log('   ⏭️  theme-setup.js already exists, skipping');
      return;
    }

    const themeContent = `/**
 * Design System Theme Setup
 * 
 * Import this file in your app's entry point (e.g., index.js or main.jsx)
 */

import '@min-apps/design-system/src/styles/global.css';
import { initTheme } from '@min-apps/design-system';

/**
 * Initialize the theme system
 * This will:
 * - Load the saved theme preference from localStorage
 * - Apply the theme to the document
 * - Set up theme change listeners
 */
export function setupTheme() {
  initTheme();
}

/**
 * Optional: Set a custom default theme for this app
 */
export function setAppTheme(themeName = 'light') {
  const { applyTheme } = await import('@min-apps/design-system');
  applyTheme(themeName);
}
`;

    fs.writeFileSync(themePath, themeContent);
    console.log('   ✅ Created theme-setup.js');
  }

  createAppExample() {
    const appPath = path.join(this.targetDir, 'src', 'App.example.jsx');
    
    if (fs.existsSync(appPath)) {
      console.log('   ⏭️  App.example.jsx already exists, skipping');
      return;
    }

    const appContent = `/**
 * Example App Component with Design System
 * 
 * This is a reference implementation showing how to use the design system.
 * Copy patterns from here into your actual App.jsx
 */

import React from 'react';
import { AppLayout } from '@min-apps/design-system/layouts';
import { Button, ThemeToggle } from '@min-apps/design-system/components';
import './theme-setup.js';

function App() {
  return (
    <AppLayout
      header={
        <header style={{ 
          display: 'flex', 
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '16px'
        }}>
          <h1>My Min App</h1>
          <ThemeToggle />
        </header>
      }
    >
      <main>
        <h2>Welcome to Your Min App</h2>
        <p>This app is now using the min-apps design system!</p>
        
        <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
          <Button variant="primary">Primary Button</Button>
          <Button variant="secondary">Secondary Button</Button>
          <Button variant="outline">Outline Button</Button>
        </div>
      </main>
    </AppLayout>
  );
}

export default App;
`;

    fs.writeFileSync(appPath, appContent);
    console.log('   ✅ Created App.example.jsx');
  }

  createHomeExample() {
    const homePath = path.join(this.targetDir, 'src', 'Home.example.jsx');
    
    if (fs.existsSync(homePath)) {
      console.log('   ⏭️  Home.example.jsx already exists, skipping');
      return;
    }

    const homeContent = `/**
 * Example Home Screen with Design System
 * 
 * This shows the proper logo positioning and spacing
 * using the HomeLayout component.
 */

import React from 'react';
import { HomeLayout } from '@min-apps/design-system/layouts';
import { Button } from '@min-apps/design-system/components';
import { spacing } from '@min-apps/design-system/tokens';

function Home() {
  return (
    <HomeLayout
      logo="/logo.svg"  // Replace with your app's logo
      title="Your App Name"
      subtitle="Your app tagline"
    >
      <div style={{ 
        display: 'flex', 
        flexDirection: 'column', 
        gap: spacing[4],
        marginTop: spacing[6]
      }}>
        <Button 
          variant="primary" 
          fullWidth
          onClick={() => console.log('Get Started')}
        >
          Get Started
        </Button>
        
        <Button 
          variant="outline" 
          fullWidth
          onClick={() => console.log('Learn More')}
        >
          Learn More
        </Button>
      </div>
      
      {/* Logo will be positioned at exactly 32px from top on desktop */}
      {/* Buttons will have consistent 24px × 12px padding */}
    </HomeLayout>
  );
}

export default Home;
`;

    fs.writeFileSync(homePath, homeContent);
    console.log('   ✅ Created Home.example.jsx');
  }

  createChecklist() {
    const checklistPath = path.join(this.targetDir, 'INTEGRATION_CHECKLIST.md');
    
    const checklist = `# Design System Integration Checklist
${this.appType ? `\n**App**: ${APP_TYPES[this.appType]}` : ''}
**Date Started**: ${new Date().toISOString().split('T')[0]}

## ✅ Completed
- [ ] Design system added to package.json
- [ ] npm install completed

## 🔧 Setup Phase

- [ ] Import global styles in main entry file
  \`\`\`javascript
  import '@min-apps/design-system/src/styles/global.css';
  \`\`\`

- [ ] Initialize theming
  \`\`\`javascript
  import { initTheme } from '@min-apps/design-system';
  initTheme();
  \`\`\`

- [ ] Verify theme switching works
  - [ ] Light theme displays correctly
  - [ ] Dark theme displays correctly
  - [ ] Theme persists on reload

## 📏 Spacing Migration

### Logo Positioning (Critical!)
- [ ] Update home screen logo positioning
  - [ ] Logo top margin: \`spacing.logo.marginTop\` (32px desktop)
  - [ ] Logo bottom margin: \`spacing.logo.marginBottom\` (24px desktop)
  - [ ] Logo size: 120px desktop, 80px mobile
  - [ ] Logo horizontally centered

### Page Margins
- [ ] Replace page margins with \`spacing.page.*\`
  - [ ] Top: \`spacing.page.marginTop\` (24px)
  - [ ] Left: \`spacing.page.marginLeft\` (16px)
  - [ ] Right: \`spacing.page.marginRight\` (16px)
  - [ ] Bottom: \`spacing.page.marginBottom\` (24px)

### Button Spacing
- [ ] Update button padding
  - [ ] Horizontal: \`spacing.button.paddingX\` (24px)
  - [ ] Vertical: \`spacing.button.paddingY\` (12px)
  - [ ] Icon-text gap: \`spacing.button.gap\` (8px)

### List Item Spacing
- [ ] Update list items
  - [ ] Vertical padding: \`spacing.list.itemPaddingY\` (16px)
  - [ ] Horizontal padding: \`spacing.list.itemPaddingX\` (16px)
  - [ ] Image-text gap: \`spacing.list.itemGap\` (12px)
  - [ ] Between items: \`spacing.list.betweenItems\` (8px)

## 🎨 Color Migration

- [ ] Replace hard-coded colors with CSS variables
  - [ ] Backgrounds: \`var(--color-background-primary)\`
  - [ ] Text: \`var(--color-text-primary)\`
  - [ ] Borders: \`var(--color-border-primary)\`
  - [ ] Primary: \`var(--color-primary-main)\`
  - [ ] Secondary: \`var(--color-secondary-main)\`

- [ ] Test all screens in both themes
  - [ ] Verify color contrast
  - [ ] Check hover states
  - [ ] Check active states
  - [ ] Check disabled states

## 🧩 Component Migration

### Buttons
- [ ] Replace custom buttons with \`<Button>\`
  - [ ] Primary buttons: \`variant="primary"\`
  - [ ] Secondary buttons: \`variant="secondary"\`
  - [ ] Outline buttons: \`variant="outline"\`

### List Items
- [ ] Replace custom list items with \`<ListItem>\`
  - [ ] Add \`title\`, \`subtitle\`, \`image\` props
  - [ ] Add \`onClick\` handlers
  - [ ] Add \`action\` prop for buttons

### Layouts
- [ ] Replace custom layouts
  - [ ] Home screen: Use \`<HomeLayout>\`
  - [ ] App layout: Use \`<AppLayout>\`
  - [ ] Lists: Use \`<List>\` wrapper

${this.getAppSpecificTasks()}

## 🧪 Testing

### Visual Testing
- [ ] Desktop (1920×1080)
- [ ] Desktop (1440×900)
- [ ] Tablet (768×1024)
- [ ] Mobile (375×667)
- [ ] Mobile (414×896)

### Functionality
- [ ] Theme switching works
- [ ] All navigation works
- [ ] All buttons work
- [ ] All forms work
- [ ] All lists render correctly

### Consistency Check
- [ ] Logo position matches other min apps
- [ ] Button spacing matches other min apps
- [ ] List spacing matches other min apps
- [ ] Page margins match other min apps

### Accessibility
- [ ] Keyboard navigation works
- [ ] Focus indicators visible
- [ ] Color contrast sufficient
- [ ] Screen reader compatible

### Cross-browser
- [ ] Chrome/Edge
- [ ] Firefox
- [ ] Safari
- [ ] Mobile Safari
- [ ] Mobile Chrome

## 🧹 Cleanup

- [ ] Remove old custom component files
- [ ] Remove old CSS with hard-coded values
- [ ] Remove unused dependencies
- [ ] Update app documentation
- [ ] Update README

## 🎯 Final Verification

- [ ] All spacing uses design tokens
- [ ] All colors use CSS variables
- [ ] All components use design system
- [ ] Themes work throughout app
- [ ] No console errors
- [ ] No visual regressions
- [ ] Accessibility standards met

## 📝 Notes

_Add any app-specific notes, issues, or customizations here:_


---

## Next Steps

1. Work through each section in order
2. Test frequently
3. Compare with other min apps for consistency
4. Document any issues or customizations

## Resources

- [Integration Tools](../design-system/integration-tools/)
- [Design System Docs](../design-system/docs/)
- [Migration Guide](../design-system/docs/migration.md)
- [Component Docs](../design-system/docs/components.md)
`;

    fs.writeFileSync(checklistPath, checklist);
    console.log('✅ Created INTEGRATION_CHECKLIST.md\n');
  }

  getAppSpecificTasks() {
    const tasks = {
      watchedit: `
### WatchedIt-Specific Tasks
- [ ] Replace movie card components with design system
- [ ] Update poster image sizing (consistent dimensions)
- [ ] Standardize movie list spacing
- [ ] Update player controls positioning
- [ ] Migrate search interface
- [ ] Update detail view layout`,

      podlink: `
### PodLink-Specific Tasks
- [ ] Replace podcast episode components
- [ ] Standardize episode card spacing
- [ ] Update audio player controls styling
- [ ] Normalize episode list items
- [ ] Migrate show detail view
- [ ] Update playback interface`,

      yourtube: `
### YourTube-Specific Tasks
- [ ] Replace video card components
- [ ] Standardize thumbnail sizing (16:9 aspect ratio)
- [ ] Update video metadata spacing
- [ ] Normalize video list items
- [ ] Migrate video player interface
- [ ] Update channel view layout`,

      cyclismo: `
### Cyclismo-Specific Tasks
- [ ] Replace route/guide components
- [ ] Standardize map container sizing
- [ ] Update route detail spacing
- [ ] Normalize guide list items
- [ ] Migrate race calendar view
- [ ] Update rider/team profiles`
    };

    return this.appType ? tasks[this.appType] : '';
  }

  printSummary() {
    console.log('═══════════════════════════════════════════════════════════');
    console.log('🎉 Integration Setup Complete!');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    console.log('Files Created:');
    console.log('  📄 INTEGRATION_CHECKLIST.md - Your integration roadmap');
    console.log('  📄 src/theme-setup.js - Theme initialization');
    console.log('  📄 src/App.example.jsx - Example app component');
    console.log('  📄 src/Home.example.jsx - Example home screen\n');
    
    console.log('Next Steps:\n');
    console.log('  1. Run: npm install');
    console.log('  2. Import theme-setup.js in your main entry file');
    console.log('  3. Review INTEGRATION_CHECKLIST.md');
    console.log('  4. Check the example files for reference implementations');
    console.log('  5. Start migrating your components\n');
    
    console.log('Need Help?');
    console.log('  📚 Design System Docs: ./node_modules/@min-apps/design-system/docs/');
    console.log('  📋 Integration Checklist: ./INTEGRATION_CHECKLIST.md');
    if (this.appType) {
      console.log(`  📱 App-Specific Guide: ./node_modules/@min-apps/design-system/integration-tools/app-specific/${this.appType}-integration.md\n`);
    }
    
    console.log('═══════════════════════════════════════════════════════════\n');
  }
}

// Run the integration
const integrator = new DesignSystemIntegrator();
integrator.run().catch(error => {
  console.error('❌ Integration failed:', error);
  process.exit(1);
});
