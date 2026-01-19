local StatusEffectsFolder = game:GetService("ServerStorage"):FindFirstChild("StatusEffects")
if StatusEffectsFolder then
	for _, v in StatusEffectsFolder:GetDescendants() do
		if v:IsA("ModuleScript") then
			local z = require(v)
			z.Discriminator = Random.new():NextNumber(-1000, 1000)
		end
	end
end
