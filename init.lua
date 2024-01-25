-- Ko(lloid)(re)act by jiwonz
-- heavily inspired by react

--- [ Special Thanks ]
-- @react for inspiration and solutions
-- @qwreey75 for quad/round
-- @nuttolum for UIParticle
-- @roblox for roact/type, roact/symbol

--- [ Issues ]
-- render() function is little bit messy -> bugs can be seen

--- [ TODO ]
-- add Koact.memo

local Types = require(script.types)
local module = {}
local meta = {}

--// Imports
local Output = require(script.output)
local Blur = require(script.libs.blur)
local Array = require(script.libs.array)
local Locale = require(script.libs.locale)
local Round = require(script.libs.round)
local UIParticle = require(script.libs.uiparticle)
local KoactType = require(script["type"])
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")
local SoundService = game:GetService("SoundService")

--// Globals
local currentContext:Types.CurrentContext
local screenBlurId = 0
local blurId = 0
local blurDOF
local rendering = {}
local eventHandles = {}
local renderQueue

--// Pre-Index
local newInstance = Instance.new

function Output.fatal(msg,...)
	error(msg:format(...))
end

local function setChildren(props)
	local children = props.children or {
		n=0;
	}
	for i = 1,#props do
		children[i] = props[i]
		children.n+=1
		props[i] = nil
	end
	if children.n > 0 then
		props.children = children
	else
		children = nil
	end
end

local function getChildByIndex(props,index)
	local children = props.children
	if not children then
		return
	end
	return children[index]
end

local function initializeCurrent(current)
	current.hookId = nil
	current.effectQueue = nil
end

--// new functions
function module.newContext(initialValue:any?):Types.Context
	local context = {
		_currentValue=initialValue;
		[KoactType] = KoactType.Context;
	}
	context.Provider = function(props)
		setChildren(props)
		return {
			component=context;
			props=props;
			[KoactType]=KoactType.Element;
		}
	end
	return context
end

--// use functions
function module.useState(initalValue:any?):(any?,(value:any?)->())
	local hooks = currentContext.hooks
	if not hooks then
		hooks = {}
		currentContext.hooks = hooks
	end
	local id = currentContext.hookId and currentContext.hookId+1 or 1 --- should be reset
	local value = hooks[id]
	if not value then
		value = initalValue
		hooks[id] = value
	end
	currentContext.hookId = id
	local current = currentContext
	return value,function(newValue:any?)
		if hooks[id] ~= newValue then
			if type(newValue) ~= "function" then
				hooks[id] = newValue
			else
				hooks[id] = newValue(hooks[id])
			end
			renderQueue = current
		end
	end
end

function module.useChange(...)
	local dependencies = Array(...)
	if dependencies.n == 0 then
		dependencies = nil
	end
	local id = currentContext.hookId and currentContext.hookId+1 or 1
	currentContext.hookId = id
	local hooks = currentContext.hooks
	if not hooks then
		hooks = {}
		currentContext.hooks = hooks
	end
	local effect = hooks[id]
	local effectQueue = currentContext.effectQueue
	if not effectQueue then
		effectQueue = {}
		currentContext.effectQueue = effectQueue
	end
	if effect then
		for i = 1,dependencies.n do
			if dependencies[i] ~= effect[i] then
				effect[i] = dependencies[i]
				return true
			end
		end
	else
		hooks[id] = dependencies
		return true
	end
	return false
end

function module.useCallback(callback:()->(),...)
	local hooks = currentContext.hooks
	if not hooks then
		hooks = {}
		currentContext.hooks = hooks
	end
	local id = currentContext.hookId and currentContext.hookId+1 or 1
	local cache = hooks[id]
	if module.useChange(...) then
		cache = nil
	end
	if cache then
		callback = nil
	else
		hooks[id] = callback
		cache = callback
	end
	return cache
end

function module.useMemo(callback:()->(),...)
	local hooks = currentContext.hooks
	if not hooks then
		hooks = {}
		currentContext.hooks = hooks
	end
	local id = currentContext.hookId and currentContext.hookId+1 or 1
	local cache = hooks[id]
	if module.useChange(...) then
		cache = nil
	end
	if cache then
		callback = nil
	else
		cache = callback()
		hooks[id] = cache
	end
	return cache
end

