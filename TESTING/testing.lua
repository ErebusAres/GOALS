-- wowprogramming.com ; reference page for api

local s = 5;
local myFunc = function() 
    local s;
    s = 2;
    return s;
end

s = myFunc();
print(s) -- returns 2

local function counter(a, b, c)
    local ans = (a * b) + c;

    return ans;
end

print(counter(15, 3, 600));