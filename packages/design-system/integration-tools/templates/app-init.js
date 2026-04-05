/**
 * App Initialization Template
 * 
 * Copy this code into your main app entry point (e.g., src/index.js or src/main.jsx)
 */

import React from 'react';
import ReactDOM from 'react-dom/client';

import '@min-apps/design-system/src/styles/global.css';
import { initTheme } from '@min-apps/design-system';
import { MainAppLoading } from '@min-apps/design-system/components';

initTheme();

/**
 * Root shell — bootstrap loading is identical across all four min apps (mov min reference).
 */
function Root() {
  const [ready, setReady] = React.useState(false);

  React.useEffect(() => {
    import('./App').then((mod) => {
      window.__App = mod.default;
      setReady(true);
    });
  }, []);

  if (!ready) {
    return <MainAppLoading />;
  }

  const App = window.__App;
  return <App />;
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <Root />
  </React.StrictMode>
);