function module.useEffect(callback:()->(),...)
	local dependencies = Array(...)
	if dependencies.n == 0 then
		dependencies = nil
	end
	local id = currentContext.hookId and currentContext.hookId+1 or 1
	currentContext.hookId = id
	local hooks = currentContext.hooks
	if not hooks then
		hooks = {}
		currentContext.hooks = hooks
	end
	local effect = hooks[id]
	local effectQueue = currentContext.effectQueue
	if not effectQueue then
		effectQueue = {}
		currentContext.effectQueue = effectQueue
	end
	if effect then
		for i = 1,dependencies.n do
			if dependencies[i] ~= effect[i] then
				table.insert(effectQueue,callback)
				effect[i] = dependencies[i]
				break
			end
		end
	else
		table.insert(effectQueue,callback)
		hooks[id] = dependencies
	end
end

function module.useTween(initialValue:any,tweenTime:number?,easingStyle:Enum.EasingStyle?,easingDirection:Enum.EasingDirection?,repeatCount:number?,reverse:boolean?,delayTime:number?)
	local args = Array(tweenTime,easingStyle,easingDirection,repeatCount,reverse,delayTime)
	local state,setState = module.useState(initialValue)
	local stateHookId = currentContext.hookId
	local tweens = currentContext.tweens
	if not tweens then
		tweens = {}
		currentContext.tweens = tweens
	end
	local changed = module.useChange(args:unpack())
	local tweenInfo = tweens[stateHookId]
	if not tweenInfo or changed then
		tweenInfo = TweenInfo.new(table.unpack{args:unpack()})
		tweens[stateHookId] = tweenInfo
	end
	local hooker
	if not changed then
		hooker = function(dom,property)
			local tween = TweenService:Create(dom,tweenInfo,{
				[property]=state;
			})
			tween:Play()
			tween.Completed:Once(function()
				tween:Destroy()
				tween = nil
			end)
		end
	end
	return hooker or state,function(newValue,newtweenTime:number?,neweasingStyle:Enum.EasingStyle?,neweasingDirection:Enum.EasingDirection?,newrepeatCount:number?,newreverse:boolean?,newdelayTime:number?)
		local newArgs = Array(newtweenTime,neweasingStyle,neweasingDirection,newrepeatCount,newreverse,newdelayTime)
		local changed = false
		for i = 1,args.n do
			local new = newArgs[i]
			if new then
				args[i] = new
				changed = true
			end
		end
		if changed then
			tweenInfo = TweenInfo.new(table.unpack{args:unpack()})
		end
		setState(newValue)
	end
end

function module.useReducer(reducer:(state:any?,action:any?)->(any?),initialArg:any?):(any?,(action:any?)->())
	local hooks = currentContext.hooks
	if not hooks then
		hooks = {}
		currentContext.hooks = hooks
	end
	local id = currentContext.hookId and currentContext.hookId+1 or 1
	local value = hooks[id]
	if not value then
		value = initialArg
		hooks[id] = value
	end
	currentContext.hookId = id
	local current = currentContext
	return value,function(action:any?)
		local newValue = reducer(value,action)
		if hooks[id] ~= newValue then
			hooks[id] = newValue
			renderQueue = current
		end
	end
end

function module.useRef(initialValue:any?):Types.Ref
	local id = currentContext.hookId and currentContext.hookId+1 or 1
	currentContext.hookId = id
	local hooks = currentContext.hooks
	if not hooks then
		hooks = {}
		currentContext.hooks = hooks
	end
	local ref = hooks[id]
	if not ref then
		ref = {
			THISISREALSHIT=true;
			current=initialValue;
		}
		hooks[id] = ref
	end
	return ref
end

function module.useContext(context:Types.Context)
	return currentContext.useContext and currentContext.useContext(context)
end

function module.useSound(sound:Sound)
	return function()
		SoundService:PlayLocalSound(sound)
	end
end

function module.useStylesheet(stylesheet)
	local tagStyles = currentContext.tagStyles
	if not tagStyles then
		tagStyles = {}
		currentContext.tagStyles = tagStyles
	end
	for k,v in stylesheet do
		if type(k) == "function" then
			local element = k()
			tagStyles[element.component] = v
		end
	end
end

