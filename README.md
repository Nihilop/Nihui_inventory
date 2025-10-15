# Nihui IV - Inventory

**Version:** 0.2.0
**Author:** Nihui

Modern inventory management system with smart categorization, inspired by BetterBags with beautiful Nihui styling.

## Features

### View Modes

#### Category View (Default)
- **Automatic Organization:** Items sorted into logical categories
- **Categories Include:**
  - Consumables (food, potions, flasks)
  - Equipment (weapons, armor, trinkets)
  - Trade Goods (crafting materials, reagents)
  - Quest Items
  - Junk (gray items)
  - Miscellaneous
- **Clean Layout:** Each category displays as a separate section
- **Quick Navigation:** Find items by type instantly

#### All Items View
- **Traditional Bag View:** See all items together
- **Grid Layout:** Items arranged in a clean grid
- **Auto-Sort Available:** Middle-click to sort (only in this mode)
- **Sort Options:**
  - By Quality (rarity)
  - By Name (alphabetical)
  - By Item Level
  - By Type

### Separate Backpack & Bank
- **Independent Settings:** Backpack and bank have separate configurations
- **View Mode:** Choose category or all items view independently
- **Icon Size:** Different icon sizes for backpack vs. bank
- **Empty Slots:** Toggle empty slot display per container

### Search System
- **Quick Search:** Instant filtering across all items
- **Highlight Matches:** Found items highlighted
- **Clear Button:** Reset search with one click

### UI Customization

#### Icon Sizes
- **Backpack Icon Size:** Adjustable (default: 54px)
- **Bank Icon Size:** Adjustable (default: 48px)
- **Range:** 24px to 72px
- **Live Preview:** See changes immediately

#### Display Options
- **Show Empty Slots:** Toggle per container (backpack/bank)
- **Big Header:** Decorative header with character info and currency
- **Compact Mode:** Reduce spacing for smaller footprint

### Currency & Money Display
- **Gold Display:** Current gold, silver, copper
- **Currency Tracker:** Shows relevant currencies (badges, marks, etc.)
- **Clean Format:** Easy to read at a glance

### Character Selection
- **Multi-Character:** View items from other characters
- **Server-Wide:** Track inventory across your account
- **Quick Switch:** Dropdown to change character view

### Auto-Sort (All Items View Only)
- **Middle-Click Trigger:** Middle-click bag to sort
- **Sort Types:**
  - **Quality:** Rarity-based (legendary → common)
  - **Name:** Alphabetical order
  - **Item Level:** Highest to lowest
  - **Type:** Group by item type
- **Smart Stacking:** Automatically combines partial stacks

### Grid System
- **Smart Layout:** Efficient use of space
- **Adjustable Columns:** Grid adapts to icon size
- **Even Distribution:** Items spread evenly across rows

## Installation

1. Extract the `Nihui_iv` folder to:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
2. Restart World of Warcraft or type `/reload`
3. Open your bags - Nihui IV will replace the default UI

## Configuration

Open the options:
```
/nihuiiv
```

Or click the **gear icon** in the bag window.

### Quick Setup

1. Open your bags (default: `B` key)
2. Click the gear icon in the top-right
3. Choose view mode (Category or All Items)
4. Adjust icon size slider
5. Toggle display options (empty slots, big header)
6. Close options - settings save automatically

### View Modes Explained

**When to use Category View:**
- You want organized, grouped items
- You prefer browsing by item type
- You like a clean, sectioned layout

**When to use All Items View:**
- You want traditional bag appearance
- You need to sort items manually
- You prefer seeing everything at once

### Icon Size Recommendations

**Backpack:**
- **Large (54-72px):** Best visibility, easier clicking
- **Medium (37-53px):** Balanced size
- **Small (24-36px):** Compact, more items visible

**Bank:**
- **Medium (48-54px):** Good for storage browsing
- **Small (37-47px):** Fits many items on screen

### Sort Type Guide

**Quality Sort:**
- Orders: Legendary → Epic → Rare → Uncommon → Common → Poor
- Best for highlighting valuable items

