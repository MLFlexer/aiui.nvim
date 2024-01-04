-- to run use following cmd:
-- PlenaryBustedFile lua/testing/diff/diff_test.lua
local diff = require("aiui.diff")

describe("full change", function()
	it("No lines changed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local expected_hunks = {}
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)
	it("All lines removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {}
		local expected_hunks = { { before = { 1, 5 } } }
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)
	it("All lines removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"6",
			"7",
			"8",
			"9",
			"0",
		}
		local expected_hunks = { { before = { 1, 5 }, after = { 1, 5 } } }
		local expected_lines = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)
end)

describe("remove tests:", function()
	assert:set_parameter("TableFormatLevel", -1)
	it("3 removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"4",
			"5",
		}
		local expected_hunks = { { unchanged = { 1, 2 }, before = { 3, 3 } } }
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("1 removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"2",
			"3",
			"4",
			"5",
		}
		local expected_hunks = { { before = { 1, 1 } } }
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("5 removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"3",
			"4",
		}
		local expected_hunks = { { unchanged = { 1, 4 }, before = { 5, 5 } } }
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("2,3 removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"4",
			"5",
		}
		local expected_hunks = { { unchanged = { 1, 1 }, before = { 2, 3 } } }
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("1,2 removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"3",
			"4",
			"5",
		}
		local expected_hunks = { { before = { 1, 2 } } }
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("4,5 removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"3",
		}
		local expected_hunks = { { before = { 4, 5 } } }
		local expected_lines = { "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)
end)

describe("addition tests:", function()
	assert:set_parameter("TableFormatLevel", -1)
	it("3.5 added", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"3",
			"3.5",
			"4",
			"5",
		}
		local expected_hunks = { { unchanged = { 1, 3 }, after = { 4, 4 } } }
		local expected_lines = { "1", "2", "3", "3.5", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("0 added", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"0",
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local expected_hunks = { { after = { 1, 1 } } }
		local expected_lines = { "0", "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("6 added", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"3",
			"4",
			"5",
			"6",
		}
		local expected_hunks = { { unchanged = { 1, 5 }, after = { 6, 6 } } }
		local expected_lines = { "1", "2", "3", "4", "5", "6" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("3.1, 3.2 added", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"3",
			"3.1",
			"3.2",
			"4",
			"5",
		}
		local expected_hunks = { { unchanged = { 1, 3 }, after = { 4, 5 } } }
		local expected_lines = { "1", "2", "3", "3.1", "3.2", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("-1,0 added", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"-1",
			"0",
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local expected_hunks = { { after = { 1, 2 } } }
		local expected_lines = { "-1", "0", "1", "2", "3", "4", "5" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)

	it("6,7 added", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"2",
			"3",
			"4",
			"5",
			"6",
			"7",
		}
		local expected_hunks = { unchanged = { 1, 5 }, { after = { 6, 7 } } }
		local expected_lines = { "1", "2", "3", "4", "5", "6", "7" }
		local hunks, lines = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(hunks, expected_hunks)
		assert.same(lines, expected_lines)
	end)
end)