--// localization
local function cloneLocalizationTable(lt)
	local clone = {}
	for name,t in lt do
		local t2 = {}
		clone[name] = t2
		for k,v in t do
			t2[k] = v
		end
	end
	return clone
end

local localizationContext = module.newContext()
local function localizationProviderComponent(props)
	local default = props._default
	local tables = module.useMemo(function()
		local localizationData = props._data
		for lang,module in localizationData do
			local t = require(module)
			local newDefault = cloneLocalizationTable(default)
			for b,v in t do
				local nameLength = buffer.readu16(b,0)
				local name = buffer.readstring(b,2,nameLength)
				local keyLength = buffer.readu16(b,2+nameLength)
				local key = buffer.readstring(b,2+2+nameLength,keyLength)
				newDefault[name][key] = v
			end
			localizationData[lang] = newDefault
		end
		return localizationData
	end,nil)
	local language,setLanguage = module.useState(Locale[LocalizationService.RobloxLocaleId])
	props.value = {
		localizationTable=tables[language] or default;
		language=tables[language] and language or "default";
		setLanguage=setLanguage
	}
	return localizationContext.Provider(props)
end

function module.newStylesheet(stylesheet)
	for k,v in stylesheet do
		if KoactType.of(k) == KoactType.Element then
			for a,_ in k do
				if a ~= "component" then
					k[a] = nil
				end
			end
		end
	end
	return stylesheet
end

function module.newLocalizationTable(localizationTable,localizationModules:Instance?)
	local id = 0
	local default = {}
	for name,t in localizationTable do
		local t2 = {}
		default[name] = t2
		for k,v in t do
			id+=1
			t2[k] = v
			local nameLength = #name
			local keyLength = #k
			local b = buffer.create(nameLength+keyLength+2+2)
			buffer.writeu16(b,0,nameLength)
			buffer.writestring(b,2,name,nameLength)
			buffer.writeu16(b,2+nameLength,keyLength)
			buffer.writestring(b,2+2+nameLength,k,keyLength)
			t[k] = b
		end
	end
	local localizationData = {}
	if localizationModules then
		for i,v in localizationModules:GetChildren() do
			local locale = v.Name
			local robloxLocaleId = Locale.inverse[locale]
			if robloxLocaleId then
				localizationData[locale] = v
			end
		end
	end
	return {content=localizationTable::typeof(localizationTable),Provider = function(props)
		setChildren(props)
		props._data = localizationData
		props._default = default
		return {
			component=localizationProviderComponent;
			props=props;
			[KoactType]=KoactType.Element;
		}
	end}
end

function module.useLocalization(localizationTable)
	local value = module.useContext(localizationContext)
	return value.localizationTable::typeof(localizationTable)
end
local module:typeof(module)&Types.Koact = module --- for auto typing trick

function module.useLanguage()
	local value = module.useContext(localizationContext)
	return value.language,value.setLanguage
end

--// components
local elementClasses = {
	VideoFrame=true;
	CanvasGroup=true;
	ViewportFrame=true;
	TextLabel=true;
	TextButton=true;
	TextBox=true;
	ImageLabel=true;
	ImageButton=true;
	Frame=true;
	ScrollingFrame=true;
	Div=function()
		local frame = newInstance("Frame")
		frame.BackgroundTransparency = 1
		return frame
	end;
	ScreenGui=function()
		local gui = newInstance("ScreenGui")
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.ResetOnSpawn = false
		return gui
	end;
	SurfaceGui=function()
		local gui = newInstance("SurfaceGui")
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.ResetOnSpawn = false
		return gui
	end;
	BillboardGui=function()
		local gui = newInstance("BillboardGui")
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.ResetOnSpawn = false
		return gui
	end;
	ParticleEmitter=function(parent,props)
		local emitter
		local scale = props.Scale --- this is initial value, not able to change again
		local particle = newInstance("Folder")
		particle.Name = "ParticleEmitter"
		particle:SetAttribute("Emit",0)
		local realEmitterValue = newInstance("ObjectValue")
		realEmitterValue.Name = "ParticleEmitter"
		realEmitterValue.Parent = particle
		particle:SetAttribute("Enabled",false)
		particle:SetAttribute("Scale",1)
		particle.Parent = parent
		local oldEmit
		local function update(attribute)
			local realEmitter = realEmitterValue.Value
			if realEmitter and not emitter then
				emitter = UIParticle.fromEmitter3D(parent,realEmitter,scale)
			end
			if emitter then
				local emit = particle:GetAttribute("Emit")
				local enabled = particle:GetAttribute("Enabled")
				if enabled then
					emitter.Enabled = enabled
				end
				oldEmit = emit
				if emit and emit > 0 then--and oldEmit ~= emit then
					emitter:Emit(emit)
				end
			end
		end
		realEmitterValue.Changed:Connect(update)
		particle.AttributeChanged:Connect(update)
		particle.Destroying:Once(function()
			if emitter then
				emitter.Element:Destroy()
				emitter.Element = nil
				emitter:Destroy()
			end
			emitter = nil
			particle = nil
		end)
		return particle
	end,
}

