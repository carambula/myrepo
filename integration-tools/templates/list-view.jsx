/**
 * List View Template
 * 
 * This template shows how to create a list view with:
 * - Consistent spacing between items
 * - Proper use of ListItem component
 * - Image + title + subtitle pattern
 */

import React from 'react';
import { AppLayout } from '@min-apps/design-system/layouts';
import { List, ListItem, Button, Input, AppHeader, MainAppLoading } from '@min-apps/design-system/components';
import { spacing } from '@min-apps/design-system/tokens';

// Example data structure
const EXAMPLE_ITEMS = [
  {
    id: 1,
    title: 'Item Title 1',
    subtitle: 'Item description or metadata',
    imageUrl: '/placeholder.jpg',
    metadata: 'Additional info'
  },
  // ... more items
];

function ListView() {
  const [items, setItems] = React.useState(null);
  const [searchQuery, setSearchQuery] = React.useState('');
  const [isLoading, setIsLoading] = React.useState(true);

  React.useEffect(() => {
    fetchItems().then((data) => {
      setItems(data);
      setIsLoading(false);
    });
  }, []);

  if (isLoading || !items) {
    return <MainAppLoading />;
  }

  const handleItemClick = (item) => {
    console.log('Item clicked:', item);
    // Navigate to detail view
  };

  const handleSearch = (e) => {
    setSearchQuery(e.target.value);
    // Filter items based on search
  };

  const handleAction = (item, e) => {
    // CRITICAL: stopPropagation prevents the row onClick from firing
    // This allows separate tap areas: row click vs action button click
    e.stopPropagation();
    console.log('Action for:', item);
  };

  return (
    <AppLayout
      header={
        <AppHeader 
          title="My List"
          backButton
          onBack={() => console.log('Go back')}
        />
      }
    >
      {/* Sticky search — horizontal inset comes from AppLayout main; only vertical rhythm here */}
      <div style={{ 
        paddingTop: 0,
        paddingBottom: spacing[2],
        paddingLeft: 0,
        paddingRight: 0,
        position: 'sticky',
        top: 0,
        backgroundColor: 'var(--color-background-primary)',
        zIndex: 10
      }}>
        <Input
          type="search"
          placeholder="Search items..."
          value={searchQuery}
          onChange={handleSearch}
          fullWidth
        />
      </div>

      {/* List — no extra horizontal padding inside AppLayout main (page grid is mov min) */}
      <div style={{ paddingBottom: spacing[4] }}>
        {isLoading ? (
          <div
            className="min-content-status min-content-status--loading"
            role="status"
            aria-live="polite"
          >
            <span className="min-content-status__spinner" aria-hidden="true" />
            <span className="min-content-status__label">Loading…</span>
          </div>
        ) : (
          <>
            <List spacing="default">
              {items.map(item => (
                <ListItem
                  key={item.id}
                  image={item.imageUrl}
                  title={item.title}
                  subtitle={item.subtitle}
                  // Row click - opens detail view
                  onClick={() => handleItemClick(item)}
                  action={
                    <Button 
                      variant="ghost" 
                      size="sm"
                      // Action click - performs secondary action
                      // stopPropagation prevents row onClick from firing
                      onClick={(e) => handleAction(item, e)}
                    >
                      Action
                    </Button>
                  }
                />
              ))}
            </List>

            {/* Empty state — left-aligned; see docs/visual-specification.md */}
            {items.length === 0 && (
              <div className="min-content-status min-content-status--empty">
                <p className="min-content-status__message">No items found</p>
              </div>
            )}
          </>
        )}
      </div>
    </AppLayout>
  );
}

function fetchItems() {
  return new Promise((resolve) => setTimeout(() => resolve(EXAMPLE_ITEMS), 300));
}

export default ListView;
