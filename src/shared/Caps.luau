--!strict
-- Capitals for display text. string.upper only knows A to Z, so "Soirée" would come out
-- "SOIRéE" and "Tête-à-Tête" "TêTE-à-TêTE": the accented letters are raised here too.

local ACCENTS: { [string]: string } = {
	["à"] = "À", ["á"] = "Á", ["â"] = "Â", ["ä"] = "Ä", ["æ"] = "Æ", ["ç"] = "Ç",
	["è"] = "È", ["é"] = "É", ["ê"] = "Ê", ["ë"] = "Ë", ["ì"] = "Ì", ["í"] = "Í",
	["î"] = "Î", ["ï"] = "Ï", ["ñ"] = "Ñ", ["ò"] = "Ò", ["ó"] = "Ó", ["ô"] = "Ô",
	["ö"] = "Ö", ["ù"] = "Ù", ["ú"] = "Ú", ["û"] = "Û", ["ü"] = "Ü", ["œ"] = "Œ",
}

local function caps(text: string): string
	local up = string.upper(text)
	return (string.gsub(up, "[\195\197][\128-\191]", function(ch: string): string
		return ACCENTS[ch] or ch
	end))
end

return caps
