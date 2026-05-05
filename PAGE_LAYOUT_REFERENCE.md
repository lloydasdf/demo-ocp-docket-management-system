# Case Details Page Layout Reference

## Visual Page Structure

```
┌──────────────────────────────────────────────────────────────────────────┐
│ SIDEBAR                                  MAIN CONTENT AREA                │
│                                                                            │
│ • Dashboard                    ┌────────────────────────────────────────┐ │
│ • Clearance Search ⭐          │ DOCKET HEADER                          │ │
│ • Docket Search                │                                        │ │
│ • Cases                        │ DOCKET: DK-2025-001                    │ │
│ • New Docket Entry             │ Multiple cases involving Carlos Rene   │ │
│ • Prosecutor Assignment        │ Santos - Drug and theft charges        │ │
│ • Status Update                │                            [Filed]     │ │
│ • Reports                      └────────────────────────────────────────┘ │
│                                                                            │
│                                ┌────────────────────────────────────────┐ │
│                                │ DOCKET OVERVIEW GRID                   │ │
│                                │                                        │ │
│ ◀─ Sidebar Theme              │ Created   │ Total Cases │ Status │ Pros│ │
│   Navy Blue                    │ 1/15/25   │ 2 cases    │ 1 Filed│ 1 a│ │
│                                │           │            │ 1 Pend │     │ │
│                                └────────────────────────────────────────┘ │
│                                                                            │
│                                ┌────────────────────────────────────────┐ │
│                                │ CASES UNDER THIS DOCKET          (2)  │ │
│                                │                                        │ │
│                                │ ┌──────────────────────────────────┐  │ │
│                                │ │ OCP-2025-001  [Filed]            │  │ │
│                                │ │ Incident: 1/15/2025              │  │ │
│                                │ │ Violations: 1 | Prosecutor: Maria│  │ │
│                                │ └──────────────────────────────────┘  │ │
│                                │                                        │ │
│                                │ ┌──────────────────────────────────┐  │ │
│                                │ │ OCP-2025-011  [Pending]          │  │ │
│                                │ │ Incident: 2/1/2025               │  │ │
│                                │ │ Violations: 1 | Prosecutor: —     │  │ │
│                                │ └──────────────────────────────────┘  │ │
│                                │                                        │ │
│                                └────────────────────────────────────────┘ │
│                                                                            │
│                                ┌────────────────────────────────────────┐ │
│                                │ CASE DETAILS (when selected)          │ │
│                                │                                        │ │
│                                │ Case OCP-2025-001          [Filed]    │ │
│                                │                                        │ │
│                                │ Date of Incident  │ Prosecutor │ Viol │ │
│                                │ 1/15/2025         │ Maria      │ 1    │ │
│                                │                                        │ │
│                                └────────────────────────────────────────┘ │
│                                                                            │
│                                ┌────────────────────────────────────────┐ │
│                                │ TABS (when case selected)              │ │
│                                │                                        │ │
│ Overview Parties Violations     │ ┌──────────────────────────────────┐  │ │
│ History Attachments Summary     │ │ TAB CONTENT                      │  │ │
│                                │ │ (Changes based on selected tab)   │  │ │
│                                │ │                                  │  │ │
│                                │ │ • Overview: Key case details     │  │ │
│                                │ │ • Parties: All people involved   │  │ │
│                                │ │ • Violations: All charges        │  │ │
│                                │ │ • History: Status timeline       │  │ │
│                                │ │ • Attachments: Documents        │  │ │
│                                │ │ • Summary: Complete overview     │  │ │
│                                │ └──────────────────────────────────┘  │ │
│                                │                                        │ │
│                                └────────────────────────────────────────┘ │
│                                                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

## Section Breakdown

### 1. Page Header (Fixed)
```
┌─────────────────────────────────────────────────────────────┐
│ DOCKET: DK-2025-001                                         │
│ Multiple cases involving Carlos Rene Santos - Drug/theft    │
│                                                  [Filed]    │
└─────────────────────────────────────────────────────────────┘
```
- Docket number as label
- Docket description/title
- Docket status badge (right side)
- Background: subtle gradient

### 2. Docket Overview Grid
```
┌──────────┐ ┌────────────┐ ┌───────────┐ ┌──────────────┐
│ Created  │ │Total Cases │ │Status     │ │ Prosecutors  │
│          │ │            │ │Breakdown  │ │ Assigned     │
│ 1/15/25  │ │ 2 cases    │ │ 1 Filed   │ │ 1            │
│          │ │            │ │ 1 Pending │ │              │
└──────────┘ └────────────┘ └───────────┘ └──────────────┘
```
- 4 cards in grid layout
- Gray background on each card
- Important stats at a glance
- Small text labels above values

### 3. Cases Under This Docket (Main Feature)
```
┌────────────────────────────────────────────────────────────┐
│ CASES UNDER THIS DOCKET                           (2) ◀─ │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ OCP-2025-001  [Filed]                             → │ │
│ │ Incident: 1/15/2025                                │ │
│ │ Violations: 1 | Prosecutor: Maria                  │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ OCP-2025-011  [Pending]                           → │ │
│ │ Incident: 2/1/2025                                 │ │
│ │ Violations: 1 | Prosecutor: —                      │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
└────────────────────────────────────────────────────────────┘

