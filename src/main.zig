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
        ace = 1, // sets ace to a u8 of 1, rest of cards follow.
        two,     // two is now two = 2, because of the ace = 1
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
};

const Card = struct {
        rank: Rank,
        suit: Suit,
};

const Game = struct {
        deck: [44]Card, // slice of 44 cards
        room: [4]Card,
        deck_size: usize,
        health: u8,

        fn generateDeck(self: *Game) void {
                const suits = [_]Suit{
                        .hearts,
                        .diamonds,
                        .clubs,
                        .spades
                };

                for (suits) |suit| {
                        for (1..14) |rank_num| {// 14 cards per suit
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
                std.debug.print("GAME: deck shuffled", .{});
        }

        fn getRoom(self: *Game) void {
                for (&self.room) |*card| {
                        self.deck_size -= 1;
                        card.* = self.deck[self.deck_size]; // assign the actual card into the room, and not just the pointer. thats what card.* is for.
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
};

pub fn main() anyerror!void {
        
        var prng = std.Random.DefaultPrng.init(config.seed);
        const random = prng.random();

        // game state
        var game = Game {
                .deck = undefined,
                .room = undefined,
                .deck_size = 0,
                .health = 20,
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

                //-Draw-----------------------------------------------------------------------------
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(.black);

                rl.drawText("making game logic first.", 190, 200, 20, .light_gray);
                //----------------------------------------------------------------------------------
        }
}