**Name Sort:**
- Alphabetical A-Z
- Easy to find specific item names

**Item Level Sort:**
- Highest ilvl first
- Useful for gear management

**Type Sort:**
- Groups: Armor, Weapons, Consumables, etc.
- Similar to category view but in all items mode

### Reset to Defaults

```lua
/nihuiiv reset
```

Or delete saved variables:
```
WTF\Account\<ACCOUNT>\<SERVER>\<CHARACTER>\SavedVariables\NihuiIVDB.lua
```

## Compatibility

- **Game Version:** Retail (11.0.2+)
- **Bag Addons:** Replace AdiBags, Bagnon, or similar before using
- **Bank:** Works with both regular bank and Warband Bank
- **Void Storage:** Not supported (use default UI)

## Performance

- **Efficient Caching:** Item data cached for fast access
- **Smart Updates:** Only refresh on relevant events
- **Optimized Grid:** Fast layout calculations
- **Memory Friendly:** Minimal addon memory usage

## Saved Variables

Settings stored per character:
```
WTF\Account\<ACCOUNT>\<SERVER>\<CHARACTER>\SavedVariables\NihuiIVDB.lua
```

Settings saved:
- View modes (backpack, bank)
- Icon sizes (backpack, bank)
- Display options (empty slots, big header, compact mode)
- Sort type preference
- Auto-sort enabled/disabled

## Troubleshooting

**Q: Bags not opening**
A: Disable other bag addons and type `/reload`

**Q: Items not showing**
A: Check view mode - switch between Category and All Items

**Q: Search not working**
A: Clear search box and try again. Check for typos

**Q: Sort button not working**
A: Sorting only works in "All Items" view. Switch from Category view

**Q: Empty slots taking up space**
A: Disable "Show Empty Slots" in options (gear icon)

**Q: Bank looks different than backpack**
A: Bank and backpack have independent settings. Adjust each separately

**Q: Categories missing items**
A: Some items may be in "Miscellaneous" if they don't fit other categories

**Q: Icon size not saving**
A: Make sure you close the game properly (not alt+F4). Settings save on logout

## Key Bindings

**Default WoW Bindings:**
- `B` - Toggle backpack
- `Shift+B` - Open all bags
- Bank requires visiting a banker

**In Nihui IV:**
- `Middle-Click` bag icon - Auto-sort (All Items view only)
- `Search box` - Type to filter items
- `Gear icon` - Open options

## Tips

1. **Quick Sorting:** Use middle-click sort in All Items view for instant organization
2. **Category Browsing:** Switch to Category view when looking for specific item types
3. **Icon Size:** Use larger icons on backpack (used more often) and smaller on bank
4. **Empty Slots:** Hide empty slots in backpack for cleaner look, show in bank to see capacity
5. **Search Power:** Use partial names to find items quickly (e.g., "pot" finds potions)

## Components

Nihui IV is built with modular components from BetterBags:

- **Events System:** Efficient event handling
- **Search Engine:** Fast item filtering
- **Categories:** Smart item classification
- **Grid Layout:** Responsive item arrangement
- **Bags Controller:** Bag slot management
- **Items Controller:** Item data and display
- **Cache System:** Performance optimization
- **Stacking Logic:** Smart item grouping
- **Filters:** Advanced item filtering

## Commands

- `/nihuiiv` - Open configuration options
- `/nihuiiv reset` - Reset to defaults
- `/reload` - Reload UI

## Layouts

### Backpack Layout
- Compact header with character name
- Search bar prominently placed
- Currency display (gold, silver, copper)
- Grid or category sections
- Empty slots indicator (optional)

### Bank Layout
- Similar to backpack structure
- Bank-specific currency display
- Warband Bank tab support
- Independent view mode and icon size

## Credits

**Author:** Nihui
**Inspiration:** BetterBags (for inventory logic)
**Design:** Custom Nihui styling

Part of the **Nihui UI Suite**

---

*Beautiful bags, effortless organization*
