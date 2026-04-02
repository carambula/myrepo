/**
 * App Initialization Template
 * 
 * Copy this code into your main app entry point (e.g., src/index.js or src/main.jsx)
 */

import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

// Import design system global styles
import '@min-apps/design-system/src/styles/global.css';

// Import and initialize theme
import { initTheme } from '@min-apps/design-system';

// Initialize theme system
// This will:
// - Load saved theme preference from localStorage
// - Apply the theme to the document
// - Set up theme change listeners
initTheme();

// Optional: Set a custom default theme for this app
// import { applyTheme } from '@min-apps/design-system';
// applyTheme('light'); // or 'dark', or your custom theme name

// Render app
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
