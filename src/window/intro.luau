--!nonstrict
-- Standalone 3D brand intro: letters scale in front of the camera, then fall.
local Services = require("../services")
local TweenService = Services.TweenService
local Workspace = Services.Workspace

local function playWorldIntro(
	brand: string,
	accent: Color3,
	titleFont: Font,
	onDone: (() -> ())?
)
	local camera = Workspace.CurrentCamera
	if not camera then
		if onDone then
			onDone()
		end
		return
	end

	for _, child in Workspace:GetChildren() do
		if child.Name == "DexUIIntro" and child:IsA("Folder") then
			child:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "DexUIIntro"
	folder.Parent = Workspace

	local spawnCF = camera.CFrame * CFrame.new(0, 0.15, -11)
	local letterW, letterH, letterD = 0.82, 2.1, 0.32
	local gap = -0.04
	local totalW = #brand * letterW + math.max(0, #brand - 1) * gap

	local parts: { Part } = {}
	local texts: { TextLabel } = {}
	local borders: { UIStroke } = {}

	local borderColor = accent:Lerp(Color3.new(0, 0, 0), 0.55)

	local function randomLogoTilt(): number
		local sign = math.random(0, 1) == 0 and -1 or 1
		return sign * (1 + math.random() * 1) -- ±1°..±2°
	end

	for i = 1, #brand do
		local ch = brand:sub(i, i)
		local x = -totalW / 2 + letterW / 2 + (i - 1) * (letterW + gap)
		local targetSize = Vector3.new(letterW, letterH, letterD)

		local part = Instance.new("Part")
		part.Name = "DexUI_" .. ch
		part.Size = targetSize * 0.02
		part.CFrame = spawnCF * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.rad(randomLogoTilt()))
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = folder

		local face = Instance.new("SurfaceGui")
		face.Name = "LetterFace"
		face.Face = Enum.NormalId.Front
		face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		face.PixelsPerStud = 64
		face.LightInfluence = 0
		face.Parent = part

		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = ch
		tl.TextScaled = true
		tl.FontFace = titleFont
		tl.TextColor3 = accent
		tl.TextTransparency = 1
		tl.Parent = face

		local stroke = Instance.new("UIStroke")
		stroke.Color = borderColor
		stroke.Thickness = 3.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Transparency = 1
		stroke.Parent = tl

		table.insert(parts, part)
		table.insert(texts, tl)
		table.insert(borders, stroke)
	end

	local scaleIn = TweenInfo.new(0.32, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	for i, part in parts do
		local targetSize = Vector3.new(letterW, letterH, letterD)
		TweenService:Create(part, scaleIn, { Size = targetSize }):Play()
		TweenService:Create(texts[i], scaleIn, { TextTransparency = 0 }):Play()
		TweenService:Create(borders[i], scaleIn, { Transparency = 0 }):Play()
	end

	task.wait(1)

	for _, part in parts do
		part.Anchored = false
		part.CanCollide = true
		part.CustomPhysicalProperties = PhysicalProperties.new(0.85, 0.3, 0.35, 1, 1)
		part.AssemblyLinearVelocity = Vector3.new(
			math.random(-1, 1),
			math.random(-3, -1),
			math.random(-1, 2)
		)
		part.AssemblyAngularVelocity = Vector3.new(
			math.random(-4, 4),
			math.random(-2, 2),
			math.random(-4, 4)
		)

		local float = Instance.new("BodyForce")
		float.Force = Vector3.new(0, part.AssemblyMass * Workspace.Gravity * 0.45, 0)
		float.Parent = part
	end

	task.wait(0.9)

	task.delay(60, function()
		if folder.Parent then
			folder:Destroy()
		end
	end)

	if onDone then
		onDone()
	end
end

return playWorldIntro