Selected state (blue border):
┌──────────────────────────────────────────────────────────┐
│ OCP-2025-001  [Filed]                             → │
│ Incident: 1/15/2025                                │
│ Violations: 1 | Prosecutor: Maria                  │
└──────────────────────────────────────────────────────────┘
```
- Each case in a bordered card
- Case number + status badge
- Key info: incident date, violations, prosecutor
- Arrow on right indicates clickability
- Selected case: blue border and background
- Hover effect available

### 4. Case Details Card (Appears When Selected)
```
┌────────────────────────────────────────────────────────────┐
│ Case Details                                               │
│ Case OCP-2025-001 information                  [Filed]    │
│                                                           │
│ Date of Incident  │ Assigned Prosecutor │ Violations     │
│ 1/15/2025         │ Maria Santos        │ 1              │
│                                                           │
└────────────────────────────────────────────────────────────┘
```
- Header with case number and status
- Three columns with key information
- Clear labels and values
- Only appears when case is selected

### 5. Tabs Section (Appears When Case Selected)
```
┌─────────────────────────────────────────────────────────────┐
│ [Overview] [Parties] [Violations] [History] [Attachments]   │
│ [Summary]                                                   │
│                                                             │
│ ┌──────────────────────────────────────────────────────────┐│
│ │ TAB CONTENT                                              ││
│ │ (Changes based on active tab)                           ││
│ │                                                          ││
│ │ This area shows different content for each tab          ││
│ └──────────────────────────────────────────────────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
- 6 tabs available
- Content area below tabs
- Full width, scrollable if needed
- Only visible when case is selected

## Color Scheme

### Background Colors
- Page background: Off-white (oklch 0.98)
- Card background: White (oklch 1)
- Header gradient: Navy to darker navy
- Hover state: Muted gray

### Status Colors
- Pending: Amber (oklch 0.7 hue 35)
- Filed: Navy Blue (oklch 0.45 hue 260)
- Dismissed: Gray (oklch 0.73)
- Resolved: Green (oklch 0.6 hue 130)
- RFI: Orange (oklch 0.6 hue 29)

### Text Colors
- Primary text: Dark (oklch 0.2)
- Secondary text: Gray (oklch 0.56)
- Labels: Muted gray

## Typography

- **Page title**: 3xl, bold, primary color
- **Section headers**: lg, bold, primary color
- **Card headers**: Base, semibold
- **Labels**: sm, muted color
- **Values**: Base to lg, semibold
- **Body text**: sm, regular
- **Tab labels**: sm, medium weight

## Spacing

- Section gaps: 1.5rem (24px)
- Card padding: 1.5rem (24px)
- Item gaps: 0.75rem to 1.5rem (12-24px)
- Grid gaps: 1rem (16px)
- Border radius: 0.375rem (6px) for smaller elements, 0.5rem (8px) for cards

## Responsive Behavior

### Desktop (md and up)
- Full width layout
- 3-column grid for overview cards
- Tabs at full width
- Two-column details in Overview tab

### Tablet (sm to md)
- Single/two column layouts
- Tabs may stack
- Cards remain full width

### Mobile (xs)
- Single column
- Tabs scroll horizontally
- All cards full width
- Adjusted font sizes

## Interactive States

### Case Card
- **Default**: Border, neutral
- **Hover**: Border lighter, subtle background
- **Selected**: Blue border (2px), light blue background
- **Transition**: Smooth 200ms

### Tab
- **Inactive**: Light text
- **Active**: Bold, colored underline
- **Hover**: Slightly darker

### Button
- **Default**: Styled button with primary color
- **Hover**: Darker shade
- **Click**: Visual feedback

## Data Density

- Header section: High density (lots of info)
- Cases section: Medium density (readable with whitespace)
- Detail section: Medium-high density (organized in tabs)
- Tab content: Variable based on tab type

## Accessibility

- Clear semantic HTML (Card, Tabs components from shadcn)
- Color not the only indicator (badges + text)
- Sufficient contrast (government standard colors)
- Keyboard navigation (built into components)
- Screen reader friendly (proper heading hierarchy)
