---
name: find-component
description: >
  Use BEFORE writing any JSX in a QwickApps project, or any time you need to know what
  @qwickapps/react-framework component to use for a given UI need.
  Describe what you need to build and this skill returns the matching component(s),
  props summary, usage example, and Storybook reference.
  If nothing matches, explicitly states "no match — invoke extend-framework".
---

# Find Component

Look up the right `@qwickapps/react-framework` component before writing any JSX.

## How to Use

Describe the UI element needed in plain language. Examples:
- "card with title, description, and a CTA button"
- "two-column responsive feature grid"
- "hero section with headline and two action buttons"
- "data table with sortable columns"
- "modal/dialog with a form inside"
- "sidebar that can collapse"
- "pricing cards in a grid"
- "navigation menu that works on mobile"

## Component Catalog

| Component | Category | Use when | Key props |
|-----------|----------|----------|-----------|
| `Section` | Layout | Page sections needing background/padding control | `background`, `padding` (`small`/`medium`/`large`) |
| `GridLayout` | Layout | Any multi-column responsive grid | `columns` (number or CSS fr string), `gap` |
| `GridCell` | Layout | Individual cell inside a GridLayout | `span`, `align`, `sx` |
| `GridCellWrapper` | Layout | Additional layout control wrapping cells | — |
| `CollapsibleLayout` | Layout | Sidebar + content layout that collapses | `collapsed`, `onToggle`, `sidebar`, `children` |
| `Page` | Pages | Full page wrapper with consistent chrome | `title`, `actions`, `breadcrumbs` |
| `FormPage` | Pages | Page where a form is the primary content | `form`, `onSubmit`, `title` |
| `Container` | Base | Constrained-width content wrapper | `maxWidth` |
| `ModelView` | Base | Generic model/entity detail view | `model`, `fields` |
| `HeroBlock` | Blocks | Hero section: headline + subheading + CTAs | `heading`, `subheading`, `actions[]` |
| `HeroSlideshow` | Blocks | Animated hero cycling through multiple slides | `slides[]` |
| `FeatureCard` | Blocks | Single feature with icon + title + description | `title`, `description`, `icon` |
| `FeatureGrid` | Blocks | Grid of FeatureCards | `features[]`, `columns` |
| `CardListGrid` | Blocks | Grid of cards from a data list | `items[]`, `columns`, `renderCard` |
| `Article` | Blocks | Long-form article or blog content | `content`, `title`, `author` |
| `Content` | Blocks | Rich text content block | `content` |
| `Text` | Blocks | Single themed text element | `text`, `variant` |
| `Image` | Blocks | Responsive image with aspect ratio control | `src`, `alt`, `aspectRatio` |
| `ImageGallery` | Blocks | Responsive grid of images | `images[]`, `columns` |
| `CoverImageHeader` | Blocks | Page header with full-bleed cover image | `image`, `title`, `subtitle` |
| `PageBannerHeader` | Blocks | Page header with banner background | `title`, `subtitle`, `background` |
| `ProductCard` | Blocks | Product listing card with price + CTA | `product`, `onAddToCart` |
| `OptionSelector` | Blocks | Multi-option selector (variants, sizes, plans) | `options[]`, `onSelect`, `value` |
| `Code` | Blocks | Syntax-highlighted code block | `code`, `language` |
| `Footer` | Blocks | Site footer with links + copyright | `links[]`, `copyright` |
| `Button` | Buttons | All interactive CTAs, links, and actions | `label`, `variant` (`contained`/`outlined`/`text`), `href`, `onClick`, `buttonSize` |
| `ThemeSwitcher` | Buttons | Light/dark mode toggle button | — |
| `PaletteSwitcher` | Buttons | Palette selector UI | — |
| `FormBlock` | Forms | Complete form with fields and submit handling | `fields[]`, `onSubmit`, `submitLabel` |
| `FormField` | Forms | Single labeled form field | `label`, `name`, `type`, `required` |
| `FormCheckbox` | Forms | Checkbox input with label | `label`, `name`, `defaultChecked` |
| `FormSelect` | Forms | Dropdown/select input | `label`, `name`, `options[]` |
| `SchemaFormRenderer` | Forms | Form rendered from a JSON schema definition | `schema`, `onSubmit` |
| `Captcha` | Forms | CAPTCHA verification widget | `onVerify`, `siteKey` |
| `TextField` | Input | Controlled text input field | `label`, `value`, `onChange`, `placeholder` |
| `TextInputField` | Input | Uncontrolled text input (form context) | `label`, `name`, `placeholder` |
| `HtmlInputField` | Input | Rich HTML / WYSIWYG input | `label`, `name` |
| `SelectInputField` | Input | Controlled select dropdown | `label`, `name`, `options[]`, `value`, `onChange` |
| `SwitchInputField` | Input | Toggle switch input | `label`, `name`, `defaultChecked` |
| `ChoiceInputField` | Input | Radio group or checkbox group | `label`, `name`, `choices[]`, `multiple` |
| `Menu` | Menu | Navigation menu (horizontal or vertical) | `items[]`, `orientation` |
| `MenuItem` | Menu | Single menu item | `label`, `href`, `icon`, `children` |
| `ResponsiveMenu` | Utility | Mobile-responsive navigation with hamburger | `items[]`, `logo` |
| `Dialog` | Dialogs | Modal dialog overlay | `open`, `onClose`, `title`, `children` |
| `DataTable` | Plugins | Full-featured data grid/table | `columns[]`, `rows[]`, `onSort`, `onFilter` |
| `StatCard` | Plugins | KPI/stat display card with trend indicator | `value`, `label`, `trend`, `icon` |
| `Breadcrumbs` | Utility | Page breadcrumb navigation trail | `items[]` |
| `ErrorBoundary` | Utility | React error boundary wrapper | `fallback` |
| `Markdown` | Utility | Rendered markdown content | `content` |
| `Html` | Utility | Safe sanitized HTML renderer | `html` |
| `Logo` | Utility | QwickApps wordmark logo | `size`, `variant` (`light`/`dark`) |
| `QwickIcon` | Utility | QwickApps icon mark (Q symbol) | `size` |
| `ProductLogo` | Utility | Product-specific logo | `product`, `size` |
| `QwickApp` | Core | **Required root wrapper for every app** | `appId`, `appName`, `dataSource` |
| `Scaffold` | Core | App scaffold with header/nav/footer slots | `navigation`, `header`, `footer` |

