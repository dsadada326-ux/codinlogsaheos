-- Shortens big numbers: 1234 -> "1.2K", 300000000 -> "300M", 4.5e12 -> "4.5T"
-- Used by the player list, board totals and popups so they all match.
local NumberFormat = {}

NumberFormat.Suffixes = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

-- whole numbers under 1,000; one decimal (rounded down) with a suffix above that
function NumberFormat.abbreviate(value)
	value = tonumber(value) or 0

	local negative = value < 0
	value = math.abs(value)

	if value < 1000 then
		local text = tostring(math.floor(value))
		return negative and "-" .. text or text
	end

	local index = 1

	while value >= 1000 and index < #NumberFormat.Suffixes do
		value /= 1000
		index += 1
	end

	local text = string.format("%.1f", math.floor(value * 10) / 10)
	text = text:gsub("%.0$", "")

	text = text .. NumberFormat.Suffixes[index]

	return negative and "-" .. text or text
end

-- like abbreviate, but keeps up to 2 decimals for small amounts (1.37 -> "1.37")
function NumberFormat.amount(value)
	value = tonumber(value) or 0

	if math.abs(value) >= 1000 then
		return NumberFormat.abbreviate(value)
	end

	local text = string.format("%.2f", value)
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")

	return text
end

return NumberFormat
