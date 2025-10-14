# Nihui_iv Debugging Log - Problèmes d'affichage des items

## Date: 2025-01-XX

## Problème Initial
**Symptôme**: Impossible de cliquer sur les consommables depuis l'inventaire - erreur de taint: "Nihui_iv a été bloqué à cause d'une action qui n'est utilisable que par l'IU de Blizzard"

**Objectifs secondaires identifiés**:
- Ajouter l'affichage du niveau d'item (ilvl) sous les items
- Ajouter la flèche d'upgrade pour les items meilleurs que l'équipé

## État Actuel du Problème
**Symptôme principal**: Seulement 9 items s'affichent au lieu de 174 (96 pleins + 78 vides)

**Logs actuels montrent**:
```
Total slots: 174, Items: 96, Empty: 78
DEBUG: GetBackpackItems returned 174 items
DEBUG: Total items to display: 174
DEBUG: CreateGrid: Found 174 items to sort
DEBUG: CreateGrid: Sorted 174 items
DEBUG: CreateGrid: Creating slot 1 bagID: 0 slotID: 1
DEBUG: CreateGrid: Slot created, button: true
```

**Mais**: Les 3 premiers items dans les logs montrent `isEmpty: true` et `name: empty`, ce qui suggère un problème de récupération des données.

---

## Tentatives et Échecs

### 1. ❌ Suppression du Tooltip Handling Manuel (ÉCHEC PARTIEL)
**Fichier**: `components/slots.lua` lignes 38-50

**Ce qui a été fait**:
- Supprimé tout le code de tooltip manuel (`OnEnter`, `OnLeave`, `GameTooltip:SetBagItem()`)
- Laissé `ContainerFrameItemButtonTemplate` gérer les tooltips automatiquement
- Commentaire ajouté: "NO TOOLTIP HANDLING! ContainerFrameItemButtonTemplate does this automatically."

**Résultat**:
- ✅ Devrait résoudre le taint théoriquement
- ❌ Impossible de tester car les items ne s'affichent pas
- ⚠️ À re-tester une fois l'affichage fonctionnel

**Code critique**:
```lua
-- NO TOOLTIP HANDLING! ContainerFrameItemButtonTemplate does this automatically.
-- Any manual tooltip handling causes taint with UseContainerItem().
```

---

### 2. ❌ Ajout Item Level et Upgrade Arrow (NON TESTÉ)
**Fichiers**:
- `components/slots.lua` lignes 38-41 (ilvlText creation)
- `components/slots.lua` lignes 117-134 (ilvl display logic)
- `components/slots.lua` lignes 273-336 (UpdateUpgradeIcon function)
- `components/items.lua` lignes 79-87 (currentItemLevel retrieval)

**Ce qui a été fait**:
- Créé un FontString `ilvlText` pour afficher le niveau d'item
- Ajouté la logique pour afficher ilvl uniquement pour Armor et Weapons
- Implémenté `UpdateUpgradeIcon()` qui compare avec l'équipement du joueur
- Utilisé `ItemLocation:CreateFromBagAndSlot()` et `C_Item.GetCurrentItemLevel()`

**Résultat**:
- ❌ Code ajouté mais non testé car les items ne s'affichent pas
- ⚠️ Le code pour récupérer currentItemLevel a été simplifié pour éviter le blocage

**Problème découvert**: `C_Item.GetCurrentItemLevel()` peut bloquer si pas en cache

---

### 3. ❌ Suppression OnUpdate Frame Hook (CORRECT MAIS INSUFFISANT)
**Fichier**: `components/bags.lua` lignes 176-208

**Ce qui a été fait**:
- Remplacé l'OnUpdate polling (60+ fois/seconde) par des hooks OnShow
- Éliminé le code qui touchait constamment les secure frames

**Résultat**:
- ✅ Correctement implémenté, devrait éliminer une source de taint
- ❌ N'a pas résolu le problème d'affichage des items
- ⚠️ Bonne pratique même si pas la cause du problème actuel

---

### 4. ❌ Simplification Item Data Retrieval (BLOQUAIT)
**Fichier**: `components/items.lua` lignes 72-91

**Tentatives successives**:

**Version 1** (BLOQUAIT):
```lua
local itemMixin = Item:CreateFromBagAndSlot(bagID, slotID)
local currentItemLevel = C_Item.GetCurrentItemLevel(itemLocation)
```
- ❌ Bloquait complètement, items ne se chargeaient pas

**Version 2** (ACTUELLE):
```lua
local currentItemLevel = itemLevel or 0
-- Évite tous les appels bloquants
```
- ✅ Ne bloque plus
- ❌ Ne récupère pas le bon currentItemLevel (toujours 0)

**Résultat**: Les appels à `Item:CreateFromBagAndSlot()` et `C_Item.GetCurrentItemLevel()` sont **BLOQUANTS** et ne doivent PAS être utilisés de manière synchrone.

---

### 5. ❌ Tentative Système de Grilles Complexe (ABANDONNÉ)
**Fichier**: `layouts/backpack.lua` lignes 540-583 (version précédente)

**Ce qui a été tenté**:
- Système de grilles par catégorie avec `ns.Components.Grid`
- Headers de catégorie
- Grilles imbriquées pour chaque catégorie

**Problème découvert**:
```lua
DEBUG: Category grid drawn: 488,000004577637 x 78,000007629395
```
- Les dimensions calculées étaient **ÉNORMES** (des millions de pixels)
- `GetWidth()` et `GetHeight()` retournaient des valeurs invalides

**Résultat**:
- ❌ Système trop complexe, dimensions invalides
- ✅ Simplifié pour utiliser `ns.Components.Slots.CreateGrid()` directement

---

### 6. ❌ Fix Dimensions Grid Layout (PARTIEL)
**Fichier**: `components/grid.lua` lignes 155-220

**Ce qui a été fait**:
- Ajout de vérifications de sécurité sur `GetWidth()` et `GetHeight()`
- Fallback à 37x37 si dimensions invalides (> 10000 ou <= 0)

**Code ajouté**:
```lua
-- Safety check: if dimensions are invalid, use defaults
if not cellWidth or cellWidth <= 0 or cellWidth > 10000 then
    cellWidth = 37 -- Default item button size
end
if not cellHeight or cellHeight <= 0 or cellHeight > 10000 then
    cellHeight = 37 -- Default item button size
end
```

**Résultat**:
- ✅ Protège contre les dimensions invalides
- ❌ N'a pas résolu le problème d'affichage (le système de grille complexe a été abandonné)

---

### 7. ❌ Assurer Taille des Slots (CORRECT MAIS INSUFFISANT)
**Fichier**: `components/slots.lua` ligne 58

**Ce qui a été fait**:
```lua
-- IMPORTANT: Ensure size is always 37x37 (in case it was changed)
slot:SetSize(37, 37)
```

**Résultat**:
- ✅ Garantit que les slots ont toujours la bonne taille
- ❌ N'a pas résolu le problème d'affichage

---

### 8. ❌ Simplification Totale - CreateGrid Direct (ACTUEL)
**Fichier**: `layouts/backpack.lua` lignes 517-550

**Ce qui a été fait**:
- Supprimé tout le système de grilles par catégorie
- Appelé directement `ns.Components.Slots.CreateGrid(scrollChild, items, 8, 4)`
- Désactivé le stacking pour voir tous les items

**Code actuel**:
```lua
-- DON'T apply stacking for now - show all items
-- items = ns.Components.Stacking.FilterStackedItems(items)

local allSlots = ns.Components.Slots.CreateGrid(scrollChild, items, 8, 4)
```

**Résultat**:
- ✅ Les logs montrent que 174 slots sont trouvés et triés
- ❌ Seulement 9 items s'affichent visuellement
- ⚠️ Les 3 premiers items dans les logs ont tous `isEmpty: true` et `name: empty`

---

### 9. ❌ Tentative Async Item Loading (EN COURS)
**Fichiers**:
- `components/items.lua` lignes 76-79 (RequestLoadItemDataByID)
- `layouts/backpack.lua` lignes 615-630 (GET_ITEM_INFO_RECEIVED event - DÉSACTIVÉ)

**Ce qui a été tenté**:
```lua
-- If item info is not cached, request it
if not itemName then
    C_Item.RequestLoadItemDataByID(itemID)
end
```