## Theme Variable Catalog

| Category | Variables |
|----------|-----------|
| **Primary** | `--theme-primary`, `--theme-primary-light`, `--theme-primary-dark`, `--theme-on-primary` |
| **Secondary** | `--theme-secondary`, `--theme-secondary-light`, `--theme-secondary-dark`, `--theme-on-secondary` |
| **Accent** | `--theme-accent`, `--theme-accent-light`, `--theme-accent-dark`, `--theme-on-accent` |
| **Background** | `--theme-background`, `--theme-background-dark`, `--theme-background-overlay`, `--theme-on-background` |
| **Surface** | `--theme-surface`, `--theme-surface-variant`, `--theme-surface-elevated`, `--theme-on-surface` |
| **Text** | `--theme-text-primary`, `--theme-text-secondary`, `--theme-text-disabled`, `--theme-text-inverted` |
| **Success** | `--theme-success`, `--theme-success-light`, `--theme-success-dark`, `--theme-on-success`, `--theme-success-border` |
| **Warning** | `--theme-warning`, `--theme-warning-light`, `--theme-warning-dark`, `--theme-on-warning`, `--theme-warning-border` |
| **Error** | `--theme-error`, `--theme-error-light`, `--theme-error-dark`, `--theme-on-error`, `--theme-error-border` |
| **Info** | `--theme-info`, `--theme-info-light`, `--theme-info-dark`, `--theme-on-info`, `--theme-info-border` |
| **Border** | `--theme-border-main`, `--theme-border-light`, `--theme-border-lighter`, `--theme-border-medium`, `--theme-border-dark` |
| **Outline** | `--theme-outline`, `--theme-outline-variant` |
| **Elevation** | `--theme-elevation-1`, `--theme-elevation-2`, `--theme-elevation-3`, `--theme-elevation-4` |
| **Radius** | `--theme-border-radius` (12px default), `--theme-border-radius-small` (8px), `--theme-border-radius-large` (16px) |
| **Control** | `--theme-control-bg`, `--theme-control-text`, `--theme-control-border`, `--theme-control-hover-bg`, `--theme-control-hover-text`, `--theme-control-hover-border` |
| **Panel** | `--theme-panel-bg-start`, `--theme-panel-bg-end`, `--theme-panel-border`, `--theme-panel-shadow` |
| **Floating** | `--theme-floating-bg`, `--theme-floating-border` |
| **Code** | `--theme-code-bg`, `--theme-code-text` |
| **Link** | `--theme-link-color`, `--theme-link-hover` |
| **Header** | `--theme-header-bg-start`, `--theme-header-bg-end`, `--theme-header-collapsed-bg-start`, `--theme-header-collapsed-bg-end` |
| **Overlay** | `--theme-overlay-80`, `--theme-overlay-90`, `--theme-overlay-95` |

## Response Format

**When a match is found:**
```
Component: <ComponentName>
Import: import { ComponentName } from '@qwickapps/react-framework'
Key props: prop1, prop2, prop3
Usage:
  <ComponentName prop1="..." prop2={...} />
Storybook: blocks-componentname--default
```

**When no match:**
```
No match found for: [your description]
→ Invoke extend-framework skill to add this component to the framework before continuing.
Do NOT use @mui/material as a substitute.
```
