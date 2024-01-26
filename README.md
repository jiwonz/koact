![kocat logo](https://github.com/jiwonz/rbx-koact/blob/main/img/koact.png?raw=true)
# Koact
Facebook's React.js-like UI Development Framework for Roblox(Luau) and Kolloid Framework on Roblox

# About
"Koact" stands for KO(lloid)(re)ACT
It is a built-in library for the Kolloid framework and is included as a submodule.
Koact also enables UI development in Roblox in a similar way to React.

# Note
This project was not developed using rojo (I just wanted to develop on Roblox Studio :D, And this makes it easy to insert as a submodule into the kolloid framework)

# Features
- React-like development pattern and code styles
- Supports Roblox UI Classes
- Supports Full Auto completion
- Supports [Helper](#helper-types) types
- Supports React-like Hooks
- More snippets support
- Unlike react, there is [Modifiers](#modifier-elements) concept
- Unlike react, supports Localization
- Unlike react, supports 2D ParticleEmitter (thanks to [@nuttolum](https://devforum.roblox.com/u/nuttolum/summary))

# Installation
> [Download .RBXM](https://github.com/jiwonz/koact/raw/main/build/koact.rbxm)

# Example Code
```lua
local function App()
	local count,setCount = Koact.useState(0)
	return Koact.TextButton{
		align="center"; --- equal to AnchorPoint=Vector2.new(0.5,0.5);
		Position=UDim2.fromScale(0.5,0.5);
		Size=UDim2.fromScale(0.5,0.5);
		Text=("you've been clicked %s times!"):format(count);
		onClick=function()
			setCount(count+1)
		end
	}
end

Koact.render(
	Koact.ScreenGui{
		Koact[App]{}
	},LocalPlayer.PlayerGui
)
```

# Getting Started
COMING SOON

# Koact Reference

## Introduction

Although there are some things missing or added to Koact, we recommend that you refer to [React's reference](https://react.dev/reference/react). Additionally, Koact uses a virtual DOM(Koact elements) like React and its life cycle is almost identical to React. also full documentation for Koact will be released later. if you have a question, please leave a DM in discord `jiwonz`

## Helper Types
- You can type 'help' or 'HELP' in props table to watch all properties
- If there are any changes to the Roblox UI API, the helper must be updated for autocomplete to work to the latest version.

## Koact

### *Common Elements*
`example`
```lua
--- to create UI Elements
Koact["Roblox UI Class Name Here"]{

}

--- TextLabel element
Koact.TextLabel{
	Text="Hello world";
}

--- event handling
Koact.ImageButton{
	onClick=function()
		print("clicked")
	end,
	onMouseDown=function()
		print("mouse button down")
	end,
	onMouseUp=function()
		print("mouse button up")
	end,
	onMouseEnter=function()
		print("mouse entered")
	end,
	onMouseLeave=function()
		print("mouse left")
	end,
	onRightClick=function()
		print("right mouse clicked")
	end,
}
```

### *Modifier Elements*
- `Koact.Modifiers[Element Name]` Creates a modifier element whose parent element is affected by it.

`example`
```lua
--- you can create roblox's modifiers such as UIGradient, UIStroke, UICorners and etc
--- Or you can use special custom modifiers whose references are listed below.
return Koact.Frame{
	Size=UDim2.fromOffset(300,300);
	Koact.Modifiers.UIGradient{
		Color=ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1));
		Rotation=45;
	}
}
```

### `Modifiers.TextScale`
- Modifies parent element's TextSize depends on this modifier's `Scale` prop
- This `Scale` prop is relative to the Y axis
- Example code is appeared in [Function Components](#function-components) example code section

### `Modifiers.Round`
- Uses Image's slices to implement its round corners
- Must be parented to ImageLabel or ImageButton

### `Modifiers.Blur`
- Makes parent element's area blurry
- Uses `DOF` to create this blur effect

### `Modifiers.ScreenBlur`
- Makes whole screen blurry if the parent element is visible

### `Modifiers.Shadow`
- Creates shadow effect on the parent element

### *Function Components*
`example`
```lua
local function MyButton(props)
	return Koact.ImageButton{
		Position=props.Position;
		Size=props.Size;
		Image=Koact.rbxassetid(12345678);
		Koact.TextLabel{
			Size=UDim2.fromScale(1,1);
			Text=props.Text:upper(); --- i want to make it upper case
			Koact.Modifiers.TextScale{
				Scale=0.7;
			}; --- TextScale example!
		}
	}
end

Koact.render(
	Koact.ScreenGui{
		Koact[MyButton]{ --- this table is called 'props'
			Text="Hello Koact!"
			Size=UDim2.fromOffset(200,100);
			Position=UDim2.fromOffset(0,0);
		};
		Koact[MyButton]{
			Size=UDim2.fromOffset(200,100);
			Position=UDim2.fromOffset(0,100);
		};
		Koact[MyButton]{
			Size=UDim2.fromOffset(200,100);
			Position=UDim2.fromOffset(0,200);
		};
	},LocalPlayer.PlayerGui
)
```

### *Hooks*

### `useContext`
`warning` This function is only available in function component scope
```lua
useContext: (context: Context) -> (any?)
```

- Returns a value from the given context.

### `useState`
`warning` This function is only available in function component scope
```lua
useState: (initialValue: any?) -> (any?, (value) -> ())
```

- Manages state in functional components.

### `useEffect`
`warning` This function is only available in function component scope
```lua
useEffect: (callback: () -> (), ...any?) -> (() -> ())
```

- Runs an effect in functional components.

### `useReducer`
`warning` This function is only available in function component scope
```lua
useReducer: (reducer: (state: any?, action: any?) -> (any?), initialArg: any?) -> (any?, (action: any?) -> ())
```

- Manages state using a reducer function.

### `useRef`
`warning` This function is only available in function component scope
```lua
useRef: (initialValue) -> (Ref)
```

- Creates a mutable object that persists across renders.

`example`
```lua
return function()
	local ref = Koact.useRef()
	Koact.useEffect(function()
		local viewportFrame = ref.current
		local camera = Instance.new("Camera",viewportFrame)
		viewportFrame.CurrentCamera = camera
		local sword = script.Parent.assets.Sword:Clone()
		sword.Parent = viewportFrame
	end,nil)
	return Koact.ViewportFrame{
		ref=ref;
	}
end
```

### `useCallback`
`warning` This function is only available in function component scope
```lua
useCallback: (callback: () -> (), ...any?) -> (() -> ())
```

- Memoizes a callback function.

### `useMemo`
`warning` This function is only available in function component scope
```lua
useMemo: (callback: () -> (), ...any?) -> (any?)
```

- Memoizes a value.

### `useChange`
`warning` This function is only available in function component scope
```lua
useChange: (...any?) -> (boolean)
```

- Monitors changes and returns a boolean.

### `useNavigate`
`warning` This function is only available in function component scope
```lua
useNavigate: () -> ()
```

- Navigates within the application.

### `useTween`
`warning` This function is only available in function component scope
```lua
useTween: (initialValue: any) -> (Hooker, () -> ())
```

- Manages tweening animations.

### `useLocalization`
`warning` This function is only available in function component scope
```lua
useLocalization: (localizationTarget: string) -> ({})
```

- Handles localization.

### `useLanguage`
`warning` This function is only available in function component scope
```lua
useLanguage: () -> (Locale.Enums, (Locale.Enums) -> ())
```

- Returns a function that allows you to change the main language of the localization table that useLocalization will return.

### `useSound`
`warning` This function is only available in function component scope
```lua
useSound: (sound: Sound) -> () -> ()
```

- This returns a function that has the same effect as `SoundService:PlayLocal(sound)`

### `useStylesheet`
`warning` This function is only available in function component scope
```lua
useStylesheet: (stylesheet: {}) -> ()
```

- Applies a stylesheet to a component.

### `newContext`

```lua
newContext: (initialValue: any?) -> (Context)
```

- Creates a new context.

### *Functions*

### `memo`

```lua
memo: (component: Component) -> (Component)
```

- ~~Memoizes a component.~~ (COMING SOON)

### `render`

```lua
render: (element: Element, rendererInstance: Instance) -> ()
```

- Renders an element.

### `rbxassetid`

```lua
rbxassetid: (assetId: number | string) -> (string)
```

- Converts an asset ID number to a rbxasset string.

### *Asynchronous Functions*
`issues` Bugs may occur if these functions are used with or after a function that yields a thread.
### `setTimeout`
`warning` This function is only available in function component scope
```lua
setTimeout: (func: () -> (), seconds: number) -> ()
```

- Sets a timeout for a function.

### `setInterval`
`warning` This function is only available in function component scope
```lua
setInterval: (func: () -> (), seconds: number) -> (number)
```

- Sets an interval for a function.

### `clearInterval`
`warning` This function is only available in function component scope
```lua
clearInterval: (intervalId: number) -> ()
```

- Clears an interval.

### `async`
`warning` This function is only available in function component scope
```lua
async: (func: () -> ()) -> (() -> ())
```

- Executes a function asynchronously.

### `await`
`warning` This function is only available in function component scope
```lua
await: (func: () -> ()) -> (any)
```

- Awaits the result of an asynchronous function.

# Known Issues
- Asynchronous functions may not work as expected or may produce errors or bugs.

# TODO
- Koact.memo()
- More optimized performance
- More features for Koact.useSound()

# Credits / Special Thanks
- [@facebook](https://github.com/facebook/react) for inspiration and solutions
- [@qwreey75](https://github.com/qwreey/quad) for quad/round
- [@Fractality](https://www.roblox.com/users/1516442/profile) for UI Blur
- [@nuttolum](https://devforum.roblox.com/u/nuttolum/summary) for UIParticle
- [@roblox](https://github.com/Roblox/roact) for roact/type, roact/symbol