**Événement GET_ITEM_INFO_RECEIVED**:
- Implémenté pour rafraîchir quand les items sont chargés
- **DÉSACTIVÉ** car causait 3 refreshes successifs en boucle

**Résultat**:
- ❌ Causait des refreshes multiples (visible dans les logs)
- ❌ N'a pas résolu le problème d'affichage
- ⚠️ À ré-activer plus tard avec un meilleur debouncing

---

### 10. ✅ Utilisation ContainerInfo comme Source Primaire (ACTUEL)
**Fichier**: `components/items.lua` lignes 98-128

**Ce qui a été fait**:
```lua
-- CRITICAL: Use containerInfo as primary source since it's always available
itemTexture = containerInfo.iconFileID,  -- ALWAYS use containerInfo for texture
currentItemCount = containerInfo.stackCount or 1,  -- ALWAYS use containerInfo
```

**Résultat**:
- ✅ `containerInfo` est **toujours disponible** (synchrone)
- ✅ `iconFileID` devrait donner les textures d'items
- ❌ **MAIS** les logs montrent toujours `isEmpty: true` pour les 3 premiers items

---

## Problèmes Identifiés Non Résolus

### Problème #1: Items Marqués comme Vides
**Logs montrent**:
```
DEBUG: Item key: 5_25 isEmpty: true name: empty
DEBUG: Item key: 3_25 isEmpty: true name: empty
DEBUG: Item key: 4_25 isEmpty: true name: empty
```

**Questions**:
- Pourquoi `GetBackpackItems()` retourne des items avec `isEmpty: true` ?
- Est-ce que `C_Container.GetContainerItemID()` retourne `nil` pour ces slots ?
- Est-ce que les données de `containerInfo` sont valides ?

**À investiguer**:
```lua
-- Dans items.lua ligne 34
local itemID = C_Container.GetContainerItemID(bagID, slotID)
if itemID then
    -- Item exists
else
    -- Empty slot - mais pourquoi tous les slots sont vides ?
end
```

---

### Problème #2: Seuls 9 Items Visibles
**Symptôme**: 174 slots créés selon les logs, mais seulement 9 affichés à l'écran

**Hypothèses**:
1. **Hypothèse A**: Les items sont positionnés hors écran (trop bas, mauvais offset Y)
2. **Hypothèse B**: Les items sont superposés au même endroit
3. **Hypothèse C**: Les items n'ont pas de texture donc invisibles (mais devrait voir les bordures)
4. **Hypothèse D**: Le `scrollChild` a une taille incorrecte qui cache les items
5. **Hypothèse E**: Les items sont créés mais pas affichés (`Show()` pas appelé)

**Ce qui contredit certaines hypothèses**:
- `UpdateSlot()` appelle `slot:Show()` et `button:Show()` (lignes 173-174)
- Les positions sont calculées avec `col * (37 + spacing)` et `-row * (37 + spacing)` (lignes 263-264)
- Le `scrollChild` a sa taille mise à jour (ligne 537)

---

### Problème #3: Timing Asynchrone
**Observation utilisateur**: "parfois le log debug apparait avant que la liste des items se fasse, problème d'ordre d'execution"

**Analyse**:
- WoW charge les données des items de manière asynchrone
- `C_Item.GetItemInfo()` peut retourner `nil` si l'item n'est pas en cache
- Les événements `BAG_UPDATE_DELAYED` et `GET_ITEM_INFO_RECEIVED` arrivent après

**Tentatives**:
- ✅ Ajouté `C_Timer.After(0.1, refresh)` - mais causait des refreshes multiples
- ❌ Event `GET_ITEM_INFO_RECEIVED` - causait 3+ refreshes en boucle
- ⚠️ Actuellement désactivés pour éviter les boucles

---

## Debug Logs Utiles

### Commande pour afficher les erreurs Lua
```
/console scriptErrors 1
```