local modifierClasses = {
	UIAspectRatioConstraint=true;
	UICorner=true;
	UIGradient=true;
	UIGridLayout=true;
	UIListLayout=true;
	UIPadding=true;
	UIPageLayout=true;
	UIScale=true;
	UISizeConstraint=true;
	UIStroke=true;
	UITableLayout=true;
	UITextSizeConstraint=true;
	Blur=function(parent)
		blurId+=1
		if not blurDOF then
			blurDOF = newInstance("DepthOfFieldEffect")
			blurDOF.Name = "koact.dof"
			blurDOF.Enabled = true
			blurDOF.FarIntensity = 0
			blurDOF.FocusDistance = 51.6
			blurDOF.InFocusRadius = 50
			blurDOF.NearIntensity = 0.3
			blurDOF.Parent = Lighting
		end
		local blurPartConfig = {
			Transparency = 0.98,
			Color = Color3.new(1,1,1)
		}
		local blur = newInstance("Folder")
		blur.Name = "Blur"
		blur:SetAttribute("Enabled",true)
		Blur:BindFrame(parent,blurPartConfig)
		blur:GetAttributeChangedSignal("Enabled"):Connect(function()
			if blur:GetAttribute("Enabled") == false then
				Blur:UnbindFrame(parent)
			else
				Blur:BindFrame(parent,blurPartConfig)
			end
		end)
		blur.Destroying:Once(function()
			blurId-=1
			Blur:UnbindFrame(parent)
			blur = nil
			if blurId < 1 then
				blurDOF:Destroy()
				blurDOF = nil
			end
		end)
		return blur
	end;
	ScreenBlur=function()
		screenBlurId+=1
		local screenBlur = newInstance("Folder")
		screenBlur.Name = "ScreenBlur"
		screenBlur:SetAttribute("Enabled",true)
		screenBlur:SetAttribute("Size",24)
		screenBlur:SetAttribute("Archivable",true)
		local realBlur = newInstance("BlurEffect")
		realBlur.Name = "koact.screenblur"..screenBlurId
		realBlur.Enabled = true
		realBlur.Size = 24
		realBlur.Archivable = true
		screenBlur.AttributeChanged:Connect(function(attribute)
			realBlur[attribute] = screenBlur:GetAttribute(attribute)
		end)
		screenBlur.Destroying:Once(function()
			screenBlurId-=1
			realBlur:Destroy()
			realBlur = nil
			screenBlur = nil
		end)
		realBlur.Parent = Lighting
		return screenBlur
	end;
	Round=function(parent:GuiObject)
		if not parent:IsA("ImageLabel") and not parent:IsA("ImageButton") then
			Output.fatal("Koact.Modifier.Round can only be used on ImageLabel and ImageButton.")
			return
		end
		local round = newInstance("Folder")
		round.Name = "Round"
		round:SetAttribute("Size",0)
		round:GetAttributeChangedSignal("Size"):Connect(function()
			Round.SetRound(parent,round:GetAttribute("Size"))
			parent.BorderSizePixel = 0
			parent.BackgroundTransparency = 1
		end)
		round.Destroying:Connect(function()
			Round.SetRound(parent,0)
			round = nil
		end)
		return round
	end,
	Shadow=function(parent)
		local shadow = newInstance("Folder")
		shadow.Name = "Shadow"
		shadow:SetAttribute("Color",Color3.new(0,0,0))
		shadow:SetAttribute("Transparency",0.5)
		shadow:SetAttribute("Offset",UDim2.new())
		local realShadow:Instance = parent:Clone()
		local function overrideOpacity(original)
			return 1-(1-original)*(1-shadow:GetAttribute("Transparency"))
		end
		local function baseImage()
			realShadow.ImageTransparency = overrideOpacity(parent.ImageTransparency)
			realShadow.ImageColor3 = shadow:GetAttribute("Color")
			realShadow.Image = parent.Image
			realShadow.ScaleType = parent.ScaleType
			realShadow.SliceCenter = parent.SliceCenter
			realShadow.SliceScale = parent.SliceScale
			if realShadow:IsA("TextButton") or realShadow:IsA("ImageButton") then
				realShadow.AutoButtonColor = false
			end
		end
		local function baseText()
			realShadow.TextTransparency = overrideOpacity(parent.TextTransparency)
			realShadow.TextColor3 = shadow:GetAttribute("Color")
		end
		local shadowProcessor = {
			ImageLabel = baseImage,
			ImageButton = baseImage,
			TextLabel = baseText,
			TextBox = baseText,
			TextButton = baseText,
		}
		local process = shadowProcessor[realShadow.ClassName]
		realShadow.Name = "koact.shadow"
		local function update()
			realShadow.Size = parent.Size
			local offset = shadow:GetAttribute("Offset")
			realShadow.Position = parent.Position+offset
			realShadow.BackgroundTransparency = overrideOpacity(parent.BackgroundTransparency)
			realShadow.BackgroundColor3 = shadow:GetAttribute("Color")
			realShadow.BorderColor3 = shadow:GetAttribute("Color")
			realShadow.AnchorPoint = Vector2.new(0,0)
			realShadow.SizeConstraint = Enum.SizeConstraint.RelativeXY
			realShadow.ZIndex = parent.ZIndex-1
			process()
		end
		shadow.Destroying:Once(function()
			rendering[realShadow] = nil
			realShadow:Destroy()
			realShadow = nil
			shadow = nil
		end)
		if process then
			rendering[realShadow] = update
		end
		realShadow.Parent = parent.Parent
		shadow.Parent = parent
		return shadow
	end,
	TextScale=function(parent:Instance)
		local textScale = newInstance("Folder")
		textScale.Name = "TextScale"
		local function update()
			parent.TextSize = parent.AbsoluteSize.Y*textScale:GetAttribute("Scale")
		end
		textScale:GetAttributeChangedSignal("Scale"):Connect(update)
		local event = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		textScale.Destroying:Once(function()
			event:Disconnect()
			event = nil
			textScale = nil
		end)
		parent.TextScaled = false
		textScale:SetAttribute("Scale",1)
		return textScale
	end,
}

