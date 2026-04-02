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
import { List, ListItem, Button, Input, AppHeader } from '@min-apps/design-system/components';
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
  const [items, setItems] = React.useState(EXAMPLE_ITEMS);
  const [searchQuery, setSearchQuery] = React.useState('');

  const handleItemClick = (item) => {
    console.log('Item clicked:', item);
    // Navigate to detail view
  };

  const handleSearch = (e) => {
    setSearchQuery(e.target.value);
    // Filter items based on search
  };

  const handleAction = (item, e) => {
    e.stopPropagation(); // Prevent item click
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
      {/* Search bar */}
      <div style={{ 
        padding: spacing[4],
        paddingBottom: spacing[2],
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

      {/* List */}
      <div style={{ padding: `0 ${spacing[4]}px ${spacing[4]}px` }}>
        <List spacing="default">
          {items.map(item => (
            <ListItem
              key={item.id}
              image={item.imageUrl}
              title={item.title}
              subtitle={item.subtitle}
              onClick={() => handleItemClick(item)}
              action={
                <Button 
                  variant="ghost" 
                  size="sm"
                  onClick={(e) => handleAction(item, e)}
                >
                  Action
                </Button>
              }
            />
          ))}
        </List>

        {/* Empty state */}
        {items.length === 0 && (
          <div style={{ 
            textAlign: 'center',
            padding: spacing[8],
            color: 'var(--color-text-secondary)'
          }}>
            <p>No items found</p>
          </div>
        )}
      </div>
    </AppLayout>
  );
}

export default ListView;
