//! main.zig. game logic and funcionality is contained here, as well as the raylib sutff

const rl = @import("raylib");
const std = @import("std");

const config = @import("config.zig");

// structs and enums
const Suit = enum {
        spades,
        hearts,
        diamonds,
        clubs,
};

const Rank = enum(u8) {
        two = 2, // because two = 2, rest of ranks will enumerate as three = 3, four = 4, etc.
        three,
        four,
        five,
        six,
        seven,
        eight,
        nine,
        ten,
        jack,
        queen,
        king,
        ace,
};

const Action = enum {
        heal,
        equip,
        fight,
        barehand,
};

const Card = struct {
        rank: Rank,
        suit: Suit,
        
        fn resolve(self: *Card, barehanded: bool) Action {
                if (self.suit == Suit.spades or self.suit == Suit.clubs) {
                        if (barehanded) {
                                return Action.barehand;
                        } else if (!barehanded) {
                                return Action.fight;
                        }
                } else if (self.suit == Suit.hearts) {
                        return Action.heal;
                } else if (self.suit == Suit.diamonds) {
                        return Action.equip;
                }
        }

        fn getAsText(self: Card, allocator: std.mem.Allocator) ![]u8 {
                return try std.fmt.allocPrint(
                        allocator,
                        "{s} of {s}",
                        .{
                                @tagName(self.rank),
                                @tagName(self.suit),
                        },
                );
        }
};

const Game = struct {
        deck: [44]Card, // slice of 44 cards
        deck_size: usize,
        room: [4]Card,

        health: u8,
        equipped_weapon: Card,

        // conceptually:
        // deck[0] = "bottom"
        // deck[43] = "top"

        fn generateDeck(self: *Game) void {
                const suits = [_]Suit{
                        .hearts,
                        .diamonds,
                        .clubs,
                        .spades
                };

                for (suits) |suit| {
                        for (2..15) |rank_num| {// 14 cards per suit
                                const rank: Rank = @enumFromInt(rank_num); // will use rank_num to determine the rank from the enum

                                // skip the red faces and aces (ooh tuff ryhme)
                                if (suit == .hearts or suit == .diamonds) {
                                        if (rank == .ace or rank == .jack or rank == .queen or rank == .king) {
                                                continue;
                                        }
                                }

                                self.deck[self.deck_size] = .{
                                        .suit = suit,
                                        .rank = rank,
                                };

                                self.deck_size += 1;
                        }
                }
                std.debug.print("GAME: deck size: {d}\n", .{self.deck_size});
        }
        
        fn shuffleDeck(self: *Game, random: std.Random) void {
                var i = self.deck_size;

                while (i > 1) {
                        i -= 1;

                        const j = random.uintLessThan(usize, i + 1);
                        const temp = self.deck[i];
                        self.deck[i] = self.deck[j];
                        self.deck[j] = temp;
                }
                std.debug.print("GAME: deck shuffled\n", .{});
        }

        fn getRoom(self: *Game) void {
                for (&self.room) |*card| {
                        self.deck_size -= 1;
                        card.* = self.deck[self.deck_size]; // deal from the top of the deck, assign the actual card into the room, and not just the pointer. thats what card.* is for.
                }

                std.debug.print("GAME: current room:\n", .{});
                for (self.room, 0..) |card , i| { // card: iterates over the cards in the room i: index
                        std.debug.print(
                                "[Card {d}]: {s} of {s}\n",
                                .{
                                        i + 1,
                                        @tagName(card.rank), // @tagName converts an enum value into a string so we can print it.
                                        @tagName(card.suit),
                                }
                        );
                }
        }

        fn getRoomText(self: Game, allocator: std.mem.Allocator) ![:0]u8 {
                var buf: std.ArrayList(u8) = .empty;
                defer buf.deinit(allocator);

                for (self.room, 0..) |card, i| {
                        const card_text = try card.getAsText(allocator);
                        defer allocator.free(card_text);

                        try buf.appendSlice(allocator, card_text);

                        if (i < self.room.len - 1) { // adds | in between cards
                                try buf.appendSlice(allocator, " | ");
                        }
                }
                
                const result = try allocator.allocSentinel(u8, buf.items.len, 0);
                @memcpy(result, buf.items);

                return result;
        }

        fn avoidRoom(self: *Game) void {
                const remaining = self.deck_size;

                // put the room on the bottom of the deck, so it gets dealt last
                std.mem.copyBackwards(Card, self.deck[self.room.len..][0..remaining], self.deck[0..remaining]);
                @memcpy(self.deck[0..self.room.len], &self.room);
                self.deck_size += self.room.len;

                std.debug.print("GAME: room avoided.\n", .{});
        }
};

pub fn main() anyerror!void {
        
        var prng = std.Random.DefaultPrng.init(config.seed);
        const random = prng.random();

        const allocator = std.heap.page_allocator;

        // game state
        var game = Game {
                .deck = undefined,
                .deck_size = 0,
                .room = undefined,
                .health = 20,
                .equipped_weapon = undefined,
        };
        
        game.generateDeck();
        game.shuffleDeck(random);
        game.getRoom();

        // raylib init
        rl.initWindow(config.window_width, config.window_height, config.window_title);
        defer rl.closeWindow(); // Close window and OpenGL context

        rl.setTargetFPS(config.target_fps); // Set our game to run at 60 frames-per-second

        // Main game loop
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
                
                //-Input-------------------------
                if (rl.isKeyPressed(.r)) {
                        game.avoidRoom();
                        game.getRoom();
                }
                //-------------------------------

                //-Draw--------------------------
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(.black);

                { // get room text, draw to screen
                        const room_text = try game.getRoomText(allocator);
                        defer allocator.free(room_text);

                        rl.drawText(room_text, 20, 50, 20, .light_gray);
                }
               //-------------------------------
        }
}
