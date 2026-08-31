-- Bindable hub so server modules do not circular-require.

local GameEvents = {
	RunStarted = Instance.new("BindableEvent"),
	RunFailed = Instance.new("BindableEvent"),
	RunCompleted = Instance.new("BindableEvent"),
	PlayerDiedInRun = Instance.new("BindableEvent"),
	PassOwnershipChanged = Instance.new("BindableEvent"),
}

return GameEvents
