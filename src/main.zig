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
        ace = 1,
        two,
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
        }
};

pub fn main() anyerror!void {
        // game state
        var game = Game {
                .deck = undefined,
                .deck_size = 0,
                .health = 20,
        };
        
        game.generateDeck();

        std.debug.print("GAME: deck size: {d}\n", .{game.deck_size});

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
