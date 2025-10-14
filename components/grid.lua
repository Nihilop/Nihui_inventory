-- components/grid.lua - Dynamic layout grid system (pure logic + minimal UI)
-- Simplified from BetterBags - handles grid layout and positioning of cells
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Grid = {}

-- Get constants
local const = ns.Components.Constants.Get()

-- Grid prototype
local GridProto = {}

-- Create a new grid
-- @param parent - Parent frame
-- @param spacing - Spacing between cells (default: 4)
-- @return grid - Grid object
function ns.Components.Grid.Create(parent, spacing)
    local grid = setmetatable({}, {__index = GridProto})

    -- Create container frame
    grid.frame = CreateFrame("Frame", nil, parent)
    grid.frame:SetSize(100, 100)

    -- Cell storage
    grid.cells = {} -- Array of cells
    grid.idToCell = {} -- {id = cell}
    grid.cellToID = {} -- {cell = id}

    -- Layout settings
    grid.spacing = spacing or 4
    grid.maxWidthPerRow = 400 -- Default max width
    grid.columns = 1 -- Default to single column

    return grid
end

-- Show grid
function GridProto:Show()
    self.frame:Show()
end

-- Hide grid
function GridProto:Hide()
    self.frame:Hide()
end

-- Get frame
function GridProto:GetFrame()
    return self.frame
end

-- Set maximum width per row (for wrapping)
-- @param width - Maximum width before wrapping
function GridProto:SetMaxWidthPerRow(width)
    self.maxWidthPerRow = width
end

-- Set spacing between cells
-- @param spacing - Spacing in pixels
function GridProto:SetSpacing(spacing)
    self.spacing = spacing
end

-- Set number of columns
-- @param columns - Number of columns
function GridProto:SetColumns(columns)
    self.columns = columns or 1
end

-- Add cell to grid
-- @param id - Unique ID for cell
-- @param cell - Cell object (must have .frame property)
function GridProto:AddCell(id, cell)
    assert(id, "Cell ID is required")
    assert(cell, "Cell is required")
    assert(cell.frame, "Cell must have a frame property")

    -- Check if already added
    if self.idToCell[id] then return end

    -- Add to grid
    table.insert(self.cells, cell)
    self.idToCell[id] = cell
    self.cellToID[cell] = id

    -- Set parent
    cell.frame:SetParent(self.frame)
end

-- Remove cell from grid
-- @param id - Cell ID
-- @return cell - Removed cell or nil
function GridProto:RemoveCell(id)
    assert(id, "Cell ID is required")

    local cell = self.idToCell[id]
    if not cell then return nil end

    -- Find and remove from array
    for i, c in ipairs(self.cells) do
        if c == cell then
            table.remove(self.cells, i)
            break
        end
    end

    -- Remove from maps
    self.idToCell[id] = nil
    self.cellToID[cell] = nil

    -- Hide cell
    cell.frame:Hide()
    cell.frame:ClearAllPoints()

    return cell
end

-- Get cell by ID
-- @param id - Cell ID
-- @return cell - Cell or nil
function GridProto:GetCell(id)
    return self.idToCell[id]
end

-- Get all cells
-- @return cells - Table {id = cell}
function GridProto:GetAllCells()
    return self.idToCell
end

-- Sort cells using custom function
-- @param sortFunc - Function(cellA, cellB) -> boolean
function GridProto:Sort(sortFunc)
    if type(sortFunc) ~= "function" then
        sortFunc = function() return false end
    end

    table.sort(self.cells, sortFunc)
end