local events = {
	onMouseDown = "MouseButton1Down";
	onClick = "MouseButton1Click";
	onMouseEnter = "MouseEnter";
	onMouseLeave = "MouseLeave";
	onRightClick = "MouseButton2Click";
	onTextChange = function(v:TextLabel)
		return v:GetPropertyChangedSignal("Text")
	end;
}

local propBase = {
	children=true;
	component=true;
	id=true;
	style=true;
}

--// functions
local function unmount(element)
	local current = element.current
	if current then
		local cleanupFunctions = current.cleanupFunctions
		if cleanupFunctions then
			for i,f in cleanupFunctions do
				f()
				f = nil
				cleanupFunctions[i] = nil
			end
		end
		local oldElement = current.oldElement
		if oldElement then
			local ref = oldElement.ref
			if ref then
				if ref.current then
					ref.current:Destroy()
					ref.current = nil
				end
				ref = nil
				oldElement.ref = nil
			end
			local children = oldElement.props.children
			if children then
				for i = 1,children.n do
					local child = children[i]
					if child then
						unmount(child)
					end
				end
			end
		end
	else
		local ref = element.ref
		if ref then
			if ref.current then
				ref.current:Destroy()
				ref.current = nil
			end
			ref = nil
			element.ref = nil
		end
		local children = element.props.children
		if children then
			for i = 1,children.n do
				local child = children[i]
				if child then
					unmount(child)
				end
			end
		end
	end
end

local function applyStyle(dom,style)
	if not dom then
		return
	end
	for k,v in style do
		if type(k) == "string" then
			dom[k] = v
		end
	end
end

