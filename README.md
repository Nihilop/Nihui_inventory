# Nihui IV - Modern Inventory with Component Architecture

Architecture moderne inspirée de BetterBags avec séparation complète logique/UI.

## 📁 Structure

```
Nihui_iv/
├── components/          (12 composants - Pure logique)
│   ├── constants.lua   - Constantes (bag types, qualités, etc.)
│   ├── events.lua      - Event bus système
│   ├── search.lua      - Recherche indexée avancée
│   ├── categories.lua  - Catégorisation automatique
│   ├── grid.lua        - Système de layout dynamique
│   ├── money.lua       - Affichage argent (or/argent/cuivre)
│   ├── currency.lua    - Affichage devises (Bronze, etc.)
│   ├── bags.lua        - Hooks sacs Blizzard
│   ├── items.lua       - Récupération données items
│   ├── stacking.lua    - Stack items identiques
│   ├── slots.lua       - Création ItemButtons sécurisés
│   └── filters.lua     - Filtres et tri basiques
│
├── layouts/            (UI magnifique Nihui)
│   └── backpack.lua   - Layout backpack complet
│
└── core/
    └── init.lua        - Initialisation + wiring
```

## 🎯 Philosophie

**Séparation totale logique/layout** :
- `components/` = ZÉRO UI, juste de la logique pure
- `layouts/` = UI qui utilise les components
- Result: "Plug & play" - brancher les components dans n'importe quel layout

## 🚀 Features Backpack

✅ Design moderne Nihui (violet #9482c9)
✅ Search box temps réel (recherche indexée)
✅ Affichage argent (gold/silver/copper)
✅ Affichage devises (Bronze, etc.)
✅ Grid dynamique avec items
✅ Catégories automatiques (Epic, Consumables, Quest, Reagents)
✅ Stack items identiques (coffres)
✅ Compteur slots libres
✅ Draggable
✅ ESC pour fermer
✅ Remplace complètement l'inventaire Blizzard

## 🎮 Utilisation

**Ouvrir le backpack** :
- Touche `B`
- Clic sur icône sac (barre du bas)
- `/iv` pour commandes

**Features search** :
- Texte simple: `sword`
- Par propriété: `quality:4`, `ilvl>500`, `bound:true`
- Multiple termes: `sword epic` (OR logic)

**Catégories automatiques** :
- Epic & Legendary (quality >= 4)
- Consumables
- Quest Items
- Reagents
- Uncategorized (le reste)

## 🔧 Next Steps

- [ ] Layout Bank (backpack + bank dans même frame)
- [ ] Drag & drop dropzones
- [ ] Configuration UI
- [ ] Thème customization

## 📝 Notes Techniques

**Anti-taint** :
- Utilise `ItemButton` template sécurisé (pas de SetScript)
- Reparenting des frames Blizzard vers frame cachée
- Hooks sur `ToggleAllBags`, `OpenAllBags`, `CloseAllBags`

**Performance** :
- Object pooling pour ItemButtons
- Search indexé (prefix matching)
- Event bucketing pour limiter refreshes

**Composants réutilisables** :
```lua
-- Example: Utiliser les components
local items = ns.Components.Items.GetBackpackItems()
local stacked = ns.Components.Stacking.FilterStackedItems(items)
local results = ns.Components.Search.Search("sword")
local groups = ns.Components.Categories.GroupItemsByCategory(stacked)

local grid = ns.Components.Grid.Create(myFrame)
-- ... add items to grid ...
grid:Draw()
```

## 🎨 Nihui Theme

```lua
NIHUI_PURPLE = {0.58, 0.51, 0.79}  -- #9482c9
NIHUI_DARK = {0.1, 0.1, 0.12, 0.95}
NIHUI_DARKER = {0.05, 0.05, 0.07, 0.95}
```

---

**Version**: 0.2.0
**Architecture**: Component-based (BetterBags inspired)
**Status**: Backpack ✅ | Bank 🚧
