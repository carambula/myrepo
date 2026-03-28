# Component Documentation

Complete API reference for all components in the min apps design system.

## Button

Standardized button component with consistent styling.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Button content |
| `variant` | `'primary' \| 'secondary' \| 'outline' \| 'ghost' \| 'text'` | `'primary'` | Button style variant |
| `size` | `'small' \| 'medium' \| 'large'` | `'medium'` | Button size |
| `fullWidth` | `boolean` | `false` | Full width button |
| `disabled` | `boolean` | `false` | Disabled state |
| `onClick` | `function` | - | Click handler |
| `type` | `'button' \| 'submit' \| 'reset'` | `'button'` | Button type |

### Examples

```javascript
import { Button } from '@min-apps/design-system';

// Primary button
<Button variant="primary" onClick={handleClick}>
  Click Me
</Button>

// Secondary button
<Button variant="secondary" size="large">
  Large Button
</Button>

// Outline button
<Button variant="outline" fullWidth>
  Full Width
</Button>

// Disabled button
<Button disabled>
  Disabled
</Button>
```

---

## ListItem

Standardized list item with image, title, subtitle, and optional actions.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | `string` | - | Main title text |
| `subtitle` | `string` | - | Secondary text |
| `image` | `string` | - | Image URL |
| `imageAlt` | `string` | `''` | Image alt text |
| `action` | `ReactNode` | - | Action element (e.g., button, icon) |
| `onClick` | `function` | - | Click handler |
| `children` | `ReactNode` | - | Additional content |

### Examples

```javascript
import { ListItem } from '@min-apps/design-system';

// Basic list item
<ListItem
  title="Movie Title"
  subtitle="2023 • Drama"
  image="/poster.jpg"
  onClick={handleItemClick}
/>

// With action button
<ListItem
  title="Podcast Episode"
  subtitle="45 min • Jan 15"
  image="/cover.jpg"
  action={<Button variant="ghost">Play</Button>}
/>

// With custom content
<ListItem
  title="Video Title"
  subtitle="1.2M views"
  image="/thumbnail.jpg"
>
  <div>Custom content here</div>
</ListItem>
```

---

## AppHeader

Standardized application header with logo and actions.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `logo` | `string` | - | Logo image URL |
| `logoAlt` | `string` | `'App Logo'` | Logo alt text |
| `title` | `string` | - | App title |
| `actions` | `ReactNode` | - | Header actions (e.g., theme toggle) |
| `showShadow` | `boolean` | `false` | Show bottom shadow |

### Examples

```javascript
import { AppHeader, ThemeToggle } from '@min-apps/design-system';

<AppHeader
  logo="/logo.svg"
  title="WatchedIt"
  actions={<ThemeToggle />}
  showShadow
/>
```

---

## Card

Container component with elevation and padding.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Card content |
| `padding` | `'none' \| 'small' \| 'medium' \| 'large'` | `'medium'` | Internal padding |
| `elevation` | `'none' \| 'small' \| 'medium' \| 'large'` | `'medium'` | Shadow elevation |
| `hoverable` | `boolean` | `false` | Add hover effect |
| `onClick` | `function` | - | Click handler |

### Examples

```javascript
import { Card } from '@min-apps/design-system';

// Basic card
<Card>
  <h2>Card Title</h2>
  <p>Card content</p>
</Card>

// Hoverable card
<Card hoverable elevation="large" onClick={handleClick}>
  <p>Clickable card with hover effect</p>
</Card>

// No padding card
<Card padding="none">
  <img src="/image.jpg" alt="Full width image" />
</Card>
```

---

## Input

Standardized text input with label and error states.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `type` | `string` | `'text'` | Input type |
| `placeholder` | `string` | - | Placeholder text |
| `value` | `string` | - | Input value |
| `onChange` | `function` | - | Change handler |
| `disabled` | `boolean` | `false` | Disabled state |
| `error` | `boolean` | `false` | Error state |
| `label` | `string` | - | Input label |
| `helperText` | `string` | - | Helper or error text |
| `fullWidth` | `boolean` | `false` | Full width input |

### Examples