### Logs Typiques Actuels
```
Total slots: 174, Items: 96, Empty: 78
DEBUG: GetBackpackItems returned 174 items
DEBUG: Item key: 5_25 isEmpty: true name: empty
DEBUG: Item key: 3_25 isEmpty: true name: empty
DEBUG: Item key: 4_25 isEmpty: true name: empty
DEBUG: Total items to display: 174
DEBUG: CreateGrid: Found 174 items to sort
DEBUG: CreateGrid: Sorted 174 items
DEBUG: CreateGrid: Creating slot 1 bagID: 0 slotID: 1
DEBUG: CreateGrid: Slot created, button: true
DEBUG: CreateGrid: Creating slot 2 bagID: 0 slotID: 2
DEBUG: CreateGrid: Slot created, button: true
DEBUG: CreateGrid: Creating slot 3 bagID: 0 slotID: 3
DEBUG: CreateGrid: Slot created, button: true
```

**Note**: Les logs s'arrêtent après les 3 premiers slots (limités par `if i <= 3`)

---

## Comparaison avec BetterBags

### Comment BetterBags Fonctionne
**Fichier source**: `BetterBags/frames/bag.lua`

**Architecture**:
1. **Views System**: Utilise un système de "Views" (Section Grid, Bag View)
2. **Render Pipeline**: `bag:Draw() -> view:Render() -> itemFrame:Create()`
3. **Item Pool**: Pré-crée 700 frames pour éviter le taint en combat
4. **Events**: Écoute `GET_ITEM_INFO_RECEIVED` avec debouncing
5. **Context System**: Utilise un système de "Context" pour passer les données

**Différences Clés**:
- ❌ Notre système ne pré-crée pas de pool de frames
- ❌ Pas de système de Views
- ❌ Pas de Context system
- ✅ Mais nous utilisons le même `ContainerFrameItemButtonTemplate`
- ✅ Notre structure de base est similaire (parent Button + ItemButton enfant)

---

## Pistes à Explorer Demain

### Piste #1: Vérifier GetBackpackItems()
**Action**: Ajouter des logs détaillés dans `GetAllItems()` pour voir ce que retourne réellement `C_Container.GetContainerItemID()`

**Code à ajouter** dans `components/items.lua` ligne 31:
```lua
for slotID = 1, numSlots do
    local itemID = C_Container.GetContainerItemID(bagID, slotID)
    local slotKey = bagID .. "_" .. slotID

    print("DEBUG GetAllItems: bag", bagID, "slot", slotID, "itemID:", itemID)

    if itemID then
        -- ...
    end
end
```

---

### Piste #2: Vérifier Positionnement des Slots
**Action**: Logger les positions X/Y de chaque slot créé

**Code à ajouter** dans `components/slots.lua` ligne 266:
```lua
button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

if i <= 10 then
    print("DEBUG Position: slot", i, "x:", x, "y:", y, "visible:", button:IsShown())
end
```

---

### Piste #3: Vérifier ScrollChild et Clipping
**Action**: Vérifier que le scrollChild et contentFrame n'ont pas de problèmes de clipping

**Code à ajouter** dans `layouts/backpack.lua` après ligne 537:
```lua
scrollChild:SetSize(math.max(contentWidth, 8 * 41), math.max(100, gridHeight + 20))

print("DEBUG ScrollChild:")
print("  Size:", scrollChild:GetWidth(), "x", scrollChild:GetHeight())
print("  Visible:", scrollChild:IsShown())
print("  Parent:", scrollChild:GetParent() and scrollChild:GetParent():GetName())
print("  Strata:", scrollChild:GetFrameStrata())
print("  Level:", scrollChild:GetFrameLevel())
```

---

### Piste #4: Test Minimal - Afficher UN Seul Item
**Action**: Simplifier au maximum pour tester avec 1 seul item hardcodé

**Code de test** à mettre dans `layouts/backpack.lua`:
```lua
-- TEST: Create only ONE slot manually
local testItemData = {
    bagID = 0,
    slotID = 1,
    slotKey = "0_1",
    isEmpty = false,
    itemTexture = 134400, -- Hardcoded texture ID
    currentItemCount = 1,
    itemQuality = 3,
}

local testSlot = ns.Components.Slots.CreateSlot(scrollChild, testItemData)
testSlot:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 50, -50)
testSlot:SetSize(37, 37)
testSlot:Show()
testSlot.itemButton:Show()

print("TEST SLOT created at 50, -50")
print("  Visible:", testSlot:IsShown())
print("  Button visible:", testSlot.itemButton:IsShown())
print("  Texture:", testSlot.itemButton:GetNormalTexture())
```

---

