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

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { delete = { 0, 0, a } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)
	it("All lines changed", function()
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
		local expected_hunks = { { delete = { 0, 0, a }, add = { 0, 5 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { delete = { 2, 2, { "3" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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

		local expected_hunks = { { delete = { 0, 0, { "1" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { delete = { 4, 4, { "5" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { delete = { 1, 1, { "2", "3" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { delete = { 0, 0, { "1", "2" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { delete = { 3, 3, { "4", "5" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)

	it("1,5 removed", function()
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
		}
		local expected_hunks = { { delete = { 0, 0, { "1" } } }, { delete = { 3, 3, { "5" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)
	it("2,4 removed", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"1",
			"3",
			"5",
		}
		local expected_hunks = { { delete = { 1, 1, { "2" } } }, { delete = { 2, 2, { "4" } } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { add = { 3, 4 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { add = { 0, 1 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { add = { 5, 6 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { add = { 3, 5 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { add = { 0, 2 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
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
		local expected_hunks = { { add = { 5, 7 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)

	it("0,6 added", function()
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
			"6",
		}
		local expected_hunks = { { add = { 0, 1 } }, { add = { 6, 7 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)
	it("2.5, 4.5 added", function()
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
			"2.5",
			"3",
			"4",
			"4.5",
			"5",
		}
		local expected_hunks = { { add = { 2, 3 } }, { add = { 5, 6 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)

	it("1 replaced by 0", function()
		local a = {
			"1",
			"2",
			"3",
			"4",
			"5",
		}
		local b = {
			"0",
			"2",
			"3",
			"4",
			"5",
		}
		local expected_hunks = { { delete = { 0, 0, { "1" } }, add = { 0, 1 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)

	it("5 replaced by 6", function()
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
			"6",
		}
		local expected_hunks = { { delete = { 4, 4, { "5" } }, add = { 4, 5 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)
	it("3 replaced by x", function()
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
			"x",
			"4",
			"5",
		}
		local expected_hunks = { { delete = { 2, 2, { "3" } }, add = { 2, 3 } } }

		local hunks = diff.indices_to_hunks(diff.get_diff_indices(a, b), a, b)
		assert.same(expected_hunks, hunks)
		diff.insert_and_highlight_diff(0, 0, #a, b, hunks)
	end)
end)
