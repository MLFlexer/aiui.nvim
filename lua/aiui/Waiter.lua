---The Waiter is a class which enables a running animation
---which updates every x miliseconds
---@class Waiter
---@field timer nil | uv_timer_t
---@field animation string[]
---@field frame integer
local Waiter = { timer = nil, animation = { ".", "..", "..." }, frame = 1 }

---updates and returns the next frame
---@return string
function Waiter:next_frame()
	-- + 1 as lua tables are 1-indexed
	local frame = self.animation[self.frame % #self.animation + 1]
	self.frame = self.frame + 1
	return frame
end

---Apply a callback each for every milisecond
---@param fpms integer
---@param callback function
function Waiter:start(fpms, callback)
	if self.timer then
		error("Waiter already started")
	end
	self.timer = vim.loop.new_timer()
	self.timer:start(0, fpms, callback)
end

---Stops waiter
function Waiter:stop()
	if self.timer then
		self.timer:stop()
		self.timer = nil
	end
end

---Creates a new Waiter with a given animation
---@param animation string[]
---@return Waiter
function Waiter:new(animation)
	local waiter = Waiter
	waiter.animation = animation
	return vim.deepcopy(waiter)
end

return Waiter