### Piste #5: Copier Exactement BetterBags Item Creation
**Action**: Au lieu de réinventer, copier **exactement** le code de BetterBags pour créer un ItemButton

**Référence**: `BetterBags/frames/item.lua` lignes 683-728 (fonction `_DoCreate`)

**Différences à noter**:
- BetterBags crée le parent comme `CreateFrame("Button")` sans nom ✅ (nous aussi)
- BetterBags utilise `ContainerFrameItemButtonTemplate` ✅ (nous aussi)
- BetterBags ne définit **AUCUN** script de tooltip ✅ (nous non plus maintenant)
- BetterBags utilise `HookScript` pour les textures Pushed/Normal ❌ (nous ne faisons pas ça)

---

## Fichiers Modifiés (État Actuel)

### components/slots.lua
**Lignes critiques**:
- 26-27: Création parent frame 37x37
- 30-32: Création ItemButton avec template
- 38-41: Création ilvlText (non testé)
- 44-46: Stockage références
- 48-49: Commentaire NO TOOLTIP
- 58: SetSize(37, 37) pour assurer taille
- 72: Appel UpdateSlot
- 100-175: UpdateSlot avec ilvl et upgrade logic
- 227-287: CreateGrid avec logs debug
- 273-336: UpdateUpgradeIcon (non testé)

### components/items.lua
**Lignes critiques**:
- 73-79: GetItemInfo avec RequestLoadItemDataByID
- 98-128: Return structure utilisant containerInfo comme primaire

### layouts/backpack.lua
**Lignes critiques**:
- 495-549: RefreshItems simplifié avec CreateGrid direct
- 505: Stacking désactivé
- 517-549: Logs debug et CreateGrid
- 553-567: Show() simple sans délais
- 615-630: GET_ITEM_INFO_RECEIVED désactivé

### components/bags.lua
**Lignes critiques**:
- 176-208: OnShow hooks au lieu d'OnUpdate

---

## Conclusion Temporaire

**Ce qui fonctionne**:
- ✅ Récupération des items (174 trouvés)
- ✅ Tri des items
- ✅ Création des slots (174 créés selon logs)
- ✅ Pas de taint apparent dans le code actuel

**Ce qui ne fonctionne PAS**:
- ❌ Affichage visuel (9 items au lieu de 174)
- ❌ Les 3 premiers items loggés sont marqués `isEmpty: true`
- ❌ Click droit sur consommables (non testé car items pas affichés)
- ❌ Item level display (non testé)
- ❌ Upgrade arrows (non testé)

**Hypothèse principale**:
Le problème semble être que `GetBackpackItems()` retourne des items avec `isEmpty: true` alors qu'il devrait retourner des items avec des données. Il faut investiguer **pourquoi** `C_Container.GetContainerItemID()` retourne `nil` ou pourquoi la logique marque les items comme vides.

**Prochaine étape critique**:
Ajouter des logs **DANS** `GetAllItems()` (components/items.lua ligne 26-50) pour voir ce que retournent réellement les API de WoW pour chaque slot.

---

## Notes Importantes

### Sur le Taint
- Le taint vient de toucher les secure frames ou d'appeler `UseContainerItem()` depuis du code tainté
- BetterBags évite le taint en:
  1. Ne touchant JAMAIS les scripts de l'ItemButton après création
  2. Utilisant HookScript au lieu de SetScript
  3. Pré-créant 700 frames avant le combat
  4. N'appelant JAMAIS de fonctions secure depuis des callbacks

### Sur l'API de WoW
- `C_Container.GetContainerItemInfo()` est **synchrone** et fiable ✅
- `C_Item.GetItemInfo()` peut retourner `nil` si pas en cache ⚠️
- `Item:CreateFromBagAndSlot()` est **bloquant** ❌
- `C_Item.GetCurrentItemLevel()` peut être **bloquant** ❌
- `containerInfo.iconFileID` est **toujours disponible** ✅

### Sur le Debugging
- Activer les erreurs Lua: `/console scriptErrors 1`
- Les logs `print()` apparaissent dans la console de chat
- Utiliser `/reload` pour recharger les fichiers Lua
- Parfois besoin de fermer/rouvrir le sac après `/reload`

---

**Fin du rapport - Session à reprendre demain**