```javascript
import { Input } from '@min-apps/design-system';

// Basic input
<Input
  label="Email"
  type="email"
  placeholder="Enter your email"
  value={email}
  onChange={(e) => setEmail(e.target.value)}
/>

// Input with error
<Input
  label="Password"
  type="password"
  error
  helperText="Password must be at least 8 characters"
  value={password}
  onChange={(e) => setPassword(e.target.value)}
/>

// Full width input
<Input
  label="Search"
  placeholder="Search..."
  fullWidth
/>
```

---

## ThemeToggle

Button to toggle between light and dark themes.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `currentTheme` | `'light' \| 'dark'` | `'light'` | Current theme |
| `onToggle` | `function` | - | Toggle handler |

### Examples

```javascript
import { ThemeToggle, useTheme } from '@min-apps/design-system';

function App() {
  const { theme, toggleTheme } = useTheme();
  
  return (
    <ThemeToggle
      currentTheme={theme}
      onToggle={toggleTheme}
    />
  );
}
```

---

## AppLayout

Standard page layout with header, main content, and footer.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Main content |
| `header` | `ReactNode` | - | Header component |
| `footer` | `ReactNode` | - | Footer component |

### Examples

```javascript
import { AppLayout, AppHeader } from '@min-apps/design-system';

<AppLayout
  header={<AppHeader logo="/logo.svg" title="My App" />}
  footer={<Footer />}
>
  <h1>Page Content</h1>
  <p>Your content here</p>
</AppLayout>
```

---

## HomeLayout

Specialized layout for home/landing pages with centered logo.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Page content |
| `logo` | `string` | - | Logo image URL |
| `logoAlt` | `string` | `'App Logo'` | Logo alt text |
| `title` | `string` | - | App title |
| `subtitle` | `string` | - | App subtitle |

### Examples

```javascript
import { HomeLayout, Button } from '@min-apps/design-system';

<HomeLayout
  logo="/logo.svg"
  title="WatchedIt"
  subtitle="Track your movies and shows"
>
  <Button variant="primary" fullWidth>Get Started</Button>
  <Button variant="outline" fullWidth>Learn More</Button>
</HomeLayout>
```

---

## ContentContainer

Centers content with max width and padding.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Container content |
| `maxWidth` | `'small' \| 'default' \| 'large' \| 'full'` | `'default'` | Maximum width |
| `padding` | `'none' \| 'small' \| 'default' \| 'large'` | `'default'` | Horizontal padding |

### Examples

```javascript
import { ContentContainer } from '@min-apps/design-system';

<ContentContainer maxWidth="small">
  <p>Centered content with small max width</p>
</ContentContainer>
```

---

## List

Container for list items with consistent spacing.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | List items |
| `spacing` | `'compact' \| 'default' \| 'comfortable'` | `'default'` | Space between items |

### Examples

```javascript
import { List, ListItem } from '@min-apps/design-system';

<List spacing="comfortable">
  <ListItem title="Item 1" subtitle="Description" />
  <ListItem title="Item 2" subtitle="Description" />
  <ListItem title="Item 3" subtitle="Description" />
</List>
```

---

## Grid

Responsive grid layout.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Grid items |
| `columns` | `object` | `{ xs: 1, sm: 2, md: 3, lg: 4 }` | Columns per breakpoint |
| `gap` | `'none' \| 'small' \| 'default' \| 'large'` | `'default'` | Gap between items |

### Examples

```javascript
import { Grid, Card } from '@min-apps/design-system';

<Grid columns={{ xs: 1, sm: 2, md: 3 }} gap="large">
  <Card>Item 1</Card>
  <Card>Item 2</Card>
  <Card>Item 3</Card>
</Grid>
```

---

## Stack

Vertical or horizontal stack with spacing.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Stack items |
| `direction` | `'vertical' \| 'horizontal'` | `'vertical'` | Stack direction |
| `spacing` | `'none' \| 'small' \| 'default' \| 'large'` | `'default'` | Space between items |
| `align` | `string` | `'stretch'` | CSS align-items |
| `justify` | `string` | `'flex-start'` | CSS justify-content |

### Examples

```javascript
import { Stack, Button } from '@min-apps/design-system';

// Vertical stack
<Stack spacing="large">
  <Button>Button 1</Button>
  <Button>Button 2</Button>
  <Button>Button 3</Button>
</Stack>

// Horizontal stack
<Stack direction="horizontal" spacing="small" align="center">
  <span>Label:</span>
  <Button size="small">Action</Button>
</Stack>
```
