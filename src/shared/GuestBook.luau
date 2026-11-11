--!strict
-- The Livre d'Or (the house's guest book): guests sign it with a line chosen from these, never
-- typed, once a night. The last few signatures stay for everyone to read.

local GuestBook = {}

GuestBook.Lines = {
	"What an evening.",
	"My first night here. I'll be back.",
	"The Salon, always.",
	"Steal a Luxe: one more trip.",
	"The Basement nearly beat me.",
	"I made it to the Executive Suite.",
	"I kept the last lamp tonight.",
	"A win in the Library. They'll want another.",
	"The Pianist was wonderful tonight.",
	"Good evening to the Concierge.",
	"See you at the Soirée.",
	"Looking for a rival. Find me in the Library.",
	"Come and join my Circle.",
	"Tonight's table was hard. I'll be back tomorrow.",
	"Until midnight.",
	"Thank you for a lovely house.",
}

GuestBook.keep = 30 -- signatures kept

return GuestBook
