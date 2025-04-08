const std = @import("std");

const Inst = struct {
    u32,
    u8,
    []const Arg,
};

const Arg = enum(u8) {
    block,
    @"i32",
    @"i64",
    @"f32",
    @"f64",
    index,
    index_vector,
    valtype,
    valtype_vector,
    reftype,
    byte,
};

const instructions = std.StaticStringMap(Inst).initComptime(.{
    .{"unreachable", .{0x00, 0, &[0]Arg{}}},
    .{"nop", .{0x01, 0, &[0]Arg{}}},
    .{"block", .{0x02, 0, &.{ .block }}},
    .{"loop", .{0x03, 0, &.{ .block }}},
    .{"if", .{0x04, 0, &.{ .block }}},
    .{"else", .{0x05, 0, &[0]Arg{ }}},
    .{"try", .{0x06, 0, &[0]Arg{}}},
    .{"catch", .{0x07, 0, &[0]Arg{}}},
    .{"throw", .{0x08, 0, &[0]Arg{}}},
    .{"rethrow", .{0x09, 0, &[0]Arg{}}},
    .{"throw_ref", .{0x0a, 0, &[0]Arg{}}},
    .{"end", .{0x0b, 0, &[0]Arg{}}},
    .{"br", .{0x0c, 0, &.{ .index }}},
    .{"br_if", .{0x0d, 0, &.{ .index }}},
    .{"br_table", .{0x0e, 0, &.{ .index_vector }}},
    .{"return", .{0x0f, 0, &[0]Arg{}}},
    .{"call", .{0x10, 0, &.{ .index }}},
    .{"call_indirect", .{0x11, 0, &.{ .index, .index }}},
    .{"return_call", .{0x12, 0, &[0]Arg{}}},
    .{"return_call_indirect", .{0x13, 0, &[0]Arg{}}},
    .{"call_ref", .{0x14, 0, &[0]Arg{}}},
    .{"delegate", .{0x18, 0, &[0]Arg{}}},
    .{"catch_all", .{0x19, 0, &[0]Arg{}}},
    .{"drop", .{0x1a, 0, &[0]Arg{}}},
    .{"select", .{0x1c, 0, &.{ .valtype_vector }}},
    .{"try_table", .{0x1f, 0, &[0]Arg{}}},
    .{"local.get", .{0x20, 0, &.{ .index }}},
    .{"local.set", .{0x21, 0, &.{ .index }}},
    .{"local.tee", .{0x22, 0, &.{ .index }}},
    .{"global.get", .{0x23, 0, &.{ .index }}},
    .{"global.set", .{0x24, 0, &.{ .index }}},
    .{"i32.load", .{0x28, 0, &.{ .index, .index }}},
    .{"i64.load", .{0x29, 0, &.{ .index, .index }}},
    .{"f32.load", .{0x2a, 0, &.{ .index, .index }}},
    .{"f64.load", .{0x2b, 0, &.{ .index, .index }}},
    .{"i32.load8_s", .{0x2c, 0, &.{ .index, .index }}},
    .{"i32.load8_u", .{0x2d, 0, &.{ .index, .index }}},
    .{"i32.load16_s", .{0x2e, 0, &.{ .index, .index }}},
    .{"i32.load16_u", .{0x2f, 0, &.{ .index, .index }}},
    .{"i64.load8_s", .{0x30, 0, &.{ .index, .index }}},
    .{"i64.load8_u", .{0x31, 0, &.{ .index, .index }}},
    .{"i64.load16_s", .{0x32, 0, &.{ .index, .index }}},
    .{"i64.load16_u", .{0x33, 0, &.{ .index, .index }}},
    .{"i64.load32_s", .{0x34, 0, &.{ .index, .index }}},
    .{"i64.load32_u", .{0x35, 0, &.{ .index, .index }}},
    .{"i32.store", .{0x36, 0, &.{ .index, .index }}},
    .{"i64.store", .{0x37, 0, &.{ .index, .index }}},
    .{"f32.store", .{0x38, 0, &.{ .index, .index }}},
    .{"f64.store", .{0x39, 0, &.{ .index, .index }}},
    .{"i32.store8", .{0x3a, 0, &.{ .index, .index }}},
    .{"i32.store16", .{0x3b, 0, &.{ .index, .index }}},
    .{"i64.store8", .{0x3c, 0, &.{ .index, .index }}},
    .{"i64.store16", .{0x3d, 0, &.{ .index, .index }}},
    .{"i64.store32", .{0x3e, 0, &.{ .index, .index }}},
    .{"memory.size", .{0x3f, 0, &[0]Arg{}}},
    .{"memory.grow", .{0x40, 0, &[0]Arg{}}},
    .{"i32.const", .{0x41, 0, &.{ .@"i32"}}},
    .{"i64.const", .{0x42, 0, &.{ .@"i64"}}},
    .{"f32.const", .{0x43, 0, &.{ .@"f32"}}},
    .{"f64.const", .{0x44, 0, &.{ .@"f64"}}},
    .{"i32.eqz", .{0x45, 0, &[0]Arg{}}},
    .{"i32.eq", .{0x46, 0, &[0]Arg{}}},
    .{"i32.ne", .{0x47, 0, &[0]Arg{}}},
    .{"i32.lt_s", .{0x48, 0, &[0]Arg{}}},
    .{"i32.lt_u", .{0x49, 0, &[0]Arg{}}},
    .{"i32.gt_s", .{0x4a, 0, &[0]Arg{}}},
    .{"i32.gt_u", .{0x4b, 0, &[0]Arg{}}},
    .{"i32.le_s", .{0x4c, 0, &[0]Arg{}}},
    .{"i32.le_u", .{0x4d, 0, &[0]Arg{}}},
    .{"i32.ge_s", .{0x4e, 0, &[0]Arg{}}},
    .{"i32.ge_u", .{0x4f, 0, &[0]Arg{}}},
    .{"i64.eqz", .{0x50, 0, &[0]Arg{}}},
    .{"i64.eq", .{0x51, 0, &[0]Arg{}}},
    .{"i64.ne", .{0x52, 0, &[0]Arg{}}},
    .{"i64.lt_s", .{0x53, 0, &[0]Arg{}}},
    .{"i64.lt_u", .{0x54, 0, &[0]Arg{}}},
    .{"i64.gt_s", .{0x55, 0, &[0]Arg{}}},
    .{"i64.gt_u", .{0x56, 0, &[0]Arg{}}},
    .{"i64.le_s", .{0x57, 0, &[0]Arg{}}},
    .{"i64.le_u", .{0x58, 0, &[0]Arg{}}},
    .{"i64.ge_s", .{0x59, 0, &[0]Arg{}}},
    .{"i64.ge_u", .{0x5a, 0, &[0]Arg{}}},
    .{"f32.eq", .{0x5b, 0, &[0]Arg{}}},
    .{"f32.ne", .{0x5c, 0, &[0]Arg{}}},
    .{"f32.lt", .{0x5d, 0, &[0]Arg{}}},
    .{"f32.gt", .{0x5e, 0, &[0]Arg{}}},
    .{"f32.le", .{0x5f, 0, &[0]Arg{}}},
    .{"f32.ge", .{0x60, 0, &[0]Arg{}}},
    .{"f64.eq", .{0x61, 0, &[0]Arg{}}},
    .{"f64.ne", .{0x62, 0, &[0]Arg{}}},
    .{"f64.lt", .{0x63, 0, &[0]Arg{}}},
    .{"f64.gt", .{0x64, 0, &[0]Arg{}}},
    .{"f64.le", .{0x65, 0, &[0]Arg{}}},
    .{"f64.ge", .{0x66, 0, &[0]Arg{}}},
    .{"i32.clz", .{0x67, 0, &[0]Arg{}}},
    .{"i32.ctz", .{0x68, 0, &[0]Arg{}}},
    .{"i32.popcnt", .{0x69, 0, &[0]Arg{}}},
    .{"i32.add", .{0x6a, 0, &[0]Arg{}}},
    .{"i32.sub", .{0x6b, 0, &[0]Arg{}}},
    .{"i32.mul", .{0x6c, 0, &[0]Arg{}}},
    .{"i32.div_s", .{0x6d, 0, &[0]Arg{}}},
    .{"i32.div_u", .{0x6e, 0, &[0]Arg{}}},
    .{"i32.rem_s", .{0x6f, 0, &[0]Arg{}}},
    .{"i32.rem_u", .{0x70, 0, &[0]Arg{}}},
    .{"i32.and", .{0x71, 0, &[0]Arg{}}},
    .{"i32.or", .{0x72, 0, &[0]Arg{}}},
    .{"i32.xor", .{0x73, 0, &[0]Arg{}}},
    .{"i32.shl", .{0x74, 0, &[0]Arg{}}},
    .{"i32.shr_s", .{0x75, 0, &[0]Arg{}}},
    .{"i32.shr_u", .{0x76, 0, &[0]Arg{}}},
    .{"i32.rotl", .{0x77, 0, &[0]Arg{}}},
    .{"i32.rotr", .{0x78, 0, &[0]Arg{}}},
    .{"i64.clz", .{0x79, 0, &[0]Arg{}}},
    .{"i64.ctz", .{0x7a, 0, &[0]Arg{}}},
    .{"i64.popcnt", .{0x7b, 0, &[0]Arg{}}},
    .{"i64.add", .{0x7c, 0, &[0]Arg{}}},
    .{"i64.sub", .{0x7d, 0, &[0]Arg{}}},
    .{"i64.mul", .{0x7e, 0, &[0]Arg{}}},
    .{"i64.div_s", .{0x7f, 0, &[0]Arg{}}},
    .{"i64.div_u", .{0x80, 0, &[0]Arg{}}},
    .{"i64.rem_s", .{0x81, 0, &[0]Arg{}}},
    .{"i64.rem_u", .{0x82, 0, &[0]Arg{}}},
    .{"i64.and", .{0x83, 0, &[0]Arg{}}},
    .{"i64.or", .{0x84, 0, &[0]Arg{}}},
    .{"i64.xor", .{0x85, 0, &[0]Arg{}}},
    .{"i64.shl", .{0x86, 0, &[0]Arg{}}},
    .{"i64.shr_s", .{0x87, 0, &[0]Arg{}}},
    .{"i64.shr_u", .{0x88, 0, &[0]Arg{}}},
    .{"i64.rotl", .{0x89, 0, &[0]Arg{}}},
    .{"i64.rotr", .{0x8a, 0, &[0]Arg{}}},
    .{"f32.abs", .{0x8b, 0, &[0]Arg{}}},
    .{"f32.neg", .{0x8c, 0, &[0]Arg{}}},
    .{"f32.ceil", .{0x8d, 0, &[0]Arg{}}},
    .{"f32.floor", .{0x8e, 0, &[0]Arg{}}},
    .{"f32.trunc", .{0x8f, 0, &[0]Arg{}}},
    .{"f32.nearest", .{0x90, 0, &[0]Arg{}}},
    .{"f32.sqrt", .{0x91, 0, &[0]Arg{}}},
    .{"f32.add", .{0x92, 0, &[0]Arg{}}},
    .{"f32.sub", .{0x93, 0, &[0]Arg{}}},
    .{"f32.mul", .{0x94, 0, &[0]Arg{}}},
    .{"f32.div", .{0x95, 0, &[0]Arg{}}},
    .{"f32.min", .{0x96, 0, &[0]Arg{}}},
    .{"f32.max", .{0x97, 0, &[0]Arg{}}},
    .{"f32.copysign", .{0x98, 0, &[0]Arg{}}},
    .{"f64.abs", .{0x99, 0, &[0]Arg{}}},
    .{"f64.neg", .{0x9a, 0, &[0]Arg{}}},
    .{"f64.ceil", .{0x9b, 0, &[0]Arg{}}},
    .{"f64.floor", .{0x9c, 0, &[0]Arg{}}},
    .{"f64.trunc", .{0x9d, 0, &[0]Arg{}}},
    .{"f64.nearest", .{0x9e, 0, &[0]Arg{}}},
    .{"f64.sqrt", .{0x9f, 0, &[0]Arg{}}},
    .{"f64.add", .{0xa0, 0, &[0]Arg{}}},
    .{"f64.sub", .{0xa1, 0, &[0]Arg{}}},
    .{"f64.mul", .{0xa2, 0, &[0]Arg{}}},
    .{"f64.div", .{0xa3, 0, &[0]Arg{}}},
    .{"f64.min", .{0xa4, 0, &[0]Arg{}}},
    .{"f64.max", .{0xa5, 0, &[0]Arg{}}},
    .{"f64.copysign", .{0xa6, 0, &[0]Arg{}}},
    .{"i32.wrap_i64", .{0xa7, 0, &[0]Arg{}}},
    .{"i32.trunc_f32_s", .{0xa8, 0, &[0]Arg{}}},
    .{"i32.trunc_f32_u", .{0xa9, 0, &[0]Arg{}}},
    .{"i32.trunc_f64_s", .{0xaa, 0, &[0]Arg{}}},
    .{"i32.trunc_f64_u", .{0xab, 0, &[0]Arg{}}},
    .{"i64.extend_i32_s", .{0xac, 0, &[0]Arg{}}},
    .{"i64.extend_i32_u", .{0xad, 0, &[0]Arg{}}},
    .{"i64.trunc_f32_s", .{0xae, 0, &[0]Arg{}}},
    .{"i64.trunc_f32_u", .{0xaf, 0, &[0]Arg{}}},
    .{"i64.trunc_f64_s", .{0xb0, 0, &[0]Arg{}}},
    .{"i64.trunc_f64_u", .{0xb1, 0, &[0]Arg{}}},
    .{"f32.convert_i32_s", .{0xb2, 0, &[0]Arg{}}},
    .{"f32.convert_i32_u", .{0xb3, 0, &[0]Arg{}}},
    .{"f32.convert_i64_s", .{0xb4, 0, &[0]Arg{}}},
    .{"f32.convert_i64_u", .{0xb5, 0, &[0]Arg{}}},
    .{"f32.demote_f64", .{0xb6, 0, &[0]Arg{}}},
    .{"f64.convert_i32_s", .{0xb7, 0, &[0]Arg{}}},
    .{"f64.convert_i32_u", .{0xb8, 0, &[0]Arg{}}},
    .{"f64.convert_i64_s", .{0xb9, 0, &[0]Arg{}}},
    .{"f64.convert_i64_u", .{0xba, 0, &[0]Arg{}}},
    .{"f64.promote_f32", .{0xbb, 0, &[0]Arg{}}},
    .{"i32.reinterpret_f32", .{0xbc, 0, &[0]Arg{}}},
    .{"i64.reinterpret_f64", .{0xbd, 0, &[0]Arg{}}},
    .{"f32.reinterpret_i32", .{0xbe, 0, &[0]Arg{}}},
    .{"f64.reinterpret_i64", .{0xbf, 0, &[0]Arg{}}},
    .{"i32.extend8_s", .{0xC0, 0, &[0]Arg{}}},
    .{"i32.extend16_s", .{0xC1, 0, &[0]Arg{}}},
    .{"i64.extend8_s", .{0xC2, 0, &[0]Arg{}}},
    .{"i64.extend16_s", .{0xC3, 0, &[0]Arg{}}},
    .{"i64.extend32_s", .{0xC4, 0, &[0]Arg{}}},
    .{"alloca", .{0xe0, 0, &[0]Arg{}}},
    .{"br_unless", .{0xe1, 0, &[0]Arg{}}},
    .{"call_import", .{0xe2, 0, &[0]Arg{}}},
    .{"data", .{0xe3, 0, &[0]Arg{}}},
    .{"drop_keep", .{0xe4, 0, &[0]Arg{}}},
    .{"catch_drop", .{0xe5, 0, &[0]Arg{}}},
    .{"adjust_frame_for_return_call", .{0xe6, 0, &[0]Arg{}}},
    .{"global.get.ref", .{0xe7, 0, &[0]Arg{}}},
    .{"local.get.ref", .{0xe9, 0, &[0]Arg{}}},
    .{"mark_ref", .{0xea, 0, &[0]Arg{}}},
    .{"i32.trunc_sat_f32_s", .{0x00, 0xfc, &[0]Arg{}}},
    .{"i32.trunc_sat_f32_u", .{0x01, 0xfc, &[0]Arg{}}},
    .{"i32.trunc_sat_f64_s", .{0x02, 0xfc, &[0]Arg{}}},
    .{"i32.trunc_sat_f64_u", .{0x03, 0xfc, &[0]Arg{}}},
    .{"i64.trunc_sat_f32_s", .{0x04, 0xfc, &[0]Arg{}}},
    .{"i64.trunc_sat_f32_u", .{0x05, 0xfc, &[0]Arg{}}},
    .{"i64.trunc_sat_f64_s", .{0x06, 0xfc, &[0]Arg{}}},
    .{"i64.trunc_sat_f64_u", .{0x07, 0xfc, &[0]Arg{}}},
    .{"memory.init", .{0x08, 0xfc, &[0]Arg{}}},
    .{"data.drop", .{0x09, 0xfc, &[0]Arg{}}},
    .{"memory.copy", .{0x0a, 0xfc, &[0]Arg{}}},
    .{"memory.fill", .{0x0b, 0xfc, &[0]Arg{}}},
    .{"table.init", .{0x0c, 0xfc, &.{ .index, .index }}},
    .{"elem.drop", .{0x0d, 0xfc, &[0]Arg{}}},
    .{"table.copy", .{0x0e, 0xfc, &.{ .index, .index }}},
    .{"table.get", .{0x25, 0, &.{ .index }}},
    .{"table.set", .{0x26, 0, &.{ .index }}},
    .{"table.grow", .{0x0f, 0xfc, &.{ .index }}},
    .{"table.size", .{0x10, 0xfc, &.{ .index }}},
    .{"table.fill", .{0x11, 0xfc, &.{ .index }}},
    .{"ref.&[0]Arg{}", .{0xd0, 0, &.{ .reftype }}},
    .{"ref.is_&[0]Arg{}", .{0xd1, 0, &[0]Arg{}}},
    .{"ref.func", .{0xd2, 0, &.{ .index }}},
    .{"v128.load", .{0x00, 0xfd, &.{ .index, .index }}},
    .{"v128.load8x8_s", .{0x01, 0xfd, &.{ .index, .index }}},
    .{"v128.load8x8_u", .{0x02, 0xfd, &.{ .index, .index }}},
    .{"v128.load16x4_s", .{0x03, 0xfd, &.{ .index, .index }}},
    .{"v128.load16x4_u", .{0x04, 0xfd, &.{ .index, .index }}},
    .{"v128.load32x2_s", .{0x05, 0xfd, &.{ .index, .index }}},
    .{"v128.load32x2_u", .{0x06, 0xfd, &.{ .index, .index }}},
    .{"v128.load8_splat", .{0x07, 0xfd, &.{ .index, .index }}},
    .{"v128.load16_splat", .{0x08, 0xfd, &.{ .index, .index }}},
    .{"v128.load32_splat", .{0x09, 0xfd, &.{ .index, .index }}},
    .{"v128.load64_splat", .{0x0a, 0xfd, &.{ .index, .index }}},
    .{"v128.store", .{0x0b, 0xfd, &.{ .index, .index }}},
    .{"v128.const", .{0x0c, 0xfd, &(.{ .byte } ** 16)}},
    .{"i8x16.shuffle", .{0x0d, 0xfd, &(.{ .byte } ** 16)}},
    .{"i8x16.swizzle", .{0x0e, 0xfd, &[0]Arg{}}},
    .{"i8x16.splat", .{0x0f, 0xfd, &[0]Arg{}}},
    .{"i16x8.splat", .{0x10, 0xfd, &[0]Arg{}}},
    .{"i32x4.splat", .{0x11, 0xfd, &[0]Arg{}}},
    .{"i64x2.splat", .{0x12, 0xfd, &[0]Arg{}}},
    .{"f32x4.splat", .{0x13, 0xfd, &[0]Arg{}}},
    .{"f64x2.splat", .{0x14, 0xfd, &[0]Arg{}}},
    .{"i8x16.extract_lane_s", .{0x15, 0xfd, &.{ .byte }}},
    .{"i8x16.extract_lane_u", .{0x16, 0xfd, &.{ .byte }}},
    .{"i8x16.replace_lane", .{0x17, 0xfd, &.{ .byte }}},
    .{"i16x8.extract_lane_s", .{0x18, 0xfd, &.{ .byte }}},
    .{"i16x8.extract_lane_u", .{0x19, 0xfd, &.{ .byte }}},
    .{"i16x8.replace_lane", .{0x1a, 0xfd, &.{ .byte }}},
    .{"i32x4.extract_lane", .{0x1b, 0xfd, &.{ .byte }}},
    .{"i32x4.replace_lane", .{0x1c, 0xfd, &.{ .byte }}},
    .{"i64x2.extract_lane", .{0x1d, 0xfd, &.{ .byte }}},
    .{"i64x2.replace_lane", .{0x1e, 0xfd, &.{ .byte }}},
    .{"f32x4.extract_lane", .{0x1f, 0xfd, &.{ .byte }}},
    .{"f32x4.replace_lane", .{0x20, 0xfd, &.{ .byte }}},
    .{"f64x2.extract_lane", .{0x21, 0xfd, &.{ .byte }}},
    .{"f64x2.replace_lane", .{0x22, 0xfd, &.{ .byte }}},
    .{"i8x16.eq", .{0x23, 0xfd, &[0]Arg{}}},
    .{"i8x16.ne", .{0x24, 0xfd, &[0]Arg{}}},
    .{"i8x16.lt_s", .{0x25, 0xfd, &[0]Arg{}}},
    .{"i8x16.lt_u", .{0x26, 0xfd, &[0]Arg{}}},
    .{"i8x16.gt_s", .{0x27, 0xfd, &[0]Arg{}}},
    .{"i8x16.gt_u", .{0x28, 0xfd, &[0]Arg{}}},
    .{"i8x16.le_s", .{0x29, 0xfd, &[0]Arg{}}},
    .{"i8x16.le_u", .{0x2a, 0xfd, &[0]Arg{}}},
    .{"i8x16.ge_s", .{0x2b, 0xfd, &[0]Arg{}}},
    .{"i8x16.ge_u", .{0x2c, 0xfd, &[0]Arg{}}},
    .{"i16x8.eq", .{0x2d, 0xfd, &[0]Arg{}}},
    .{"i16x8.ne", .{0x2e, 0xfd, &[0]Arg{}}},
    .{"i16x8.lt_s", .{0x2f, 0xfd, &[0]Arg{}}},
    .{"i16x8.lt_u", .{0x30, 0xfd, &[0]Arg{}}},
    .{"i16x8.gt_s", .{0x31, 0xfd, &[0]Arg{}}},
    .{"i16x8.gt_u", .{0x32, 0xfd, &[0]Arg{}}},
    .{"i16x8.le_s", .{0x33, 0xfd, &[0]Arg{}}},
    .{"i16x8.le_u", .{0x34, 0xfd, &[0]Arg{}}},
    .{"i16x8.ge_s", .{0x35, 0xfd, &[0]Arg{}}},
    .{"i16x8.ge_u", .{0x36, 0xfd, &[0]Arg{}}},
    .{"i32x4.eq", .{0x37, 0xfd, &[0]Arg{}}},
    .{"i32x4.ne", .{0x38, 0xfd, &[0]Arg{}}},
    .{"i32x4.lt_s", .{0x39, 0xfd, &[0]Arg{}}},
    .{"i32x4.lt_u", .{0x3a, 0xfd, &[0]Arg{}}},
    .{"i32x4.gt_s", .{0x3b, 0xfd, &[0]Arg{}}},
    .{"i32x4.gt_u", .{0x3c, 0xfd, &[0]Arg{}}},
    .{"i32x4.le_s", .{0x3d, 0xfd, &[0]Arg{}}},
    .{"i32x4.le_u", .{0x3e, 0xfd, &[0]Arg{}}},
    .{"i32x4.ge_s", .{0x3f, 0xfd, &[0]Arg{}}},
    .{"i32x4.ge_u", .{0x40, 0xfd, &[0]Arg{}}},
    .{"f32x4.eq", .{0x41, 0xfd, &[0]Arg{}}},
    .{"f32x4.ne", .{0x42, 0xfd, &[0]Arg{}}},
    .{"f32x4.lt", .{0x43, 0xfd, &[0]Arg{}}},
    .{"f32x4.gt", .{0x44, 0xfd, &[0]Arg{}}},
    .{"f32x4.le", .{0x45, 0xfd, &[0]Arg{}}},
    .{"f32x4.ge", .{0x46, 0xfd, &[0]Arg{}}},
    .{"f64x2.eq", .{0x47, 0xfd, &[0]Arg{}}},
    .{"f64x2.ne", .{0x48, 0xfd, &[0]Arg{}}},
    .{"f64x2.lt", .{0x49, 0xfd, &[0]Arg{}}},
    .{"f64x2.gt", .{0x4a, 0xfd, &[0]Arg{}}},
    .{"f64x2.le", .{0x4b, 0xfd, &[0]Arg{}}},
    .{"f64x2.ge", .{0x4c, 0xfd, &[0]Arg{}}},
    .{"v128.not", .{0x4d, 0xfd, &[0]Arg{}}},
    .{"v128.and", .{0x4e, 0xfd, &[0]Arg{}}},
    .{"v128.andnot", .{0x4f, 0xfd, &[0]Arg{}}},
    .{"v128.or", .{0x50, 0xfd, &[0]Arg{}}},
    .{"v128.xor", .{0x51, 0xfd, &[0]Arg{}}},
    .{"v128.bitselect", .{0x52, 0xfd, &[0]Arg{}}},
    .{"v128.any_true", .{0x53, 0xfd, &[0]Arg{}}},
    .{"v128.load8_lane", .{0x54, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.load16_lane", .{0x55, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.load32_lane", .{0x56, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.load64_lane", .{0x57, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.store8_lane", .{0x58, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.store16_lane", .{0x59, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.store32_lane", .{0x5a, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.store64_lane", .{0x5b, 0xfd, &.{ .index, .index, .byte }}},
    .{"v128.load32_zero", .{0x5c, 0xfd, &.{ .index, .index }}},
    .{"v128.load64_zero", .{0x5d, 0xfd, &.{ .index, .index }}},
    .{"f32x4.demote_f64x2_zero", .{0x5e, 0xfd, &[0]Arg{}}},
    .{"f64x2.promote_low_f32x4", .{0x5f, 0xfd, &[0]Arg{}}},
    .{"i8x16.abs", .{0x60, 0xfd, &[0]Arg{}}},
    .{"i8x16.neg", .{0x61, 0xfd, &[0]Arg{}}},
    .{"i8x16.popcnt", .{0x62, 0xfd, &[0]Arg{}}},
    .{"i8x16.all_true", .{0x63, 0xfd, &[0]Arg{}}},
    .{"i8x16.bitmask", .{0x64, 0xfd, &[0]Arg{}}},
    .{"i8x16.narrow_i16x8_s", .{0x65, 0xfd, &[0]Arg{}}},
    .{"i8x16.narrow_i16x8_u", .{0x66, 0xfd, &[0]Arg{}}},
    .{"i8x16.shl", .{0x6b, 0xfd, &[0]Arg{}}},
    .{"i8x16.shr_s", .{0x6c, 0xfd, &[0]Arg{}}},
    .{"i8x16.shr_u", .{0x6d, 0xfd, &[0]Arg{}}},
    .{"i8x16.add", .{0x6e, 0xfd, &[0]Arg{}}},
    .{"i8x16.add_sat_s", .{0x6f, 0xfd, &[0]Arg{}}},
    .{"i8x16.add_sat_u", .{0x70, 0xfd, &[0]Arg{}}},
    .{"i8x16.sub", .{0x71, 0xfd, &[0]Arg{}}},
    .{"i8x16.sub_sat_s", .{0x72, 0xfd, &[0]Arg{}}},
    .{"i8x16.sub_sat_u", .{0x73, 0xfd, &[0]Arg{}}},
    .{"i8x16.min_s", .{0x76, 0xfd, &[0]Arg{}}},
    .{"i8x16.min_u", .{0x77, 0xfd, &[0]Arg{}}},
    .{"i8x16.max_s", .{0x78, 0xfd, &[0]Arg{}}},
    .{"i8x16.max_u", .{0x79, 0xfd, &[0]Arg{}}},
    .{"i8x16.avgr_u", .{0x7b, 0xfd, &[0]Arg{}}},
    .{"i16x8.extadd_pairwise_i8x16_s", .{0x7c, 0xfd, &[0]Arg{}}},
    .{"i16x8.extadd_pairwise_i8x16_u", .{0x7d, 0xfd, &[0]Arg{}}},
    .{"i32x4.extadd_pairwise_i16x8_s", .{0x7e, 0xfd, &[0]Arg{}}},
    .{"i32x4.extadd_pairwise_i16x8_u", .{0x7f, 0xfd, &[0]Arg{}}},
    .{"i16x8.abs", .{0x80, 0xfd, &[0]Arg{}}},
    .{"i16x8.neg", .{0x81, 0xfd, &[0]Arg{}}},
    .{"i16x8.q15mulr_sat_s", .{0x82, 0xfd, &[0]Arg{}}},
    .{"i16x8.all_true", .{0x83, 0xfd, &[0]Arg{}}},
    .{"i16x8.bitmask", .{0x84, 0xfd, &[0]Arg{}}},
    .{"i16x8.narrow_i32x4_s", .{0x85, 0xfd, &[0]Arg{}}},
    .{"i16x8.narrow_i32x4_u", .{0x86, 0xfd, &[0]Arg{}}},
    .{"i16x8.extend_low_i8x16_s", .{0x87, 0xfd, &[0]Arg{}}},
    .{"i16x8.extend_high_i8x16_s", .{0x88, 0xfd, &[0]Arg{}}},
    .{"i16x8.extend_low_i8x16_u", .{0x89, 0xfd, &[0]Arg{}}},
    .{"i16x8.extend_high_i8x16_u", .{0x8a, 0xfd, &[0]Arg{}}},
    .{"i16x8.shl", .{0x8b, 0xfd, &[0]Arg{}}},
    .{"i16x8.shr_s", .{0x8c, 0xfd, &[0]Arg{}}},
    .{"i16x8.shr_u", .{0x8d, 0xfd, &[0]Arg{}}},
    .{"i16x8.add", .{0x8e, 0xfd, &[0]Arg{}}},
    .{"i16x8.add_sat_s", .{0x8f, 0xfd, &[0]Arg{}}},
    .{"i16x8.add_sat_u", .{0x90, 0xfd, &[0]Arg{}}},
    .{"i16x8.sub", .{0x91, 0xfd, &[0]Arg{}}},
    .{"i16x8.sub_sat_s", .{0x92, 0xfd, &[0]Arg{}}},
    .{"i16x8.sub_sat_u", .{0x93, 0xfd, &[0]Arg{}}},
    .{"i16x8.mul", .{0x95, 0xfd, &[0]Arg{}}},
    .{"i16x8.min_s", .{0x96, 0xfd, &[0]Arg{}}},
    .{"i16x8.min_u", .{0x97, 0xfd, &[0]Arg{}}},
    .{"i16x8.max_s", .{0x98, 0xfd, &[0]Arg{}}},
    .{"i16x8.max_u", .{0x99, 0xfd, &[0]Arg{}}},
    .{"i16x8.avgr_u", .{0x9b, 0xfd, &[0]Arg{}}},
    .{"i16x8.extmul_low_i8x16_s", .{0x9c, 0xfd, &[0]Arg{}}},
    .{"i16x8.extmul_high_i8x16_s", .{0x9d, 0xfd, &[0]Arg{}}},
    .{"i16x8.extmul_low_i8x16_u", .{0x9e, 0xfd, &[0]Arg{}}},
    .{"i16x8.extmul_high_i8x16_u", .{0x9f, 0xfd, &[0]Arg{}}},
    .{"i32x4.abs", .{0xa0, 0xfd, &[0]Arg{}}},
    .{"i32x4.neg", .{0xa1, 0xfd, &[0]Arg{}}},
    .{"i32x4.all_true", .{0xa3, 0xfd, &[0]Arg{}}},
    .{"i32x4.bitmask", .{0xa4, 0xfd, &[0]Arg{}}},
    .{"i32x4.extend_low_i16x8_s", .{0xa7, 0xfd, &[0]Arg{}}},
    .{"i32x4.extend_high_i16x8_s", .{0xa8, 0xfd, &[0]Arg{}}},
    .{"i32x4.extend_low_i16x8_u", .{0xa9, 0xfd, &[0]Arg{}}},
    .{"i32x4.extend_high_i16x8_u", .{0xaa, 0xfd, &[0]Arg{}}},
    .{"i32x4.shl", .{0xab, 0xfd, &[0]Arg{}}},
    .{"i32x4.shr_s", .{0xac, 0xfd, &[0]Arg{}}},
    .{"i32x4.shr_u", .{0xad, 0xfd, &[0]Arg{}}},
    .{"i32x4.add", .{0xae, 0xfd, &[0]Arg{}}},
    .{"i32x4.sub", .{0xb1, 0xfd, &[0]Arg{}}},
    .{"i32x4.mul", .{0xb5, 0xfd, &[0]Arg{}}},
    .{"i32x4.min_s", .{0xb6, 0xfd, &[0]Arg{}}},
    .{"i32x4.min_u", .{0xb7, 0xfd, &[0]Arg{}}},
    .{"i32x4.max_s", .{0xb8, 0xfd, &[0]Arg{}}},
    .{"i32x4.max_u", .{0xb9, 0xfd, &[0]Arg{}}},
    .{"i32x4.dot_i16x8_s", .{0xba, 0xfd, &[0]Arg{}}},
    .{"i32x4.extmul_low_i16x8_s", .{0xbc, 0xfd, &[0]Arg{}}},
    .{"i32x4.extmul_high_i16x8_s", .{0xbd, 0xfd, &[0]Arg{}}},
    .{"i32x4.extmul_low_i16x8_u", .{0xbe, 0xfd, &[0]Arg{}}},
    .{"i32x4.extmul_high_i16x8_u", .{0xbf, 0xfd, &[0]Arg{}}},
    .{"i64x2.abs", .{0xc0, 0xfd, &[0]Arg{}}},
    .{"i64x2.neg", .{0xc1, 0xfd, &[0]Arg{}}},
    .{"i64x2.all_true", .{0xc3, 0xfd, &[0]Arg{}}},
    .{"i64x2.bitmask", .{0xc4, 0xfd, &[0]Arg{}}},
    .{"i64x2.extend_low_i32x4_s", .{0xc7, 0xfd, &[0]Arg{}}},
    .{"i64x2.extend_high_i32x4_s", .{0xc8, 0xfd, &[0]Arg{}}},
    .{"i64x2.extend_low_i32x4_u", .{0xc9, 0xfd, &[0]Arg{}}},
    .{"i64x2.extend_high_i32x4_u", .{0xca, 0xfd, &[0]Arg{}}},
    .{"i64x2.shl", .{0xcb, 0xfd, &[0]Arg{}}},
    .{"i64x2.shr_s", .{0xcc, 0xfd, &[0]Arg{}}},
    .{"i64x2.shr_u", .{0xcd, 0xfd, &[0]Arg{}}},
    .{"i64x2.add", .{0xce, 0xfd, &[0]Arg{}}},
    .{"i64x2.sub", .{0xd1, 0xfd, &[0]Arg{}}},
    .{"i64x2.mul", .{0xd5, 0xfd, &[0]Arg{}}},
    .{"i64x2.eq", .{0xd6, 0xfd, &[0]Arg{}}},
    .{"i64x2.ne", .{0xd7, 0xfd, &[0]Arg{}}},
    .{"i64x2.lt_s", .{0xd8, 0xfd, &[0]Arg{}}},
    .{"i64x2.gt_s", .{0xd9, 0xfd, &[0]Arg{}}},
    .{"i64x2.le_s", .{0xda, 0xfd, &[0]Arg{}}},
    .{"i64x2.ge_s", .{0xdb, 0xfd, &[0]Arg{}}},
    .{"i64x2.extmul_low_i32x4_s", .{0xdc, 0xfd, &[0]Arg{}}},
    .{"i64x2.extmul_high_i32x4_s", .{0xdd, 0xfd, &[0]Arg{}}},
    .{"i64x2.extmul_low_i32x4_u", .{0xde, 0xfd, &[0]Arg{}}},
    .{"i64x2.extmul_high_i32x4_u", .{0xdf, 0xfd, &[0]Arg{}}},
    .{"f32x4.ceil", .{0x67, 0xfd, &[0]Arg{}}},
    .{"f32x4.floor", .{0x68, 0xfd, &[0]Arg{}}},
    .{"f32x4.trunc", .{0x69, 0xfd, &[0]Arg{}}},
    .{"f32x4.nearest", .{0x6a, 0xfd, &[0]Arg{}}},
    .{"f64x2.ceil", .{0x74, 0xfd, &[0]Arg{}}},
    .{"f64x2.floor", .{0x75, 0xfd, &[0]Arg{}}},
    .{"f64x2.trunc", .{0x7a, 0xfd, &[0]Arg{}}},
    .{"f64x2.nearest", .{0x94, 0xfd, &[0]Arg{}}},
    .{"f32x4.abs", .{0xe0, 0xfd, &[0]Arg{}}},
    .{"f32x4.neg", .{0xe1, 0xfd, &[0]Arg{}}},
    .{"f32x4.sqrt", .{0xe3, 0xfd, &[0]Arg{}}},
    .{"f32x4.add", .{0xe4, 0xfd, &[0]Arg{}}},
    .{"f32x4.sub", .{0xe5, 0xfd, &[0]Arg{}}},
    .{"f32x4.mul", .{0xe6, 0xfd, &[0]Arg{}}},
    .{"f32x4.div", .{0xe7, 0xfd, &[0]Arg{}}},
    .{"f32x4.min", .{0xe8, 0xfd, &[0]Arg{}}},
    .{"f32x4.max", .{0xe9, 0xfd, &[0]Arg{}}},
    .{"f32x4.pmin", .{0xea, 0xfd, &[0]Arg{}}},
    .{"f32x4.pmax", .{0xeb, 0xfd, &[0]Arg{}}},
    .{"f64x2.abs", .{0xec, 0xfd, &[0]Arg{}}},
    .{"f64x2.neg", .{0xed, 0xfd, &[0]Arg{}}},
    .{"f64x2.sqrt", .{0xef, 0xfd, &[0]Arg{}}},
    .{"f64x2.add", .{0xf0, 0xfd, &[0]Arg{}}},
    .{"f64x2.sub", .{0xf1, 0xfd, &[0]Arg{}}},
    .{"f64x2.mul", .{0xf2, 0xfd, &[0]Arg{}}},
    .{"f64x2.div", .{0xf3, 0xfd, &[0]Arg{}}},
    .{"f64x2.min", .{0xf4, 0xfd, &[0]Arg{}}},
    .{"f64x2.max", .{0xf5, 0xfd, &[0]Arg{}}},
    .{"f64x2.pmin", .{0xf6, 0xfd, &[0]Arg{}}},
    .{"f64x2.pmax", .{0xf7, 0xfd, &[0]Arg{}}},
    .{"i32x4.trunc_sat_f32x4_s", .{0xf8, 0xfd, &[0]Arg{}}},
    .{"i32x4.trunc_sat_f32x4_u", .{0xf9, 0xfd, &[0]Arg{}}},
    .{"f32x4.convert_i32x4_s", .{0xfa, 0xfd, &[0]Arg{}}},
    .{"f32x4.convert_i32x4_u", .{0xfb, 0xfd, &[0]Arg{}}},
    .{"i32x4.trunc_sat_f64x2_s_zero", .{0xfc, 0xfd, &[0]Arg{}}},
    .{"i32x4.trunc_sat_f64x2_u_zero", .{0xfd, 0xfd, &[0]Arg{}}},
    .{"f64x2.convert_low_i32x4_s", .{0xfe, 0xfd, &[0]Arg{}}},
    .{"f64x2.convert_low_i32x4_u", .{0xff, 0xfd, &[0]Arg{}}},
    .{"i8x16.relaxed_swizzle", .{0x100, 0xfd, &[0]Arg{}}},
    .{"i32x4.relaxed_trunc_f32x4_s", .{0x101, 0xfd, &[0]Arg{}}},
    .{"i32x4.relaxed_trunc_f32x4_u", .{0x102, 0xfd, &[0]Arg{}}},
    .{"i32x4.relaxed_trunc_f64x2_s_zero", .{0x103, 0xfd, &[0]Arg{}}},
    .{"i32x4.relaxed_trunc_f64x2_u_zero", .{0x104, 0xfd, &[0]Arg{}}},
    .{"f32x4.relaxed_madd", .{0x105, 0xfd, &[0]Arg{}}},
    .{"f32x4.relaxed_nmadd", .{0x106, 0xfd, &[0]Arg{}}},
    .{"f64x2.relaxed_madd", .{0x107, 0xfd, &[0]Arg{}}},
    .{"f64x2.relaxed_nmadd", .{0x108, 0xfd, &[0]Arg{}}},
    .{"i8x16.relaxed_laneselect", .{0x109, 0xfd, &[0]Arg{}}},
    .{"i16x8.relaxed_laneselect", .{0x10a, 0xfd, &[0]Arg{}}},
    .{"i32x4.relaxed_laneselect", .{0x10b, 0xfd, &[0]Arg{}}},
    .{"i64x2.relaxed_laneselect", .{0x10c, 0xfd, &[0]Arg{}}},
    .{"f32x4.relaxed_min", .{0x10d, 0xfd, &[0]Arg{}}},
    .{"f32x4.relaxed_max", .{0x10e, 0xfd, &[0]Arg{}}},
    .{"f64x2.relaxed_min", .{0x10f, 0xfd, &[0]Arg{}}},
    .{"f64x2.relaxed_max", .{0x110, 0xfd, &[0]Arg{}}},
    .{"i16x8.relaxed_q15mulr_s", .{0x111, 0xfd, &[0]Arg{}}},
    .{"i16x8.relaxed_dot_i8x16_i7x16_s", .{0x112, 0xfd, &[0]Arg{}}},
    .{"i32x4.relaxed_dot_i8x16_i7x16_add_s", .{0x113, 0xfd, &[0]Arg{}}},
    .{"memory.atomic.notify", .{0x00, 0xfe, &[0]Arg{}}},
    .{"memory.atomic.wait32", .{0x01, 0xfe, &[0]Arg{}}},
    .{"memory.atomic.wait64", .{0x02, 0xfe, &[0]Arg{}}},
    .{"atomic.fence", .{0x03, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.load", .{0x10, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.load", .{0x11, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.load8_u", .{0x12, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.load16_u", .{0x13, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.load8_u", .{0x14, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.load16_u", .{0x15, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.load32_u", .{0x16, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.store", .{0x17, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.store", .{0x18, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.store8", .{0x19, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.store16", .{0x1a, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.store8", .{0x1b, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.store16", .{0x1c, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.store32", .{0x1d, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw.add", .{0x1e, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw.add", .{0x1f, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw8.add_u", .{0x20, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw16.add_u", .{0x21, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw8.add_u", .{0x22, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw16.add_u", .{0x23, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw32.add_u", .{0x24, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw.sub", .{0x25, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw.sub", .{0x26, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw8.sub_u", .{0x27, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw16.sub_u", .{0x28, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw8.sub_u", .{0x29, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw16.sub_u", .{0x2a, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw32.sub_u", .{0x2b, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw.and", .{0x2c, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw.and", .{0x2d, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw8.and_u", .{0x2e, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw16.and_u", .{0x2f, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw8.and_u", .{0x30, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw16.and_u", .{0x31, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw32.and_u", .{0x32, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw.or", .{0x33, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw.or", .{0x34, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw8.or_u", .{0x35, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw16.or_u", .{0x36, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw8.or_u", .{0x37, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw16.or_u", .{0x38, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw32.or_u", .{0x39, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw.xor", .{0x3a, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw.xor", .{0x3b, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw8.xor_u", .{0x3c, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw16.xor_u", .{0x3d, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw8.xor_u", .{0x3e, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw16.xor_u", .{0x3f, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw32.xor_u", .{0x40, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw.xchg", .{0x41, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw.xchg", .{0x42, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw8.xchg_u", .{0x43, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw16.xchg_u", .{0x44, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw8.xchg_u", .{0x45, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw16.xchg_u", .{0x46, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw32.xchg_u", .{0x47, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw.cmpxchg", .{0x48, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw.cmpxchg", .{0x49, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw8.cmpxchg_u", .{0x4a, 0xfe, &[0]Arg{}}},
    .{"i32.atomic.rmw16.cmpxchg_u", .{0x4b, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw8.cmpxchg_u", .{0x4c, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw16.cmpxchg_u", .{0x4d, 0xfe, &[0]Arg{}}},
    .{"i64.atomic.rmw32.cmpxchg_u", .{0x4e, 0xfe, &[0]Arg{}}},
});

pub const Valtype = enum(u8) {
    @"i32" = 0x7F,
    @"i64" = 0x7E,
    @"f32" = 0x7D,
    @"f64" = 0x7C,
    v128 = 0x7B,
    funcref = 0x70,
    externref = 0x6F,
};

pub const Section = enum(u8) {
    // custom = 0,
    type = 1,
    import = 2,
    function = 3,
    // table = 4,
    memory = 5,
    global = 6,
    @"export" = 7,
    start = 8,
    // element = 9,
    code = 10,
    data = 11,
    datacount = 12,
};

pub const ImportDesc = enum(u8) {
    func,
    table,
    mem,
    global,
};
pub const ExportDesc = ImportDesc;

pub const Reftype = enum(u8) {
    funcref = 0x70,
    externref = 0x6F,
};

pub fn readNext(reader: anytype, buffer: []u8) ?[]u8 {
    var index: usize = 0;
    while (reader.readByte()) |byte| {
        switch (byte) {
            '\n', ' ' => if (index == 0) continue else break,
            else => {
                buffer[index] = byte;
                index += 1;
            },
        }
    } else |_| {
        return null;
    }
    return buffer[0..index];
}

pub fn readNextSectionVariant(reader: anytype, read_buffer: []u8) ?Section {
    if (readNext(reader, read_buffer)) |section| {
        return std.meta.stringToEnum(Section, section);
    } else {
        return null;
    }
}

pub fn readNextInteger(T: type, reader: anytype, read_buffer: []u8) !T {
    const string = readNext(reader, read_buffer);
    return std.fmt.parseInt(T, string.?, 10);
}

pub fn readNextValtype(reader: anytype, read_buffer: []u8) ?Valtype {
    const string = readNext(reader, read_buffer);
    return std.meta.stringToEnum(Valtype, string.?);
}

pub fn readNextReftype(reader: anytype, read_buffer: []u8) ?Reftype {
    const string = readNext(reader, read_buffer);
    return std.meta.stringToEnum(Reftype, string.?);
}

pub fn writeInstruction(instruction: Inst, writer: anytype) !void {
    const prefix, const opcode, _ = instruction;
    if (opcode == 0) {
        try writer.writeByte(@intCast(prefix));
    } else {
        try writer.writeByte(opcode);
        try std.leb.writeUleb128(writer, prefix);
    }
}

pub fn readNextExpression(reader: anytype, read_buffer: []u8, writer: anytype) !void {
    var instruction = instructions.get(readNext(reader, read_buffer).?);

    while (instruction) |inst| {
        const prefix, const opcode, const args = inst;
        try writeInstruction(inst, writer);

        if (prefix == 0x0B and opcode == 0) {
            break;
        }

        for (args) |arg| {
            switch (arg) {
                .@"i32", .@"i64" => {
                    const number = try readNextInteger(i65, reader, read_buffer);
                    try std.leb.writeIleb128(writer, number);
                },
                .@"f32" => {
                    const string = readNext(reader, read_buffer).?;
                    const float = try std.fmt.parseFloat(f32, string);
                    try std.leb.writeIleb128(writer, @as(u32, @bitCast(float)));
                },
                .@"f64" => {
                    const string = readNext(reader, read_buffer).?;
                    const float = try std.fmt.parseFloat(f64, string);
                    try std.leb.writeIleb128(writer, @as(u64, @bitCast(float)));
                },
                .block => {
                    const number = try readNextInteger(u32, reader, read_buffer);

                    if (number == 0x40) {
                        try writer.writeByte(0x40);
                    } else if (std.meta.intToEnum(Valtype, number)) |valtype| {
                        try writer.writeByte(@intFromEnum(valtype));
                    } else |_| {
                        try std.leb.writeUleb128(writer, number);
                    }
                },
                .index => {
                    const index = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, index);
                },
                .index_vector => {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, count);

                    for (0..count) |_| {
                        const index = try readNextInteger(u32, reader, read_buffer);
                        try std.leb.writeUleb128(writer, index);
                    }
                },
                .valtype => {
                    const valtype = readNextValtype(reader, read_buffer).?;
                    try writer.writeByte(@intFromEnum(valtype));
                },
                .valtype_vector => {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, count);

                    for (0..count) |_| {
                        const valtype = readNextValtype(reader, read_buffer).?;
                        try writer.writeByte(@intFromEnum(valtype));
                    }
                },
                .reftype => {
                    const reftype = readNextReftype(reader, read_buffer).?;
                    try writer.writeByte(@intFromEnum(reftype));
                },
                .byte => {
                    const byte = try readNextInteger(u8, reader, read_buffer);
                    try writer.writeByte(byte);
                },
            }
        }

        instruction = instructions.get(readNext(reader, read_buffer).?);
    }
}

pub fn readNextString(reader: anytype, write_buffer: []u8) ![]u8 {
    const State = enum {
        normal,
        slash,
    };

    var stream = std.io.fixedBufferStream(write_buffer);
    const writer = stream.writer();

    var state = State.normal;
    _ = try reader.readByte();

    while (true) {
        const byte = try reader.readByte();
        switch (state) {
            .normal => switch (byte) {
                '\\' => state = .slash,
                '\"' => break,
                else => try writer.writeByte(byte),
            },
            .slash => switch (byte) {
                '\\', '\"' => {
                    try writer.writeByte(byte);
                    state = .normal;
                },
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    const second_byte = try reader.readByte();
                    const number = try std.fmt.parseInt(u8, &.{byte, second_byte}, 16);
                    try writer.writeByte(number);
                    state = .normal;
                },
                'n' => {
                    try writer.writeByte('\n');
                    state = .normal;
                },
                't' => {
                    try writer.writeByte('\t');
                    state = .normal;
                },
                else => unreachable,
            },
        }
    }

    return stream.getWritten();
}

pub fn readNextSection(allocator: std.mem.Allocator, section: Section, reader: anytype, read_buffer: []u8, write_buffer: []u8) ![]u8 {
    var stream = std.io.fixedBufferStream(write_buffer);
    const writer = stream.writer();

    switch (section) {
        .type => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                try writer.writeByte(0x60);

                for (0..2) |_| {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, count);

                    for (0..count) |_| {
                        const valtype = readNextValtype(reader, read_buffer).?;
                        try writer.writeByte(@intFromEnum(valtype));
                    }
                }
            }
        },
        .import => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                for (0..2) |_| {
                    const string = readNext(reader, read_buffer).?;
                    try std.leb.writeUleb128(writer, string.len);
                    try writer.writeAll(string);
                }

                const import_type = std.meta.stringToEnum(ImportDesc, readNext(reader, read_buffer).?).?;
                try writer.writeByte(@intFromEnum(import_type));
                switch (import_type) {
                    .func => {
                        const funcidx = try readNextInteger(u32, reader, read_buffer);
                        try std.leb.writeUleb128(writer, funcidx);
                    },
                    else => {},
                }
            }
        },
        .function => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const typeidx = try readNextInteger(u32, reader, read_buffer);
                try std.leb.writeUleb128(writer, typeidx);
            }
        },
        .memory => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const limit_type = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(limit_type);
                for (0..limit_type + 1) |_| {
                    const num= try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, num);
                }
            }
        },
        .global => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const valtype = readNextValtype(reader, read_buffer).?;
                try writer.writeByte(@intFromEnum(valtype));

                const mut = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(mut);
                
                try readNextExpression(reader, read_buffer, writer);
            }
        },
        .@"export" => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const string = readNext(reader, read_buffer).?;
                try std.leb.writeUleb128(writer, string.len);
                try writer.writeAll(string);

                const export_type = std.meta.stringToEnum(ExportDesc, readNext(reader, read_buffer).?).?;
                try writer.writeByte(@intFromEnum(export_type));

                const idx = try readNextInteger(u32, reader, read_buffer);
                try std.leb.writeUleb128(writer, idx);
            }
        },
        .start => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);
        },
        .code => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);
            var func = try std.ArrayList(u8).initCapacity(allocator, 0xFF);
            defer func.deinit();

            for (0..number) |_| {
                const locals = try readNextInteger(u32, reader, read_buffer);
                try std.leb.writeUleb128(func.writer(), locals);

                for (0..locals) |_| {
                    const count = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(func.writer(), count);

                    const valtype = readNextValtype(reader, read_buffer).?;
                    try func.append(@intFromEnum(valtype));
                }
                
                try readNextExpression(reader, read_buffer, func.writer());

                try std.leb.writeUleb128(writer, func.items.len);
                try writer.writeAll(func.items);

                func.clearRetainingCapacity();
            }
        },
        .data => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);

            for (0..number) |_| {
                const id = try readNextInteger(u8, reader, read_buffer);
                try writer.writeByte(id);

                if (id == 2) {
                    const memidx = try readNextInteger(u32, reader, read_buffer);
                    try std.leb.writeUleb128(writer, memidx);
                }

                if (id == 0 or id == 2) {
                    try readNextExpression(reader, read_buffer, writer);
                }

                const string = try readNextString(reader, read_buffer);
                try std.leb.writeUleb128(writer, string.len);
                try writer.writeAll(string);
            }
        },
        .datacount => {
            const number = try readNextInteger(u32, reader, read_buffer);
            try std.leb.writeUleb128(writer, number);
        },
    }

    return stream.getWritten();
}

pub fn runWasm(wasm: []const u8) !void {
    var proc = std.process.Child.init(&[_][]const u8{"wasmtime", "-"}, std.heap.page_allocator);
    proc.stdin_behavior = .Pipe;
    try proc.spawn();
    
    if (proc.stdin) |*stdin| {
        try stdin.writeAll(wasm);
        stdin.close();
        proc.stdin = null;
    }
    
    _ = try proc.wait();
}

pub fn replace_extension(allocator: std.mem.Allocator, path: []const u8, new_extension: []const u8) []u8 {
    const extension = std.fs.path.extension(path);
    var new_path = allocator.alloc(u8, path.len - extension.len + new_extension.len) catch unreachable;
    std.mem.copyForwards(u8, new_path, path[0 .. path.len - extension.len]);
    std.mem.copyForwards(u8, new_path[new_path.len - new_extension.len ..], new_extension);

    return new_path;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    var args = std.process.args();
    _ = args.next();

    if (args.next()) |source_path| {
        const source_file = try std.fs.cwd().openFile(source_path, .{});
        defer source_file.close();

        var out = try std.ArrayList(u8).initCapacity(allocator, 0xFFFF);
        try out.appendSlice(&.{0,'a','s','m',1,0,0,0});

        const read_buffer = try allocator.alloc(u8, 0xFF);
        const write_buffer = try allocator.alloc(u8, 0xFFFF);

        while (readNextSectionVariant(source_file.reader(), read_buffer)) |section| {
            const content = try readNextSection(allocator, section, source_file.reader(), read_buffer, write_buffer);
            try out.append(@intFromEnum(section));
            try std.leb.writeUleb128(out.writer(), content.len);
            try out.appendSlice(content);
        }

        if (args.next()) |out_path| {
            const out_file = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
            try out_file.writeAll(out.items);
            out_file.close();

            try stdout.print("crust has compiled {s}.\n", .{ out_path });
        } else {
            if (runWasm(out.items)) |_| {
                try stdout.print("crust is finnished running.\n", .{ });
            } else |e| switch (e) {
                error.FileNotFound => try stdout.print("crust needs you to install wasmtime first.\n", .{}),
                else => return e,
            }
        }
    } else {
        try stdout.print("crust needs a file path.\n", .{});
    }
}
