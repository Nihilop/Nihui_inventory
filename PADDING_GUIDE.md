# Nihui IV - Guide des Paddings

Ce fichier liste tous les paddings/marges principaux de l'addon pour faciliter les ajustements visuels.

## Paddings Globaux (Frame principale)

### Fichier: `layouts/backpack.lua`

#### Ligne 231-232: Title Bar (Barre de titre)
```lua
bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -45)  -- 33px left (50/1.5), 45px top
bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -33, -45)  -- 33px right
```

#### Ligne 297: Search Box
```lua
container:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -85)  -- 33px left, 85px top
```

#### Ligne 393-394: ScrollFrame (Zone de contenu principal)
```lua
scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -123)  -- 33px left, 123px top (85 + 28 + 10)
scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -50, 80)  -- 50px right (33 + 17 scrollbar), 80px bottom
```

#### Ligne 369: Money Display
```lua
frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 33, 50)  -- 33px left/bottom (aligned with scroll content)
```

#### Ligne 376: Currency Display
```lua
frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -50, 50)  -- 50px right, 50px bottom
```

#### Ligne 383: Free Slots Text
```lua
text:SetPoint("BOTTOM", parent, "BOTTOM", 0, 38)  -- 38px bottom
```

---

## Scrollbar Right Padding (IMPORTANT)

#### Ligne 412-413: Position de la scrollbar
```lua
scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -8, -16)  -- -8 = padding scrollbar <-> border
scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -8, 16)
```

**Pour ajuster l'espace entre la scrollbar et la bordure droite:**
- Modifie la valeur `-8` (première valeur dans SetPoint)
- Valeur plus négative = plus d'espace (ex: `-12`)
- Valeur moins négative = moins d'espace (ex: `-4`)

---

## Spacings Internes

#### Ligne 447-448: Category Headers
```lua
header:SetHeight(28)  -- 8px top + 12px text + 8px bottom
headerText:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -8)  -- 8px top margin
```

#### Ligne 623: Grid Principal (entre catégories)
```lua
itemGrid:SetSpacing(4)  -- 4px entre les catégories
```

#### Ligne 534: Category Grids (entre items)
```lua
categoryGrid:SetSpacing(4)  -- 4px entre les items
```

---

## Paddings de la Search Box

#### Ligne 298: Hauteur du container
```lua
container:SetHeight(28)  -- Hauteur totale (réduite pour un look plus serré)
```

#### Ligne 306: Hauteur du background coin
```lua
coinBg:SetHeight(28)  -- Match container height
```

#### Ligne 314-315: EditBox padding interne
```lua
box:SetPoint("LEFT", coinBg, "LEFT", 12, 0)  -- 12px padding left
box:SetPoint("RIGHT", coinBg, "RIGHT", -12, 0)  -- 12px padding right
```

---

## Notes

- **Padding horizontal global**: 33px (50/1.5) pour tous les éléments principaux
- **ScrollFrame right padding**: 50px (33px base + 17px scrollbar width)
- **Scrollbar right padding from border**: -8px (ajustable ligne 412-413)
- **Bottom padding**: 80px pour laisser de l'espace pour money/currency/slots
- **Spacing entre catégories et items**: 4px (compact)
- **Headers de catégories**: Prennent toute la largeur (`maxWidth`) pour forcer l'alignement vertical
- **Search box height**: 28px (réduite pour un look plus compact)

Pour ajuster les paddings, modifie simplement ces valeurs dans `layouts/backpack.lua`.
