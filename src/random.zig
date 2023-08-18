const Random = struct {
    var seed: u32 = 1;

    pub fn init(mySeed: u32) Random {
        return Random{ .seed = mySeed };
    }

    pub fn nextIntRange(self: *Random, min: u32, max: u32) u32 {
        if (min == max)
            return min;
        return min + (self.gen() % (max - min));
    }

    fn gen(self: *Random) u32 {
        var lo: u32 = 16807 * (self.seed & 0xFFFF);
        var hi: u32 = 16807 * (self.seed >> 16);

        lo += (hi & 0x7FFF) << 16;
        lo += hi >> 15;

        if (lo > 0x7FFFFFFF)
            lo -= 0x7FFFFFFF;

        self.seed = lo;
        return lo;
    }
};
