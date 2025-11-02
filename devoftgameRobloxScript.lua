-- services
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- references
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local camera = Workspace.CurrentCamera

-- disable default Roblox hotbar
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- GUI references
local CustomInventoryGUI = script.Parent
local hotBar = CustomInventoryGUI.hotBar
local Inventory = CustomInventoryGUI.Inventory
local toolButtonTemplate = script.toolButton

-- inventory handler
local inventoryHandler = require(script.SETTINGS)

------------------------
-- UTILITY FUNCTIONS
------------------------

local function getToolEquipped()
	local character = player.Character
	if character then
		return character:FindFirstChildOfClass("Tool")
	end
	return nil
end

------------------------
-- HOTBAR LAYOUT
------------------------

-- destroy grid if exists
local grid = hotBar:FindFirstChildOfClass("UIGridLayout")
if grid then grid:Destroy() end

-- horizontal layout
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = hotBar

hotBar.AnchorPoint = Vector2.new(0.5,1)
hotBar.Position = UDim2.fromScale(0.5,0.95)
hotBar.Size = UDim2.new(0,550,0,60)

------------------------
-- HOTBAR FUNCTIONS
------------------------

local function createHotbarSlot(index)
	if hotBar:FindFirstChild(index) then return end
	local frame = toolButtonTemplate:Clone()
	frame.toolName.Text = ""
	frame.toolAmount.Text = ""
	frame.toolNumber.Text = index
	frame.Name = index
	frame.Size = UDim2.new(0,50,0,50)
	frame.LayoutOrder = index
	frame.Parent = hotBar

	-- click to equip tool
	frame.MouseButton1Click:Connect(function()
		local toolObject = inventoryHandler.OBJECTS.HotBar[index]
		if toolObject then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:EquipTool(toolObject.Tool)
			end
		end
	end)

	-- drag and drop
	local dragging = false
	local dragOffset
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			local mousePos = UserInputService:GetMouseLocation()
			dragOffset = mousePos - frame.AbsolutePosition
		end
	end)

	frame.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mousePos = UserInputService:GetMouseLocation()
			frame.Position = UDim2.fromOffset(mousePos.X - dragOffset.X, mousePos.Y - dragOffset.Y)
		end
	end)

	frame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			frame.Position = UDim2.fromScale((index-1)/inventoryHandler.slotAmount,0)
			for i = 1, inventoryHandler.slotAmount do
				if i ~= index then
					local target = hotBar:FindFirstChild(i)
					if target and (frame.AbsolutePosition - target.AbsolutePosition).Magnitude < 50 then
						local tmp = inventoryHandler.OBJECTS.HotBar[i]
						inventoryHandler.OBJECTS.HotBar[i] = inventoryHandler.OBJECTS.HotBar[index]
						inventoryHandler.OBJECTS.HotBar[index] = tmp
						break
					end
				end
			end
		end
	end)
end

local function showSlots()
	for i = 1, inventoryHandler.slotAmount do
		createHotbarSlot(i)
		local toolObject = inventoryHandler.OBJECTS.HotBar[i]
		local frame = hotBar:FindFirstChild(i)
		if frame then
			if toolObject then
				frame.toolName.Text = toolObject.Tool.Name
				frame.toolAmount.Text = toolObject.Amount or ""
			else
				frame.toolName.Text = ""
				frame.toolAmount.Text = ""
			end
		end
	end
end

local function removeEmptySlots()
	for i = 1, inventoryHandler.slotAmount do
		local toolObject = inventoryHandler.OBJECTS.HotBar[i]
		if not toolObject then
			local frame = hotBar:FindFirstChild(i)
			if frame then frame.toolName.Text = ""; frame.toolAmount.Text = "" end
		end
	end
end

------------------------
-- INVENTORY FUNCTIONS
------------------------

local function manageInventory(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Inventory.Visible = not Inventory.Visible
		local visible = Inventory.Visible
		inventoryHandler:removeCurrentDescription()
		if visible then
			showSlots()
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.5)
			CustomInventoryGUI.openButton.info.Text = "(') close inventory"
		else
			if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
				removeEmptySlots()
			end
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.909)
			CustomInventoryGUI.openButton.info.Text = "(') open inventory"
		end
	end
end

local function searchTool()
	inventoryHandler:searchTool()
end

local function newTool(tool)
	if tool and tool:IsA("Tool") then
		inventoryHandler:newTool(tool)
	end
end

local function reloadInventory(character)
	inventoryHandler.currentlyEquipped = nil
	backpack = player:WaitForChild("Backpack")

	for _, tool in pairs(backpack:GetChildren()) do
		newTool(tool)
	end

	if character then
		for _, tool in pairs(character:GetChildren()) do
			newTool(tool)
		end
	end

	backpack.ChildAdded:Connect(newTool)
	if character then
		character.ChildAdded:Connect(newTool)
	end
end

------------------------
-- HUD UPDATE
------------------------

local function updateHudPosition()
	local slotSize = UDim2.fromOffset(hotBar.AbsoluteSize.Y,hotBar.AbsoluteSize.Y)
	Inventory.Frame.Grid.CellSize = slotSize
	showSlots()
end

------------------------
-- INITIAL SETUP
------------------------

updateHudPosition()
reloadInventory(player.Character or player.CharacterAdded:Wait())

camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateHudPosition)
player.CharacterAdded:Connect(reloadInventory)
Inventory.SearchBox:GetPropertyChangedSignal("Text"):Connect(searchTool)

if inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
	showSlots()
end

if inventoryHandler.SETTINGS.INVENTORY_KEYBIND then
	ContextActionService:BindAction("manageInventory",manageInventory,false,inventoryHandler.SETTINGS.INVENTORY_KEYBIND)
end

if inventoryHandler.SETTINGS.OPEN_BUTTON then
	CustomInventoryGUI.openButton.MouseButton1Down:Connect(function()
		Inventory.Visible = not Inventory.Visible
		local visible = Inventory.Visible
		inventoryHandler:removeCurrentDescription()
		if visible then
			showSlots()
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.5)
			CustomInventoryGUI.openButton.info.Text = "(') close inventory"
		else
			if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
				removeEmptySlots()
			end
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.909)
			CustomInventoryGUI.openButton.info.Text = "(') open inventory"
		end
	end)
else
	CustomInventoryGUI.openButton.Visible = false
end

------------------------
-- MOUSE WHEEL SCROLL
------------------------

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and inventoryHandler.SETTINGS.SCROLL_HOTBAR_WITH_WHEEL then
		local direction = input.Position.Z
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local toolEquipped = getToolEquipped()
		local pos = inventoryHandler:getToolPosition(toolEquipped) or 0

		if humanoid then
			if direction < 0 then
				for i = pos+direction,1,1 do
					local toolObj = inventoryHandler.OBJECTS.HotBar[i]
					if toolObj then
						humanoid:EquipTool(toolObj.Tool)
						break
					end
				end
			else
				for i = pos+direction,inventoryHandler.slotAmount,1 do
					local toolObj = inventoryHandler.OBJECTS.HotBar[i]
					if toolObj then
						humanoid:EquipTool(toolObj.Tool)
						break
					end
				end
			end
		end
	end
end)

------------------------
-- END OF SCRIPT
------------------------
