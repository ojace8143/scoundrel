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
};

const State = enum {
        playing,
        gameOver,
};

const Card = struct {
        rank: Rank,
        suit: Suit,
        
        fn resolve(self: Card) Action {
                return switch (self.suit) {
                        .spades, .clubs => .fight,
                        .hearts => .heal,
                        .diamonds => .equip,
                };
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
        room_len: usize,

        health: u8,
        equipped_weapon: ?Card,
        weapon_durabillity: u8, // highest rank the equipped weapon can still slay

        potion_used: bool,
        avoided_last_room: bool,

        state: State,
        random: std.Random,

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
                const needed = self.room.len - self.room_len;
                const deal = @min(needed, self.deck_size);

                var i = self.room_len;
                while (i < self.room_len + deal) : (i += 1) {
                        self.deck_size -= 1;
                        self.room[i] = self.deck[self.deck_size]; // deal from the top of the deck into the room
                }
                self.room_len += deal;
                self.potion_used = false;

                std.debug.print("GAME: current room:\n", .{});
                for (self.room[0..self.room_len], 0..) |card, index| {
                        std.debug.print(
                                "[Card {d}]: {s} of {s}\n",
                                .{
                                        index + 1,
                                        @tagName(card.rank), // @tagName converts an enum value into a string so we can print it.
                                        @tagName(card.suit),
                                }
                        );
                }
        }

        fn removeRoomCard(self: *Game, index: usize) void {
                var i = index;
                while (i + 1 < self.room_len) : (i += 1) {
                        self.room[i] = self.room[i + 1];
                }
                self.room_len -= 1;
        }

        fn getRoomText(self: Game, allocator: std.mem.Allocator) ![:0]u8 {
                var buf: std.ArrayList(u8) = .empty;
                defer buf.deinit(allocator);

                for (self.room[0..self.room_len], 0..) |card, i| {
                        const card_text = try card.getAsText(allocator);
                        defer allocator.free(card_text);

                        try buf.appendSlice(allocator, card_text);

                        if (i < self.room_len - 1) { // adds | in between cards
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

        fn resolveCard(self: *Game, card: Card, barehanded: bool) void {
                const card_value: u8 = @intFromEnum(card.rank);
                const resolved_action = card.resolve();

                switch (resolved_action) {
                        .equip => {
                                self.equipped_weapon = card;
                                self.weapon_durabillity = 14; // a fresh weapon can slay any rank
                        },

                        .heal => {
                                if (self.potion_used) return; // only one potion per room
                                self.potion_used = true;
                                self.health = @min(20, self.health + card_value);
                        },

                        .fight => {
                                var damage: u8 = card_value;

                                if (!barehanded) {
                                        if (self.equipped_weapon) |weapon| {
                                                if (card_value <= self.weapon_durabillity) {
                                                        const weapon_value: u8 = @intFromEnum(weapon.rank);
                                                        damage = if (card_value > weapon_value) card_value - weapon_value else 0;
                                                        self.weapon_durabillity = card_value - 1; // next monster must rank lower
                                                }
                                        }
                                }

                                if (damage >= self.health) {
                                        self.health = 0;
                                        self.state = .gameOver;
                                } else {
                                        self.health -= damage;
                                }
                        },
                }
        }

        fn update(self: *Game) void {
                if (self.state != .playing) {
                        if (rl.isKeyPressed(.enter)) {
                                self.reset();
                        }
                        return;
                }

                if (self.room_len == 0) {
                        if (self.deck_size == 0) {
                                self.state = .gameOver; // dungeon cleared
                        } else {
                                self.getRoom();
                        }
                        return;
                }

                // keep the leftover card and deal the next room
                if (self.room_len == 1 and self.deck_size > 0) {
                        self.getRoom();
                }

                if (rl.isKeyPressed(.r) and self.room_len == self.room.len and !self.avoided_last_room) {
                        self.avoidRoom();
                        self.room_len = 0;
                        self.getRoom();
                        self.avoided_last_room = true;
                        return;
                }

                const keys = [_]rl.KeyboardKey{ .one, .two, .three, .four };
                const barehanded = rl.isKeyDown(.left_shift);

                for (keys, 0..) |key, i| {
                        if (!rl.isKeyPressed(key) or i >= self.room_len) continue;

                        self.resolveCard(self.room[i], barehanded);
                        self.removeRoomCard(i);
                        self.avoided_last_room = false;
                        break;
                }
        }

        fn reset(self: *Game) void {
                const random = self.random;

                self.* = .{
                        .deck = undefined,
                        .deck_size = 0,
                        .room = undefined,
                        .room_len = 0,
                        .health = 20,
                        .equipped_weapon = null,
                        .weapon_durabillity = undefined,
                        .potion_used = false,
                        .avoided_last_room = false,
                        .state = .playing,
                        .random = random,
                };

                self.generateDeck();
                self.shuffleDeck(self.random);
                self.getRoom();
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
                .room_len = 0,
                .health = 20,
                .equipped_weapon = null,
                .weapon_durabillity = undefined,
                .potion_used = false,
                .avoided_last_room = false,
                .state = .playing,
                .random = random,
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
                
                //-Update------------------------
                game.update();
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