local function applyStyleComponents(props,style)
	for k,v in style do
		if KoactType.of(v) == KoactType.Element then
			local children = props.children
			if not children then
				children = {}
				props.children = children
			end
			children.n += 1
			children[children.n] = v
		end
	end
end

local function render(old,element,parent,current,providers)
	if not element or KoactType.of(element) ~= KoactType.Element then
		return
	end
	local domElement
	local component = element.component

	if old and old.component ~= component then
		if not (type(old.component) == "table" and type(component) == "table") then
			unmount(old)
		end
	end
	local props = element.props
	local filter
	if KoactType.of(component)==KoactType.Context then
		providers = providers or {}
		providers[component] = props.value
		filter = true
	end
	if KoactType.of(component)==KoactType.Fragment then
		filter = true
	end

	local renderChildren = true
	if filter then
		--domElement = parent
	else
		local style = props.style
		if style then
			applyStyleComponents(props,style)
		end
		if current and current.tagStyles then
			local tagStyle = current.tagStyles[component]
			if tagStyle then
				applyStyleComponents(props,tagStyle)
			end
		end
		local classBehavior = elementClasses[component]
		if classBehavior == nil then
			classBehavior = modifierClasses[component]
		end
		if classBehavior then
			if old then
				local ref = old.ref
				if ref and ref.current then
					domElement = ref.current
				end
			else
				domElement = type(classBehavior)=="function" and classBehavior(parent,props) or newInstance(component)
			end
			if domElement then
				local ref = props.ref
				if ref then
					ref.current = domElement
					element.ref = ref
				else
					element.ref = {
						current=domElement
					}
				end
				if not RunService:IsStudio() then
					domElement.Name = ""
				end

				local style = props.style
				if style then
					applyStyle(domElement,style)
				end
				if current and current.props and current.props._componentStyles then
					local tagStyle = current.props._componentStyles[component]
					if tagStyle then
						applyStyle(domElement,tagStyle)
					end
				end

				for k,v in props do
					if old and old.props[k] == v then --- diffing
						continue
					end
					if not propBase[k] then
						if ref and k=="ref" then
							continue
						end
						local event = events[k]
						if event then
							if type(event) == "function" then
								event = event(domElement)
							else
								event = domElement[event]
							end
							local listeners = eventHandles[domElement]
							if not listeners then
								listeners = {}
								eventHandles[domElement] = listeners
							end
							local signal = listeners[k]
							if signal then
								signal:Disconnect()
								signal = nil
							end
							signal = event:Connect(function()
								currentContext = current
								bindThreadManagers(parent,providers)
								v()
								bindThreadManagers(parent,providers)
								currentContext = nil
								if renderQueue then
									local renderTarget = renderQueue
									renderQueue = nil
									initializeCurrent(renderTarget)
									currentContext = renderTarget
									local oldParent = renderTarget.parent
									bindThreadManagers(oldParent,providers)
									local new = renderTarget.component(renderTarget.props) or module.Fragment{}
									unbindThreadManagers(oldParent,providers)
									currentContext = nil
									render(renderTarget.oldElement,new,oldParent,renderTarget,providers)
									renderTarget.oldElement = new
									runQueue(renderTarget,oldParent,providers)
								end
							end)
							listeners[k] = signal
							continue
						end
						if type(v) == "function" then
							v(domElement,k)
						else
							if domElement:GetAttribute(k) ~= nil then
								domElement:SetAttribute(k,v)
							else
								local value = domElement:FindFirstChild(k)
								if value and value:IsA("ValueBase") then
									value.Value = v
								else
									domElement[k] = v
								end
							end
						end
					end
				end
				if not domElement.Parent then
					domElement.Parent = parent
				end
			end
		else
			renderChildren = false
			local current = old and old.current or {}
			if old then
				initializeCurrent(current)
			end
			current.props = props
			if providers then
				local p = {}
				for k,v in providers do
					p[k] = v
				end
				current.useContext = function(context)
					return p and p[context] or context._currentValue
				end
			end
			current.component = component
			currentContext = current
			bindThreadManagers(parent,providers)
			local componentElement = component(props) or module.Fragment{}
			unbindThreadManagers()
			currentContext = nil
			local oldElement = current.oldElement
			current.oldElement = componentElement
			local tagStyles = current.tagStyles
			if tagStyles then
				componentElement.props._componentStyles = tagStyles
			end
			current.parent = parent
			render(oldElement,componentElement,parent,current,providers)
			element.current = current
			runQueue(current,parent,providers)
		end
	end
	if renderChildren then
		local oldChildren
		if old then
			oldChildren = old.props.children
		end
		local children = props.children
		if children then
			local childrenCount = oldChildren and math.max(children.n,oldChildren.n) or children.n
			for i = 1,childrenCount do
				local oldChild = old and getChildByIndex(old.props,i)
				local child = children[i]
				if oldChild then --- 예전에 있었는가
					if child then --- 예전에도 있었고 지금도 있는가
						if child.component == oldChild.component then
							render(oldChild,child,domElement or parent,current,providers)
						else
							unmount(oldChild)
						end
					else --- 예전에 있었는데 지금은 없는가
						unmount(oldChild)
					end
				elseif child then --- 예전에 없었는데 새로 생겼는가
					render(nil,child,domElement or parent,current,providers)
				end
			end
		elseif oldChildren then --- 예전엔 있었는데 이번엔 자녀가 한개도 없는가
			for i = 1,oldChildren.n do
				unmount(oldChildren[i])
			end
		end
	end
