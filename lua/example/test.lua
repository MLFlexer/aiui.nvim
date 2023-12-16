-- Define a class named "Person"
Person = { name = "", age = 0 }

-- Define a method for the class
function Person:new(name, age)
	local newObj = {}
	setmetatable(newObj, self)
	self.__index = self
	newObj.name = name
	newObj.age = age
	return newObj
end

function Person:info()
	print("Name:", self.name, "Age:", self.age)
end

-- Create an instance of the Person class
local person1 = Person:new("Alice", 30)
local person2 = Person:new("Bob", 25)

-- Access methods and properties of instances
person1:info() -- Output: Name: Alice Age: 30
person2:info() -- Output: Name: Bob Age: 25

print(vim.inspect(person1))
