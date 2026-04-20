const std = @import("std");

const max_pages: u8 = 100;
const max_page_text: u16 = 256;
const max_title_len: u8 = 32;
const max_author_len: u8 = 32;
const max_generation: u8 = 2;

pub const Page = struct {
    text: [max_page_text]u8 = undefined,
    text_len: u16 = 0,
};

pub const BookState = struct {
    pages: [max_pages]Page = [_]Page{.{}} ** max_pages,
    page_count: u8 = 1,
    title: [max_title_len]u8 = undefined,
    title_len: u8 = 0,
    author: [max_author_len]u8 = undefined,
    author_len: u8 = 0,
    signed: bool = false,
    generation: u8 = 0,

    pub fn setPageText(self: *BookState, page: u8, text: []const u8) bool {
        if (self.signed) return false;
        if (page >= self.page_count) return false;
        const len: u16 = @intCast(@min(text.len, max_page_text));
        @memcpy(self.pages[page].text[0..len], text[0..len]);
        self.pages[page].text_len = len;
        return true;
    }

    pub fn getPageText(self: BookState, page: u8) []const u8 {
        if (page >= self.page_count) return &[_]u8{};
        return self.pages[page].text[0..self.pages[page].text_len];
    }

    pub fn addPage(self: *BookState) bool {
        if (self.page_count >= max_pages) return false;
        self.pages[self.page_count] = .{};
        self.page_count += 1;
        return true;
    }

    pub fn sign(self: *BookState, title: []const u8, author: []const u8) void {
        if (self.signed) return;
        const tlen: u8 = @intCast(@min(title.len, max_title_len));
        @memcpy(self.title[0..tlen], title[0..tlen]);
        self.title_len = tlen;
        const alen: u8 = @intCast(@min(author.len, max_author_len));
        @memcpy(self.author[0..alen], author[0..alen]);
        self.author_len = alen;
        self.signed = true;
    }

    pub fn copy(self: BookState) ?BookState {
        if (self.generation >= max_generation) return null;
        var result = self;
        result.generation = self.generation + 1;
        return result;
    }
};

pub const LecternState = struct {
    book: ?BookState = null,
    current_page: u8 = 0,

    pub fn placeBook(self: *LecternState, book: BookState) void {
        self.book = book;
        self.current_page = 0;
    }

    pub fn removeBook(self: *LecternState) ?BookState {
        const b = self.book;
        self.book = null;
        self.current_page = 0;
        return b;
    }

    pub fn turnPage(self: *LecternState, forward: bool) void {
        const b = self.book orelse return;
        if (forward) {
            if (self.current_page + 1 < b.page_count) {
                self.current_page += 1;
            }
        } else {
            if (self.current_page > 0) {
                self.current_page -= 1;
            }
        }
    }

    pub fn getRedstoneOutput(self: LecternState) u4 {
        const b = self.book orelse return 0;
        if (b.page_count <= 1) return 0;
        const page: u32 = self.current_page;
        const max_page: u32 = b.page_count - 1;
        const result: u32 = (page * 15 + max_page / 2) / max_page;
        return @intCast(@min(result, 15));
    }
};

test "write page text" {
    var book = BookState{};
    const ok = book.setPageText(0, "Hello, world!");
    try std.testing.expect(ok);
    try std.testing.expectEqualStrings("Hello, world!", book.getPageText(0));
}

test "sign locks editing" {
    var book = BookState{};
    _ = book.setPageText(0, "Draft text");
    book.sign("My Book", "Author");
    try std.testing.expect(book.signed);
    try std.testing.expectEqualStrings("My Book", book.title[0..book.title_len]);
    try std.testing.expectEqualStrings("Author", book.author[0..book.author_len]);
    const locked = book.setPageText(0, "Changed");
    try std.testing.expect(!locked);
    try std.testing.expectEqualStrings("Draft text", book.getPageText(0));
}

test "copy generation limits" {
    var original = BookState{};
    _ = original.setPageText(0, "Original");
    original.sign("Title", "Auth");

    const copy1 = original.copy().?;
    try std.testing.expectEqual(@as(u8, 1), copy1.generation);

    const copy2 = copy1.copy().?;
    try std.testing.expectEqual(@as(u8, 2), copy2.generation);

    try std.testing.expect(copy2.copy() == null);
}

test "lectern page turning" {
    var book = BookState{};
    _ = book.addPage();
    _ = book.addPage();
    _ = book.setPageText(0, "Page 1");
    _ = book.setPageText(1, "Page 2");
    _ = book.setPageText(2, "Page 3");

    var lectern = LecternState{};
    lectern.placeBook(book);
    try std.testing.expectEqual(@as(u8, 0), lectern.current_page);

    lectern.turnPage(true);
    try std.testing.expectEqual(@as(u8, 1), lectern.current_page);

    lectern.turnPage(true);
    try std.testing.expectEqual(@as(u8, 2), lectern.current_page);

    lectern.turnPage(true);
    try std.testing.expectEqual(@as(u8, 2), lectern.current_page);

    lectern.turnPage(false);
    try std.testing.expectEqual(@as(u8, 1), lectern.current_page);
}

test "lectern redstone output" {
    var book = BookState{};
    var i: u8 = 0;
    while (i < 14) : (i += 1) {
        _ = book.addPage();
    }
    // book now has 15 pages (1 default + 14 added)

    var lectern = LecternState{};
    lectern.placeBook(book);

    try std.testing.expectEqual(@as(u4, 0), lectern.getRedstoneOutput());

    lectern.current_page = 14;
    try std.testing.expectEqual(@as(u4, 15), lectern.getRedstoneOutput());

    lectern.current_page = 7;
    try std.testing.expectEqual(@as(u4, 8), lectern.getRedstoneOutput());
}

test "lectern remove book" {
    var book = BookState{};
    _ = book.setPageText(0, "Content");

    var lectern = LecternState{};
    lectern.placeBook(book);
    try std.testing.expect(lectern.book != null);

    const removed = lectern.removeBook();
    try std.testing.expect(removed != null);
    try std.testing.expect(lectern.book == null);
    try std.testing.expectEqualStrings("Content", removed.?.getPageText(0));
}

test "get page text out of bounds" {
    const book = BookState{};
    try std.testing.expectEqualStrings("", book.getPageText(5));
}

test "add page limit" {
    var book = BookState{};
    var count: u8 = 0;
    while (count < max_pages - 1) : (count += 1) {
        try std.testing.expect(book.addPage());
    }
    try std.testing.expectEqual(max_pages, book.page_count);
    try std.testing.expect(!book.addPage());
}