end

function unbindThreadManagers()
	module.setTimeout = nil
	module.setInterval = nil
	module.clearInterval = nil
	module.async = nil
	module.await = nil
end

local intervals = {}
local intervalCurrentId = 0

function bindThreadManagers(parent,providers)
	module.setTimeout = function(func:()->(),seconds:number)
		local current = currentContext
		task.delay(seconds,function()
			currentContext = current
			bindThreadManagers(parent,providers)
			func()
			unbindThreadManagers()
			currentContext = nil
			if renderQueue then
				local renderTarget = renderQueue
				renderQueue = nil
				initializeCurrent(renderTarget)
				currentContext = renderTarget
				local oldParent = renderTarget.parent
				bindThreadManagers(oldParent,providers)
				local new = renderTarget.component(renderTarget.props) or module.Fragment{}
				unbindThreadManagers()
				currentContext = nil
				render(renderTarget.oldElement,new,oldParent,renderTarget,providers)
				renderTarget.oldElement = new
				runQueue(renderTarget,oldParent,providers)
			end
		end)
	end

	module.setInterval = function(func:()->(),seconds:number):number
		local current = currentContext
		local thread = coroutine.create(function()
			while true do
				task.wait(seconds)
				currentContext = current
				bindThreadManagers(parent,providers)
				func()
				unbindThreadManagers()
				currentContext = nil
				if renderQueue then
					local renderTarget = renderQueue
					renderQueue = nil
					initializeCurrent(renderTarget)
					currentContext = renderTarget
					local oldParent = renderTarget.parent
					bindThreadManagers(oldParent,providers)
					local new = renderTarget.component(renderTarget.props) or module.Fragment{}
					unbindThreadManagers()
					currentContext = nil
					render(renderTarget.oldElement,new,oldParent,renderTarget,providers)
					renderTarget.oldElement = new
					runQueue(renderTarget,oldParent,providers)
				end
			end
		end)
		coroutine.resume(thread)
		intervalCurrentId += 1
		intervals[intervalCurrentId] = thread
		return intervalCurrentId
	end

	module.clearInterval = function(intervalId:number)
		local thread = intervals[intervalId]
		if thread then
			coroutine.close(thread)
			thread = nil
			intervals[intervalId] = nil
		end
	end

	module.async = function(func:()->())
		local current = currentContext
		return coroutine.wrap(function()
			currentContext = current
			bindThreadManagers(parent,providers)
			func()
			unbindThreadManagers()
			currentContext = nil
			if renderQueue then
				local renderTarget = renderQueue
				renderQueue = nil
				initializeCurrent(renderTarget)
				currentContext = renderTarget
				local oldParent = renderTarget.parent
				bindThreadManagers(oldParent,providers)
				local new = renderTarget.component(renderTarget.props) or module.Fragment{}
				unbindThreadManagers()
				currentContext = nil
				render(renderTarget.oldElement,new,oldParent,renderTarget,providers)
				renderTarget.oldElement = new
				runQueue(renderTarget,oldParent,providers)
			end
		end)
	end

	module.await = function(func:()->())
		local returns = func()
		bindThreadManagers(parent,providers)
		return returns
	end