-- Clear all cells (but don't release them)
function GridProto:Clear()
    wipe(self.cells)
    wipe(self.idToCell)
    wipe(self.cellToID)
end

-- Layout cells in a single column with row wrapping
-- @param cells - Array of cells
-- @param maxWidth - Max width per row
-- @param startX - Starting X offset
-- @param startY - Starting Y offset
-- @return width, height - Total dimensions
function GridProto:LayoutColumn(cells, maxWidth, startX, startY)
    if #cells == 0 then return 0, 0 end

    local totalWidth = 0
    local totalHeight = 0
    local rowWidth = 0
    local rowStart = cells[1]

    for i, cell in ipairs(cells) do
        cell.frame:ClearAllPoints()

        -- Get cell dimensions (with safety checks)
        local cellWidth = cell.frame:GetWidth()
        local cellHeight = cell.frame:GetHeight()

        -- Safety check: if dimensions are invalid, use defaults
        if not cellWidth or cellWidth <= 0 or cellWidth > 10000 then
            cellWidth = 48 -- Default item button size
        end
        if not cellHeight or cellHeight <= 0 or cellHeight > 10000 then
            cellHeight = 48 -- Default item button size
        end

        local relativeFrame = self.frame
        local relativePoint = "TOPLEFT"
        local offsetX = startX
        local offsetY = startY

        if i == 1 then
            -- First cell - anchor to frame
            rowWidth = cellWidth
            totalWidth = rowWidth
            totalHeight = cellHeight
            rowStart = cell
        else
            -- Check if we need to wrap to new row
            if rowWidth + self.spacing + cellWidth > maxWidth then
                -- New row - anchor to first cell of previous row
                relativeFrame = rowStart.frame
                relativePoint = "BOTTOMLEFT"
                offsetX = 0
                offsetY = -self.spacing

                rowWidth = cellWidth
                totalWidth = math.max(totalWidth, rowWidth)
                totalHeight = totalHeight + cellHeight + self.spacing
                rowStart = cell
            else
                -- Same row - anchor to previous cell
                local previousCell = cells[i - 1]
                relativeFrame = previousCell.frame
                relativePoint = "TOPRIGHT"
                offsetX = self.spacing
                offsetY = 0

                rowWidth = rowWidth + self.spacing + cellWidth
                totalWidth = math.max(totalWidth, rowWidth)
            end
        end

        cell.frame:SetPoint("TOPLEFT", relativeFrame, relativePoint, offsetX, offsetY)
        cell.frame:Show()
    end

    return totalWidth, totalHeight
end

-- Calculate cell distribution across columns
-- @param cells - Array of cells
-- @param numColumns - Number of columns
-- @return columns - Array of cell arrays
function GridProto:CalculateColumns(cells, numColumns)
    if numColumns <= 1 or #cells == 0 then
        return {cells}
    end

    -- Calculate total height needed
    local totalHeight = 0
    local rowWidth = 0

    for i, cell in ipairs(cells) do
        if i == 1 then
            totalHeight = cell.frame:GetHeight()
            rowWidth = cell.frame:GetWidth()
        else
            local cellWidth = cell.frame:GetWidth()

            if rowWidth + self.spacing + cellWidth > self.maxWidthPerRow then
                -- New row
                totalHeight = totalHeight + self.spacing + cell.frame:GetHeight()
                rowWidth = cellWidth
            else
                rowWidth = rowWidth + self.spacing + cellWidth
            end
        end
    end

    -- Distribute cells across columns by height
    local targetHeightPerColumn = math.ceil(totalHeight / numColumns)
    local columns = {}
    local currentColumn = 1
    local currentHeight = 0
    rowWidth = 0

    for i, cell in ipairs(cells) do
        if i == 1 then
            currentHeight = cell.frame:GetHeight()
            rowWidth = cell.frame:GetWidth()
        else
            local cellWidth = cell.frame:GetWidth()

            if rowWidth + self.spacing + cellWidth > self.maxWidthPerRow then
                -- New row
                if currentHeight + self.spacing + cell.frame:GetHeight() > targetHeightPerColumn and currentColumn < numColumns then
                    -- Move to next column
                    currentColumn = currentColumn + 1
                    currentHeight = 0
                else
                    currentHeight = currentHeight + self.spacing + cell.frame:GetHeight()
                end
                rowWidth = cellWidth
            else
                rowWidth = rowWidth + self.spacing + cellWidth
            end
        end

        -- Add to column
        if not columns[currentColumn] then
            columns[currentColumn] = {}
        end
        table.insert(columns[currentColumn], cell)
    end

    return columns
end

-- Draw the grid (layout all cells)
-- @param options - Table {header, footer, mask}
--   - header: Cell to show at top (optional)
--   - footer: Cell to show at bottom (optional)
--   - mask: Array of cells to hide (optional)
-- @return width, height - Total dimensions
function GridProto:Draw(options)
    options = options or {}

    -- Apply mask (hide specified cells)
    local visibleCells = {}
    for _, cell in ipairs(self.cells) do
        local masked = false
        if options.mask then
            for _, maskCell in ipairs(options.mask) do
                if cell == maskCell then
                    masked = true
                    break
                end
            end
        end

        if not masked then
            table.insert(visibleCells, cell)
        end
    end

    -- Layout header
    local totalWidth = 0
    local totalHeight = 0
    local currentY = 0

    if options.header then
        local headerWidth, headerHeight = self:LayoutColumn({options.header}, self.maxWidthPerRow * 2, 0, 0)
        totalWidth = math.max(totalWidth, headerWidth)
        totalHeight = headerHeight
        currentY = -headerHeight
    end

    -- Calculate columns
    local columns = self:CalculateColumns(visibleCells, self.columns)

    -- Layout each column
    local currentX = 0
    local maxColumnHeight = 0

    for _, column in ipairs(columns) do
        local columnWidth, columnHeight = self:LayoutColumn(column, self.maxWidthPerRow, currentX, currentY)
        currentX = currentX + columnWidth
        totalWidth = totalWidth + columnWidth
        maxColumnHeight = math.max(maxColumnHeight, columnHeight)
    end

    totalHeight = totalHeight + maxColumnHeight

    -- Layout footer
    if options.footer then
        local footerWidth, footerHeight = self:LayoutColumn({options.footer}, self.maxWidthPerRow * 2, 0, currentY - maxColumnHeight)
        totalWidth = math.max(totalWidth, footerWidth)
        totalHeight = totalHeight + footerHeight
    end

    -- Update frame size
    self.frame:SetSize(math.max(totalWidth, 10), math.max(totalHeight, 10))

    return totalWidth, totalHeight
end

-- Refresh grid (redraw with current settings)
function GridProto:Refresh()
    return self:Draw()
end

-- Create a simple scroll frame wrapper
-- @param parent - Parent frame
-- @param width - Width
-- @param height - Height
-- @return grid - Grid with scroll support
function ns.Components.Grid.CreateScrollable(parent, width, height)
    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width or 400, height or 600)

    -- Create scroll child
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width or 400, 100)
    scrollFrame:SetScrollChild(scrollChild)

    -- Create grid on scroll child
    local grid = ns.Components.Grid.Create(scrollChild)
    grid.scrollFrame = scrollFrame
    grid.scrollChild = scrollChild

    -- Override Draw to update scroll child size
    local originalDraw = grid.Draw
    grid.Draw = function(self, options)
        local w, h = originalDraw(self, options)
        self.scrollChild:SetSize(math.max(w, width or 400), math.max(h, 100))
        return w, h
    end

    return grid
end

-- Helper: Create a cell from a frame
-- @param frame - Frame to wrap
-- @return cell - Cell object
function ns.Components.Grid.CreateCell(frame)
    return {
        frame = frame
    }
end
