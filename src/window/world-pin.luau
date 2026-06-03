--!nonstrict
-- Window resize, 3D world-pin, and title-bar drag (split out of window.luau for Luau register limits).

local Config = require("../config")

type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }

return function(deps: any)
	local win = deps.win
	local gui = deps.gui
	local lib = deps.lib
	local dragHandle = deps.dragHandle
	local pinBtn = deps.pinBtn
	local tabListCont = deps.tabListCont
	local setChromeActive = deps.setChromeActive
	local moveTabHighlight = deps.moveTabHighlight
	local TAB_SIDEBAR_W = deps.TAB_SIDEBAR_W
	local corner = deps.corner
	local reg = deps.reg
	local regDynamic = deps.regDynamic
	local tween = deps.tween
	local playFeedback = deps.playFeedback
	local onInputChanged = deps.onInputChanged
	local onInputEnded = deps.onInputEnded
	local onRender = deps.onRender
	local isPrimaryInput = deps.isPrimaryInput
	local isMoveInput = deps.isMoveInput
	local isGrabInput = deps.isGrabInput
	local UserInputService = deps.UserInputService
	local Workspace = deps.Workspace
	local Players = deps.Players
	local GuiService = deps.GuiService
	local ContextActionService = deps.ContextActionService
	local RunService = deps.RunService
	local mouse = deps.mouse
	local INTRO_BRAND = deps.INTRO_BRAND
	local fontDisplay = deps.fontDisplay
	-- Accent highlights: only the hovered edge OR corner lights up (never the whole frame).
	local function glowBar(size: UDim2, pos: UDim2, anchor: Vector2): Frame
		local bar = Instance.new("Frame")
		bar.Size = size
		bar.Position = pos
		bar.AnchorPoint = anchor
		bar.BackgroundTransparency = 1
		bar.BorderSizePixel = 0
		bar.ZIndex = 60
		bar.Parent = win
		corner(bar, 999)
		reg(bar, "BackgroundColor3", "pri")
		return bar
	end

	local WIN_RADIUS = 16 -- must match corner(win, ...)
	local ARM = WIN_RADIUS -- edge highlights stop at the corner curve's tangent point
	local EDGE_DIM = 0.8 -- adjacent edges only glow at ~20% opacity when a corner is hovered
	-- Edge highlights span the edge minus the rounded corners.
	local topBar = glowBar(UDim2.new(1, -2 * ARM, 0, 3), UDim2.new(0, ARM, 0, 0), Vector2.new(0, 0))
	local bottomBar = glowBar(UDim2.new(1, -2 * ARM, 0, 3), UDim2.new(0, ARM, 1, 0), Vector2.new(0, 1))
	local leftBar = glowBar(UDim2.new(0, 3, 1, -2 * ARM), UDim2.new(0, 0, 0, ARM), Vector2.new(0, 0))
	local rightBar = glowBar(UDim2.new(0, 3, 1, -2 * ARM), UDim2.new(1, 0, 0, ARM), Vector2.new(1, 0))
	-- An edge hover lights its own bar fully.
	local glowTop = { { topBar, 0 } }
	local glowBottom = { { bottomBar, 0 } }
	local glowLeft = { { leftBar, 0 } }
	local glowRight = { { rightBar, 0 } }

	-- A curved 3px border segment hugging the window's rounded corner (accent ring carved by a
	-- background-coloured mask, clipped to just the corner quarter so it connects the two edges).
	local function makeCornerArc(ax: number, ay: number): Frame
		local clip = Instance.new("Frame")
		clip.Size = UDim2.fromOffset(WIN_RADIUS, WIN_RADIUS)
		clip.AnchorPoint = Vector2.new(ax, ay)
		clip.Position = UDim2.new(ax, 0, ay, 0)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.ZIndex = 60
		clip.Parent = win

		local d = 2 * WIN_RADIUS
		local accent = Instance.new("Frame")
		accent.Size = UDim2.fromOffset(d, d)
		accent.AnchorPoint = Vector2.new(ax, ay)
		accent.Position = UDim2.new(ax, 0, ay, 0)
		accent.BackgroundTransparency = 1
		accent.BorderSizePixel = 0
		accent.ZIndex = 60
		accent.Parent = clip
		corner(accent, WIN_RADIUS)
		reg(accent, "BackgroundColor3", "pri")

		local cover = Instance.new("Frame")
		cover.Size = UDim2.fromOffset(d, d)
		cover.AnchorPoint = Vector2.new(ax, ay)
		cover.Position = UDim2.new(ax, ax == 0 and 3 or -3, ay, ay == 0 and 3 or -3)
		cover.BorderSizePixel = 0
		cover.ZIndex = 61
		cover.Parent = clip
		corner(cover, WIN_RADIUS - 3)
		reg(cover, "BackgroundColor3", "bg")
		return accent
	end

	-- Corner hover: the curved corner border is the full accent tint, while the two adjacent
	-- edges only glow faintly (EDGE_DIM) so the corner itself reads as the focal point.
	local glowTL = { { makeCornerArc(0, 0), 0 }, { topBar, EDGE_DIM }, { leftBar, EDGE_DIM } }
	local glowTR = { { makeCornerArc(1, 0), 0 }, { topBar, EDGE_DIM }, { rightBar, EDGE_DIM } }
	local glowBL = { { makeCornerArc(0, 1), 0 }, { bottomBar, EDGE_DIM }, { leftBar, EDGE_DIM } }
	local glowBR = { { makeCornerArc(1, 1), 0 }, { bottomBar, EDGE_DIM }, { rightBar, EDGE_DIM } }

	-- Forward-declared so resize handlers (registered below) see the same locals as pin setup.
	local pinned = false
	local pinnedPixelW: number? = nil
	local pinnedPixelH: number? = nil
	local worldPanelRotation = CFrame.identity
	local WP = Config.WorldPin or {}
	local WORLD_PIXELS_PER_STUD = WP.PixelsPerStud or 512
	local pinViewDepth = 20
	local anchorPart: Part
	local keepUpright: AlignOrientation
	local applyUprightTarget: () -> ()

    local resizing = false
	local activeEdges: { [string]: boolean } = {}
	local activeGroup: { any } = {}

	local function setGlow(group: { any }, on: boolean)
		for _, entry in group do
			tween(entry[1], "BackgroundTransparency", on and entry[2] or 1, 0.15)
		end
	end

	-- The tab sidebar is a fixed width, so derive the window's minimum width from a
	-- minimum content-column width. This stops the right-hand tab content from
	-- collapsing into an unusably narrow strip when the window is resized down.
	local MIN_CONTENT_W = 200
	local minW, minH = TAB_SIDEBAR_W + MIN_CONTENT_W, 360
	local resStartPos: Vector2, resStartSize: Vector2, resStartOffset: Vector2
	local resStartPartCenter: Vector3, resStartPartSize: Vector3
	local resScaleX, resScaleY = 0, 0

	local function makeHandle(size: UDim2, pos: UDim2, anchor: Vector2, edges: { [string]: boolean }, cursor: string, group: { any }, name: string)
		local h = Instance.new("TextButton")
		h.Name = "Resize_" .. name
		h.Size = size
		h.Position = pos
		h.AnchorPoint = anchor
		h.BackgroundTransparency = 1
		h.Text = ""
		h.AutoButtonColor = false
		h.ZIndex = 200
		h.Parent = win

		h.MouseEnter:Connect(function()
			mouse.Icon = cursor
			if not resizing then
				setGlow(group, true)
			end
		end)
		h.MouseLeave:Connect(function()
			if not resizing then
				mouse.Icon = ""
				setGlow(group, false)
			end
		end)
		h.InputBegan:Connect(function(i)
			if isPrimaryInput(i) then
				resizing = true
				activeEdges = edges
				activeGroup = group
				resStartPos = UserInputService:GetMouseLocation()
				resStartSize = win.AbsoluteSize
				resStartOffset = Vector2.new(win.Position.X.Offset, win.Position.Y.Offset)
				resScaleX = win.Position.X.Scale
				resScaleY = win.Position.Y.Scale
				if pinned then
					win.Size = UDim2.fromScale(1, 1)
					win.Position = UDim2.fromOffset(0, 0)
					local pps = worldFace.PixelsPerStud
					resStartSize = Vector2.new(anchorPart.Size.X * pps, anchorPart.Size.Y * pps)
					keepUpright.Enabled = false
					anchorPart.Anchored = true
					anchorPart.AssemblyLinearVelocity = Vector3.zero
					anchorPart.AssemblyAngularVelocity = Vector3.zero
					resStartPartCenter = anchorPart.Position
					resStartPartSize = anchorPart.Size
				end
				mouse.Icon = cursor
				setGlow(group, true)
			end
		end)
		return h
	end

	local EDGE = 7
	local CORNER = 14
	-- Edges
	makeHandle(UDim2.new(1, -2 * CORNER, 0, EDGE), UDim2.new(0, CORNER, 0, 0), Vector2.new(0, 0), { top = true }, "rbxasset://SystemCursors/SizeNS", glowTop, "Top")
	makeHandle(UDim2.new(1, -2 * CORNER, 0, EDGE), UDim2.new(0, CORNER, 1, 0), Vector2.new(0, 1), { bottom = true }, "rbxasset://SystemCursors/SizeNS", glowBottom, "Bottom")
	makeHandle(UDim2.new(0, EDGE, 1, -2 * CORNER), UDim2.new(0, 0, 0, CORNER), Vector2.new(0, 0), { left = true }, "rbxasset://SystemCursors/SizeEW", glowLeft, "Left")
	makeHandle(UDim2.new(0, EDGE, 1, -2 * CORNER), UDim2.new(1, 0, 0, CORNER), Vector2.new(1, 0), { right = true }, "rbxasset://SystemCursors/SizeEW", glowRight, "Right")
	-- Corners
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), { top = true, left = true }, "rbxasset://SystemCursors/SizeNWSE", glowTL, "TL")
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), { top = true, right = true }, "rbxasset://SystemCursors/SizeNESW", glowTR, "TR")
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), { bottom = true, left = true }, "rbxasset://SystemCursors/SizeNESW", glowBL, "BL")
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(1, 0, 1, 0), Vector2.new(1, 1), { bottom = true, right = true }, "rbxasset://SystemCursors/SizeNWSE", glowBR, "BR")

	onInputChanged(function(i)
		if resizing and isMoveInput(i) then
			local loc = UserInputService:GetMouseLocation()
			local dx = loc.X - resStartPos.X
			local dy = loc.Y - resStartPos.Y
			local newW, newH = resStartSize.X, resStartSize.Y
			local offX, offY = resStartOffset.X, resStartOffset.Y
			if activeEdges.right then
				newW = resStartSize.X + dx
			end
			if activeEdges.bottom then
				newH = resStartSize.Y + dy
			end
			if activeEdges.left then
				newW = math.max(minW, resStartSize.X - dx)
				offX = resStartOffset.X + (resStartSize.X - newW)
			end
			if activeEdges.top then
				newH = math.max(minH, resStartSize.Y - dy)
				offY = resStartOffset.Y + (resStartSize.Y - newH)
			end
			newW = math.max(minW, newW)
			newH = math.max(minH, newH)

			if pinned then
				local pps = worldFace.PixelsPerStud
				local newWStud = newW / pps
				local newHStud = newH / pps
				local shift = Vector3.zero
				local widthDelta = newWStud - resStartPartSize.X
				local heightDelta = newHStud - resStartPartSize.Y
				if activeEdges.right and not activeEdges.left then
					shift -= worldPanelRotation.RightVector * widthDelta * 0.5
				elseif activeEdges.left and not activeEdges.right then
					shift += worldPanelRotation.RightVector * widthDelta * 0.5
				end
				if activeEdges.bottom and not activeEdges.top then
					shift -= worldPanelRotation.UpVector * heightDelta * 0.5
				elseif activeEdges.top and not activeEdges.bottom then
					shift += worldPanelRotation.UpVector * heightDelta * 0.5
				end
				anchorPart.Size = Vector3.new(newWStud, newHStud, resStartPartSize.Z)
				anchorPart.CFrame = CFrame.new(resStartPartCenter + shift) * worldPanelRotation
			else
				win.Size = UDim2.new(0, newW, 0, newH)
				win.Position = UDim2.new(resScaleX, offX, resScaleY, offY)
			end
		end
	end)
	onInputEnded(function(i)
		if isPrimaryInput(i) and resizing then
			resizing = false
			setGlow(activeGroup, false)
			mouse.Icon = ""
			if pinned then
				anchorPart.Anchored = false
				keepUpright.Enabled = true
				applyUprightTarget()
			end
		end
	end)

	--//============================================================\\--
	--||              PIN UI INTO THE 3D WORLD                    ||--
	--\\============================================================//--

	local savedScreenPos = win.Position
	local dragWorldOffset: Vector3? = nil
	local GRAB_DEPTH_STEP = 2

	local oldWorld = Workspace:FindFirstChild("Material3WorldUI")
	if oldWorld then
		oldWorld:Destroy()
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local oldFace = playerGui:FindFirstChild("Material3WorldFace")
	if oldFace then
		oldFace:Destroy()
	end
	local oldBack = playerGui:FindFirstChild("Material3WorldBack")
	if oldBack then
		oldBack:Destroy()
	end

	local worldRoot = Instance.new("Folder")
	worldRoot.Name = "Material3WorldUI"
	worldRoot.Parent = Workspace

	anchorPart = Instance.new("Part")
	anchorPart.Name = "UIAnchor"
	anchorPart.Size = Vector3.new(7.6, 10.4, 0.08)
	anchorPart.Transparency = 1
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CastShadow = false
	anchorPart.Parent = worldRoot

	local panelAtt = Instance.new("Attachment")
	panelAtt.Name = "PanelAttachment"
	panelAtt.Parent = anchorPart

	keepUpright = Instance.new("AlignOrientation")
	keepUpright.Name = "KeepUpright"
	keepUpright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	keepUpright.RigidityEnabled = true
	keepUpright.ReactionTorqueEnabled = true
	keepUpright.MaxTorque = math.huge
	keepUpright.Responsiveness = 200
	keepUpright.Attachment0 = panelAtt
	keepUpright.Enabled = false
	keepUpright.Parent = anchorPart

	local GRAB_MOVE_SPEED = 28
	local GRAB_YAW_LERP = 0.1

	local function uprightRotationAt(pos: Vector3, cam: Camera): CFrame
		local toCam = cam.CFrame.Position - pos
		local flat = Vector3.new(toCam.X, 0, toCam.Z)
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		end
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(0, 0, -1)
		end
		return CFrame.lookAt(pos, pos + flat.Unit, Vector3.yAxis).Rotation
	end

	applyUprightTarget = function()
		keepUpright.CFrame = CFrame.new(anchorPart.Position) * worldPanelRotation
	end

	local function enableWorldPhysics()
		anchorPart.Anchored = false
		anchorPart.CanCollide = true
		anchorPart.CustomPhysicalProperties = PhysicalProperties.new(0.75, 0.3, 0.4, 1, 1)
		keepUpright.Enabled = true
		applyUprightTarget()
	end

	local function disableWorldPhysics()
		keepUpright.Enabled = false
		anchorPart.Anchored = true
		anchorPart.CanCollide = false
		anchorPart.AssemblyLinearVelocity = Vector3.zero
		anchorPart.AssemblyAngularVelocity = Vector3.zero
	end

	-- SurfaceGui must live in PlayerGui with Adornee set for input to work in 3D.
	local worldFace = Instance.new("SurfaceGui")
	worldFace.Name = "Material3WorldFace"
	worldFace.ResetOnSpawn = false
	worldFace.Enabled = false
	worldFace.Active = true
	-- Keep AlwaysOnTop off: it would render the panel through walls and break
	-- click input (clicks hit whatever geometry is actually closest). Instead we
	-- stay at world depth and rely on LightInfluence = 0 plus a brightness boost
	-- so the panel reads as flat/unlit without the lighting tint.
	worldFace.AlwaysOnTop = false
	worldFace.Face = Enum.NormalId.Front
	worldFace.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	worldFace.PixelsPerStud = WORLD_PIXELS_PER_STUD
	worldFace.LightInfluence = 0
	worldFace.Brightness = 2
	worldFace.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	worldFace.Parent = playerGui

	local worldBack = Instance.new("SurfaceGui")
	worldBack.Name = "Material3WorldBack"
	worldBack.ResetOnSpawn = false
	worldBack.Enabled = false
	worldBack.Active = true
	worldBack.AlwaysOnTop = false
	worldBack.Face = Enum.NormalId.Back
	worldBack.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	worldBack.PixelsPerStud = WORLD_PIXELS_PER_STUD
	worldBack.LightInfluence = 0
	worldBack.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	worldBack.Parent = playerGui

	local backSurface = Instance.new("Frame")
	backSurface.Name = "BackSurface"
	backSurface.Size = UDim2.fromScale(1, 1)
	backSurface.BorderSizePixel = 0
	backSurface.ClipsDescendants = true
	backSurface.Parent = worldBack
	reg(backSurface, "BackgroundColor3", "bg")
	corner(backSurface, WIN_RADIUS)

	local backLogo = Instance.new("TextLabel")
	backLogo.Name = "DexUIBackLogo"
	backLogo.AnchorPoint = Vector2.new(0.5, 0.5)
	backLogo.Position = UDim2.fromScale(0.5, 0.5)
	backLogo.Size = UDim2.fromScale(0.72, 0.22)
	backLogo.BackgroundTransparency = 1
	backLogo.Text = INTRO_BRAND
	backLogo.TextScaled = true
	backLogo.FontFace = fontDisplay
	backLogo.ZIndex = 1
	backLogo.Parent = backSurface

	local backStroke = Instance.new("UIStroke")
	backStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	backStroke.Thickness = 3.5
	backStroke.Parent = backLogo

	regDynamic(function(palette: Palette, d: number)
		local borderColor = palette.pri:Lerp(Color3.new(0, 0, 0), 0.55)
		if d > 0 then
			tween(backLogo, "TextColor3", palette.pri, d)
			tween(backStroke, "Color", borderColor, d)
		else
			backLogo.TextColor3 = palette.pri
			backStroke.Color = borderColor
		end
	end)

	local backDragHandle = Instance.new("TextButton")
	backDragHandle.Name = "BackDragHandle"
	backDragHandle.Size = UDim2.fromScale(1, 1)
	backDragHandle.BackgroundTransparency = 1
	backDragHandle.Text = ""
	backDragHandle.AutoButtonColor = false
	backDragHandle.ZIndex = 2
	backDragHandle.Parent = backSurface

	local ZOOM_BLOCK_ACTION = "DexUIBlockCameraZoom"
	local cameraZoomBlocked = false

	local function sinkCameraZoom(_actionName: string, _inputState: Enum.UserInputState, _inputObject: InputObject)
		return Enum.ContextActionResult.Sink
	end

	local function setCameraZoomBlocked(block: boolean)
		if block == cameraZoomBlocked then
			return
		end
		cameraZoomBlocked = block
		if block then
			ContextActionService:BindActionAtPriority(
				ZOOM_BLOCK_ACTION,
				sinkCameraZoom,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.UserInputType.MouseWheel
			)
		else
			ContextActionService:UnbindAction(ZOOM_BLOCK_ACTION)
		end
	end

	local worldRayParams = RaycastParams.new()
	worldRayParams.FilterType = Enum.RaycastFilterType.Exclude
	worldRayParams.FilterDescendantsInstances = { worldRoot }

	local function screenToUnitRay(sx: number, sy: number): Ray
		local cam = Workspace.CurrentCamera
		local inset = GuiService:GetGuiInset()
		local unitRay = cam:ScreenPointToRay(sx, sy + inset.Y)
		return Ray.new(unitRay.Origin, unitRay.Direction)
	end

	local function viewPointToWorld(sx: number, sy: number, depth: number): Vector3
		local ray = screenToUnitRay(sx, sy)
		return ray.Origin + ray.Direction * depth
	end

	local function studsSizeForScreenPixels(pixelW: number, pixelH: number, depth: number): (number, number)
		local cam = Workspace.CurrentCamera
		if not cam then
			return pixelW / WORLD_PIXELS_PER_STUD, pixelH / WORLD_PIXELS_PER_STUD
		end
		local vp = cam.ViewportSize
		if vp.X < 1 or vp.Y < 1 then
			return pixelW / WORLD_PIXELS_PER_STUD, pixelH / WORLD_PIXELS_PER_STUD
		end
		local vFov = math.rad(cam.FieldOfView)
		local hFov = 2 * math.atan(math.tan(vFov * 0.5) * (vp.X / vp.Y))
		local worldW = 2 * depth * math.tan(hFov * 0.5) * (pixelW / vp.X)
		local worldH = 2 * depth * math.tan(vFov * 0.5) * (pixelH / vp.Y)
		return math.max(0.5, worldW), math.max(0.5, worldH)
	end

	local function syncWorldPartSize(w: number?, h: number?)
		w = math.max(1, w or pinnedPixelW or win.AbsoluteSize.X)
		h = math.max(1, h or pinnedPixelH or win.AbsoluteSize.Y)
		if pinned then
			-- SurfaceGui layout can briefly report a tiny AbsoluteSize; ignore that feedback loop.
			if (w < minW or h < minH) and pinnedPixelW and pinnedPixelH then
				w, h = pinnedPixelW, pinnedPixelH
			elseif w >= minW and h >= minH then
				pinnedPixelW, pinnedPixelH = w, h
			end
			local worldW, worldH = studsSizeForScreenPixels(w, h, pinViewDepth)
			anchorPart.Size = Vector3.new(worldW, worldH, anchorPart.Size.Z)
			local pps = w / worldW
			worldFace.PixelsPerStud = pps
			worldBack.PixelsPerStud = pps
		else
			anchorPart.Size = Vector3.new(w / WORLD_PIXELS_PER_STUD, h / WORLD_PIXELS_PER_STUD, 0.08)
		end
	end

	local function setPartWorldCFrame(pos: Vector3)
		anchorPart.CFrame = CFrame.new(pos) * worldPanelRotation
	end

	local function mouseUnitRay(): Ray
		local loc = UserInputService:GetMouseLocation()
		return screenToUnitRay(loc.X, loc.Y)
	end

	local function rayCameraDepthPlane(depth: number): Vector3?
		local cam = Workspace.CurrentCamera
		if not cam then
			return nil
		end
		local look = cam.CFrame.LookVector
		local planePoint = cam.CFrame.Position + look * depth
		local ray = mouseUnitRay()
		local denom = ray.Direction:Dot(look)
		if math.abs(denom) < 1e-4 then
			return nil
		end
		local t = (planePoint - ray.Origin):Dot(look) / denom
		if t <= 0 then
			return nil
		end
		return ray.Origin + ray.Direction * t
	end

	local function rayToWorldPoint(): Vector3
		local ray = mouseUnitRay()
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 512, worldRayParams)
		if hit then
			return hit.Position + hit.Normal * (anchorPart.Size.Z / 2 + 0.02)
		end
		return ray.Origin + ray.Direction * pinViewDepth
	end

	local function setPinned(state: boolean)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end

		pinned = state
		setChromeActive(pinBtn, pinned)
		if pinned then
			savedScreenPos = win.Position
			local w = math.max(minW, win.AbsoluteSize.X)
			local h = math.max(minH, win.AbsoluteSize.Y)
			pinnedPixelW, pinnedPixelH = w, h

			-- Place on a fixed plane in front of the camera through the window center.
			local center = win.AbsolutePosition + win.AbsoluteSize / 2
			local worldPos = viewPointToWorld(center.X, center.Y, pinViewDepth)
			pinViewDepth = (worldPos - cam.CFrame.Position).Magnitude
			worldPanelRotation = uprightRotationAt(worldPos, cam)

			syncWorldPartSize(w, h)
			setPartWorldCFrame(worldPos)
			enableWorldPhysics()

			anchorPart.CanQuery = true
			worldFace.Adornee = anchorPart
			worldFace.Enabled = true
			worldBack.Adornee = anchorPart
			worldBack.Enabled = true
			win.Parent = worldFace
			win.Active = true
			win.AnchorPoint = Vector2.new(0, 0)
			win.Position = UDim2.fromOffset(0, 0)
			win.Size = UDim2.fromScale(1, 1)
			playFeedback("toggleOn")
		else
			disableWorldPhysics()
			worldFace.Adornee = nil
			worldFace.Enabled = false
			worldBack.Adornee = nil
			worldBack.Enabled = false
			anchorPart.CanQuery = false
			-- Restore screen size from saved pixel dims. Pinned parts are large in studs
			-- with low PPS; studSize * 512 would blow up the overlay (e.g. 11st → 5k px).
			local ppsPinned = worldFace.PixelsPerStud
			local w = pinnedPixelW
			local h = pinnedPixelH
			if not w or not h then
				w = math.floor(anchorPart.Size.X * ppsPinned + 0.5)
				h = math.floor(anchorPart.Size.Y * ppsPinned + 0.5)
			end
			w = math.clamp(math.max(minW, w), minW, math.max(minW, cam.ViewportSize.X))
			h = math.clamp(math.max(minH, h), minH, math.max(minH, cam.ViewportSize.Y))
			worldFace.PixelsPerStud = WORLD_PIXELS_PER_STUD
			worldBack.PixelsPerStud = WORLD_PIXELS_PER_STUD
			pinnedPixelW, pinnedPixelH = nil, nil
			local screenPos, onScreen = cam:WorldToViewportPoint(anchorPart.Position)
			win.Parent = gui
			win.AnchorPoint = Vector2.new(0, 0)
			win.Size = UDim2.fromOffset(w, h)
			if onScreen then
				win.Position = UDim2.new(
					0,
					screenPos.X - win.AbsoluteSize.X / 2,
					0,
					screenPos.Y - win.AbsoluteSize.Y / 2
				)
			else
				win.Position = savedScreenPos
			end
			playFeedback("toggleOff")
		end
	end

	pinBtn.MouseButton1Click:Connect(function()
		setPinned(not pinned)
	end)

	--//============================================================\\--
	--||                 DRAG FROM THE TITLE BAR                  ||--
	--\\============================================================//--

	tabListCont:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if lib.ActiveTabIndex > 0 and lib.Tabs[lib.ActiveTabIndex] then
			moveTabHighlight(lib.Tabs[lib.ActiveTabIndex].btn, 0)
		end
	end)

	win:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if pinned and not resizing then
			syncWorldPartSize()
		end
		if lib.ActiveTabIndex > 0 and lib.Tabs[lib.ActiveTabIndex] then
			moveTabHighlight(lib.Tabs[lib.ActiveTabIndex].btn, 0.15)
        end
    end)

	local dragging = false
	local dragInput: InputObject?, dragStart: Vector3, startPos: UDim2
	local activeGrabInput: Enum.UserInputType? = nil
	local grabPlaneDepth: number? = nil

	local function refreshGrabOffset()
		if grabPlaneDepth then
			local hit = rayCameraDepthPlane(grabPlaneDepth)
			if hit then
				dragWorldOffset = anchorPart.Position - hit
			end
		end
	end

	local function beginGrab(input: InputObject)
		dragging = true
		dragInput = input
		dragStart = input.Position
		startPos = win.Position
		activeGrabInput = input.UserInputType
		if pinned then
			anchorPart.Anchored = false
			anchorPart.CanCollide = true
			local cam = Workspace.CurrentCamera
			if cam then
				grabPlaneDepth = (anchorPart.Position - cam.CFrame.Position):Dot(cam.CFrame.LookVector)
				local hit = rayCameraDepthPlane(grabPlaneDepth)
				dragWorldOffset = if hit then anchorPart.Position - hit else Vector3.zero
			end
			setCameraZoomBlocked(true)
		else
			dragWorldOffset = nil
			grabPlaneDepth = nil
		end
	end

	local function endGrab(input: InputObject)
		if not activeGrabInput or input.UserInputType ~= activeGrabInput then
			return
		end
		if pinned and dragging then
			anchorPart.AssemblyLinearVelocity = Vector3.zero
			anchorPart.AssemblyAngularVelocity = Vector3.zero
			applyUprightTarget()
			setCameraZoomBlocked(false)
		end
		dragging = false
		dragInput = nil
		dragWorldOffset = nil
		grabPlaneDepth = nil
		activeGrabInput = nil
	end

	local function connectGrabHandle(handle: TextButton)
		handle.InputBegan:Connect(function(input)
			if not isGrabInput(input) or resizing then
				return
			end
			beginGrab(input)
		end)
		handle.InputEnded:Connect(function(input)
			endGrab(input)
		end)
	end

	connectGrabHandle(dragHandle)
	connectGrabHandle(backDragHandle)

	onInputChanged(function(i)
		if isMoveInput(i) then
			dragInput = i
		elseif pinned and dragging and i.UserInputType == Enum.UserInputType.MouseWheel then
			local scrollDir = i.Position.Z
			if scrollDir ~= 0 then
				local cam = Workspace.CurrentCamera
				if cam and grabPlaneDepth then
					local step = (scrollDir > 0 and 1 or -1) * GRAB_DEPTH_STEP
					grabPlaneDepth += step
					anchorPart.AssemblyLinearVelocity = Vector3.zero
					anchorPart.AssemblyAngularVelocity = Vector3.zero
					local hit = rayCameraDepthPlane(grabPlaneDepth)
					if hit and dragWorldOffset then
						local newPos = hit + dragWorldOffset
						anchorPart.CFrame = CFrame.new(newPos) * worldPanelRotation
					else
						anchorPart.CFrame = CFrame.new(anchorPart.Position + cam.CFrame.LookVector * step) * worldPanelRotation
						refreshGrabOffset()
					end
					applyUprightTarget()
				end
			end
		end
	end)

	onInputEnded(function(i)
		if activeGrabInput and i.UserInputType == activeGrabInput then
			endGrab(i)
		end
	end)

	onRender(function(dt)
		if not dragging or resizing then
			return
		end
		if pinned then
			local cam = Workspace.CurrentCamera
			local target = anchorPart.Position
			if grabPlaneDepth then
				local hit = rayCameraDepthPlane(grabPlaneDepth)
				if hit and dragWorldOffset then
					target = hit + dragWorldOffset
				end
			end

			local offset = target - anchorPart.Position
			if offset.Magnitude > 0.05 then
				anchorPart.AssemblyLinearVelocity = offset.Unit * math.min(GRAB_MOVE_SPEED, offset.Magnitude * 12)
			else
				anchorPart.AssemblyLinearVelocity = Vector3.zero
			end
			anchorPart.AssemblyAngularVelocity = Vector3.zero

			if cam then
				local targetRot = uprightRotationAt(anchorPart.Position, cam)
				worldPanelRotation = worldPanelRotation:Lerp(targetRot, math.clamp(GRAB_YAW_LERP * dt * 60, 0, 1))
				applyUprightTarget()
			end
		elseif dragInput then
			local delta = dragInput.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	return {
		isPinned = function()
			return pinned
		end,
		isResizing = function()
			return resizing
		end,
		setCameraZoomBlocked = setCameraZoomBlocked,
		teardown = function()
			setCameraZoomBlocked(false)
			if pinned then
				disableWorldPhysics()
				worldFace.Adornee = nil
				worldFace.Enabled = false
				worldBack.Adornee = nil
				worldBack.Enabled = false
				anchorPart.CanQuery = false
				win.Parent = gui
				pinned = false
			end
			if worldFace.Parent then
				worldFace:Destroy()
			end
			if worldBack.Parent then
				worldBack:Destroy()
			end
			if worldRoot.Parent then
				worldRoot:Destroy()
			end
		end,
	}
end
