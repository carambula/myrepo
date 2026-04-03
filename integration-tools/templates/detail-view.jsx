/**
 * Detail View Template
 * 
 * This template shows how to create a detail view with:
 * - Proper spacing and layout
 * - Hero image/header section
 * - Metadata display
 * - Action buttons
 */

import React from 'react';
import { AppLayout, ContentContainer, Grid } from '@min-apps/design-system/layouts';
import { Button, Card, AppHeader } from '@min-apps/design-system/components';
import { spacing, borders } from '@min-apps/design-system/tokens';

// Example item data
const EXAMPLE_ITEM = {
  id: 1,
  title: 'Item Title',
  subtitle: 'Item Subtitle',
  description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
  imageUrl: '/placeholder.jpg',
  metadata: {
    date: '2024-01-01',
    category: 'Category',
    rating: '4.5',
    duration: '2h 30m'
  }
};

function DetailView() {
  const [item, setItem] = React.useState(EXAMPLE_ITEM);
  const [isFavorited, setIsFavorited] = React.useState(false);

  const handlePrimaryAction = () => {
    console.log('Primary action for:', item);
  };

  const handleFavorite = () => {
    setIsFavorited(!isFavorited);
  };

  const handleShare = () => {
    console.log('Share:', item);
  };

  return (
    <AppLayout
      header={
        <AppHeader 
          title={item.title}
          backButton
          onBack={() => console.log('Go back')}
        />
      }
    >
      <ContentContainer>
        {/* Hero section with image and primary info */}
        <div style={{ marginBottom: spacing[6] }}>
          <Grid columns={{ xs: 1, md: 2 }} gap={spacing[6]}>
            {/* Image */}
            <div>
              <img 
                src={item.imageUrl}
                alt={item.title}
                style={{
                  width: '100%',
                  borderRadius: borders.radii.artTile,
                  boxShadow: 'var(--shadow-md)'
                }}
              />
            </div>

            {/* Info */}
            <div>
              <h1 style={{ 
                marginBottom: spacing[2],
                fontSize: '2rem',
                fontWeight: 'bold'
              }}>
                {item.title}
              </h1>
              
              <p style={{ 
                marginBottom: spacing[4],
                color: 'var(--color-text-secondary)',
                fontSize: '1.125rem'
              }}>
                {item.subtitle}
              </p>

              {/* Metadata */}
              <div style={{ 
                display: 'flex',
                gap: spacing[3],
                marginBottom: spacing[4],
                flexWrap: 'wrap',
                fontSize: '0.875rem',
                color: 'var(--color-text-tertiary)'
              }}>
                <span>📅 {item.metadata.date}</span>
                <span>🏷️ {item.metadata.category}</span>
                <span>⭐ {item.metadata.rating}</span>
                <span>⏱️ {item.metadata.duration}</span>
              </div>

              {/* Actions */}
              <div style={{ 
                display: 'flex',
                gap: spacing[3],
                marginBottom: spacing[4]
              }}>
                <Button 
                  variant="primary"
                  onClick={handlePrimaryAction}
                >
                  Primary Action
                </Button>
                
                <Button 
                  variant={isFavorited ? 'secondary' : 'outline'}
                  onClick={handleFavorite}
                >
                  {isFavorited ? '❤️ Favorited' : '🤍 Favorite'}
                </Button>
                
                <Button 
                  variant="ghost"
                  onClick={handleShare}
                >
                  Share
                </Button>
              </div>
            </div>
          </Grid>
        </div>

        {/* Description */}
        <div style={{ marginBottom: spacing[6] }}>
          <h2 style={{ 
            marginBottom: spacing[3],
            fontSize: '1.5rem',
            fontWeight: '600'
          }}>
            About
          </h2>
          <p style={{ 
            lineHeight: 1.6,
            color: 'var(--color-text-primary)'
          }}>
            {item.description}
          </p>
        </div>

        {/* Additional sections (stats, related items, etc.) */}
        <div style={{ marginBottom: spacing[6] }}>
          <h2 style={{ 
            marginBottom: spacing[3],
            fontSize: '1.5rem',
            fontWeight: '600'
          }}>
            Details
          </h2>
          
          <Grid columns={{ xs: 2, md: 4 }} gap={spacing[4]}>
            {Object.entries(item.metadata).map(([key, value]) => (
              <Card key={key} padding="md">
                <h4 style={{ 
                  marginBottom: spacing[1],
                  textTransform: 'capitalize',
                  fontSize: '0.875rem',
                  color: 'var(--color-text-secondary)'
                }}>
                  {key}
                </h4>
                <p style={{ 
                  fontSize: '1.25rem',
                  fontWeight: 'bold',
                  color: 'var(--color-text-primary)'
                }}>
                  {value}
                </p>
              </Card>
            ))}
          </Grid>
        </div>

        {/* Related items section */}
        <div>
          <h2 style={{ 
            marginBottom: spacing[3],
            fontSize: '1.5rem',
            fontWeight: '600'
          }}>
            Related Items
          </h2>
          <p style={{ color: 'var(--color-text-secondary)' }}>
            Related items would go here...
          </p>
        </div>
      </ContentContainer>
    </AppLayout>
  );
}

export default DetailView;