end

function runQueue(current,parent,providers)
	local queue = current.effectQueue
	local function runRenderQueue()
		if renderQueue then
			local renderTarget = renderQueue
			renderQueue = nil
			initializeCurrent(renderTarget)
			currentContext = renderTarget
			bindThreadManagers(parent,providers)
			local new = renderTarget.component(renderTarget.props) or module.Fragment{}
			unbindThreadManagers()
			currentContext = nil
			render(renderTarget.oldElement,new,parent,renderTarget,providers)
			renderTarget.oldElement = new
			runQueue(renderTarget,providers)
		end
	end
	runRenderQueue()
	if queue then
		local cleanupFunctions = {}
		currentContext = current
		bindThreadManagers(parent,providers)
		for _,callback in queue do
			local cleanup = callback()
			if cleanup then
				table.insert(cleanupFunctions,cleanup)
			end
		end
		unbindThreadManagers()
		currentContext = nil
		if #cleanupFunctions > 0 then
			current.cleanupFunctions = cleanupFunctions
		end
		runRenderQueue()
	end
end

function module.render(element,parent)
	render(nil,element,parent,{})
end

--function module.memo(component:Types.Component):Types.Component TODO: coming soon

--end

function module.rbxassetid(assetId:number | string):string
	return "rbxassetid://"..assetId
end

--// router
local router = {}

local NavigateContext = module.newContext()
local function RouterComponent(props:{})
	local path,setPath = module.useState("/")
	return NavigateContext.Provider{
		value={path=path,setPath=setPath};
		props.children and table.unpack(props.children) or nil;
	}
end

function module.RouterProvider(props:{})
	setChildren(props)
	return {
		component=RouterComponent;
		props=props;
		[KoactType]=KoactType.Element;
	}
end

function module.useLocation()
	return module.useContext(NavigateContext).path
end

function module.useNavigate()
	return module.useContext(NavigateContext).setPath
end

local function RouteComponent(props:{})
	local currentPath = module.useContext(NavigateContext)
	local children = props.children
	if children then
		if currentPath.path == props.ExactPath then
			return module.Fragment{
				table.unpack(children)
			}
		end
	end
end

function module.Route(props:{})
	setChildren(props)
	return {
		component=RouteComponent;
		props=props;
		[KoactType]=KoactType.Element;
	}
end

--// elements
function module.Fragment(props:{})
	setChildren(props)
	return {
		component={
			[KoactType]=KoactType.Fragment
		};
		props=props or {};
		[KoactType]=KoactType.Element;
	}
end

local modifierMeta = {}

function modifierMeta:__index(modifierClass)
	if modifierClasses[modifierClass] == nil then
		Output.fatal("Invalid modifier class '%s'",modifierClass)
		return
	end
	return function(props)
		props = props or {}
		setChildren(props)
		return {
			component=modifierClass;
			props=props;
			[KoactType]=KoactType.Element;
		}
	end
end

module.Modifier = setmetatable({},modifierMeta)

function meta:__index(classOrComponent:string|()->(Types.Element)):Types.Element
	local classBehavior = elementClasses[classOrComponent]
	if type(classOrComponent) == "string" and classBehavior == nil then
		Output.fatal("Invalid class '%s'",classOrComponent)
		return
	end
	return function(props,...) --- '...' are replacements
		props = props or {}
		for _,props2 in {...} do
			for k,v in props2 do
				if k ~= "children" then
					props[k] = v
				end
			end
			local children = props2.children
			if children then
				for i = 1,children.n do
					local child = children[i]
					if child then
						table.insert(props,child)
						children.n+=1
					end
				end
			end
		end
		setChildren(props)
		local align = props.align
		if type(classOrComponent) ~= "function" and align then
			if align==Enum.TextXAlignment.Center then
				props.AnchorPoint = Vector2.new(0.5,0.5)
			elseif align==Enum.TextXAlignment.Left then
				props.AnchorPoint = Vector2.new(1,0)
			else
				props.AnchorPoint = Vector2.new(0,0)
			end
			props.align = nil
		end
		return {
			component=classOrComponent;
			props=props;
			[KoactType]=KoactType.Element;
		}
	end
end

RunService.PreSimulation:Connect(function()
	for _,v in rendering do
		v()
	end
end)

return setmetatable(module,meta)
